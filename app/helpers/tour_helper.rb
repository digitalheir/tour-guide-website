require 'sparql/client'
require 'openssl'
require 'geokit'
require 'open-uri'
require_relative 'sparql_queries'
require_relative '../models/travel_node'
require_relative '../models/venue'

module TourHelper
  def self.find_events(start_time, end_time, user_location)
    events = nil

    # Use user location to filter out events that are too far away (> 25 km)
    bounds = Geokit::Bounds::from_point_and_radius(user_location, 25, {units: :kms})
    query = SparqlQueries::events_that_have_lat_longs(start_time, end_time, bounds)


    # Make query against artsholland sparql endpoint
    # If we use the SPARQL client library, the server return a status 500 for some reason

    puts "Making query to #{SPARQL_ENDPOINT}"
    # make query

    response = Net::HTTP.new(SPARQL_ENDPOINT.host, SPARQL_ENDPOINT.port).start do |http|
      request = Net::HTTP::Post.new(SPARQL_ENDPOINT)
      request.set_form_data({:query => query})
      request['Accept']='application/sparql-results+xml'
      http.request(request)
    end

    case response
      when Net::HTTPSuccess # Response code 2xx: success
        results = SparqlQueries::SPARQL_CLIENT.parse_response(response)
        events = ThingToDo.create_from_sparql_results(results).values
      when Net::HTTPRedirection
        #TODO follow redirect
        puts 'redirect'
      else
        #TODO handle error
        puts 'error'
    end
    #Return events array
    events
  end

  def self.make_array(string_or_array)
    if string_or_array.class == String
      [string_or_array]
    else
      string_or_array
    end
  end

  # TODO include POIs and always-open venues
  def self.generate_tour(events, tour_start, tour_end, at_location, transportation_mode=:walking)
    running_time = tour_start

    at_location = at_location
    base_location = at_location # End at starting point

    tour = []

    # Add events to the tour until get_suitable_event returns nil
    travel_finish = nil
    loop do
      # Note that events is replaced with an event that doesn't contain the selected production
      travel_to, event, return_to_base, events = get_suitable_activity(events, running_time, tour_end, at_location, base_location, transportation_mode)
      if travel_to and event and return_to_base
        if travel_to.duration >= 60
          tour << travel_to # Only add travel nodes if travel time is at least a minute
        end
        tour << event

        running_time += travel_to.duration # add time in seconds
        running_time += event.projected_duration # add time in seconds

        at_location = event.venue.latlng # set current location to the event location

        travel_finish = return_to_base
      else
        break
      end
    end
    if travel_finish
      tour << travel_finish
    end

    tour
  end

  def self.get_suitable_activity(events, at_time, until_end, at_latlng, return_latlng, transportation_means)
    # Order events to distance from starting location
    events_with_distance = events.map do |event|
      distance = at_latlng.distance_to(event.venue.latlng, {units: :kms})
      [distance, event]
    end
    events_with_distance.sort_by! do |event_with_distance|
      # Sort by distance
      event_with_distance[0]
    end

    suitable_event = nil
    travel_to = nil
    return_to_base = nil

    # Find suitable event. Prefer the closest one. # TODO prefer activity based on multidimensional function
    events_with_distance.each do |event_with_distance|
      event = event_with_distance[1]
      # Check if event duration fits in schedule
      is_suitable, travel_time_to, travel_time_back = event.is_suitable(at_time, until_end, at_latlng, return_latlng)
      if !suitable_event and is_suitable
        # Get route to closest event with less than 1 hour waiting time
        suitable_event = event
        travel_to = TravelNode.new(at_latlng, event.venue.latlng, transportation_means, travel_time_to)
        return_to_base = TravelNode.new(event.venue.latlng, return_latlng, transportation_means, travel_time_back)
      end
    end

    remaining_candidates = []
    events_with_distance.each do |event_with_distance|
      event = event_with_distance[1]
      unless event == suitable_event or (suitable_event and event.production == suitable_event.production)
        remaining_candidates << event
      end
    end

    return travel_to, suitable_event, return_to_base, remaining_candidates
  end
end
