require 'sparql/client'
require 'openssl'
require 'geokit'
require_relative 'sparql_queries'
require_relative '../models/travel_node'

module TourHelper
  def self.find_events(start_time, end_time, user_location)
    events = nil

    # Use user location to filter out events that are too far away (> 25 km)
    bounds = Geokit::Bounds::from_point_and_radius(user_location, 25, {units: :kms})
    query = SparqlQueries::events_that_have_lat_longs(start_time, end_time, bounds)


    # Make query against artsholland sparql endpoint
    # If we use the SPARQL client library, the server return a status 500 for some reason
    uri = URI('http://api.artsholland.com/sparql')

    puts "Making query to #{uri}"
    # puts query

    response = Net::HTTP.new(uri.host, uri.port).start do |http|
      request = Net::HTTP::Post.new(uri)
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

  def self.generate_tour(events, tour_start, tour_end, at_location, transportation_mode=:walking)
    running_time = tour_start

    at_location = at_location
    to_location = at_location # End at starting point

    tour = []

    # Add events to the tour until get_suitable_event returns nil
    travel_finish = nil
    loop do
      # Note that events is replaced with an event that doesn't contain the selected event
      travel_to, event, return_to_base, events = get_suitable_event(events, running_time, tour_end, at_location, to_location, transportation_mode)
      if travel_to and event and return_to_base
        tour << travel_to
        tour << event

        running_time += travel_to.duration # add time in seconds
        running_time += event.projected_duration # add time in seconds

        at_location = event.latlng # set current location to the event location

        travel_finish = return_to_base
      else
        break
      end
    end
    tour << travel_finish

    tour
  end

  def self.get_suitable_event(events, at_time, until_end, at_location, return_location, transportation_means)

    # Order events to distance from starting location
    events_with_distance = events.map do |event|
      distance = at_location.distance_to(event.latlng, {units: :kms})
      [distance, event]
    end
    events_with_distance.sort_by! do |event_with_distance|
      # Sort by distance
      event_with_distance[0]
    end

    # travel to/from are hardcoded to 5 minutes, for now
    travel_time_to = 5*60
    travel_time_from = 5*60

    suitable_event = nil
    travel_to = nil
    return_to_base = nil
    non_suitable = []

    # Find suitable event. Prefer the closest one.
    events_with_distance.each do |event_with_distance|
      event = event_with_distance[1]
      # Check if event duration fits in schedule
      if !suitable_event and event.have_time(at_time, until_end, travel_time_to, travel_time_from)
        # Get route to closest event
        suitable_event = event
        travel_to = TravelNode.new(at_location, events_with_distance[0][1].latlng, transportation_means)
        return_to_base = TravelNode.new(event.latlng, return_location, transportation_means)

        #TODO filter for production uris
        puts "Picked #{event.uri}"
      else
        non_suitable << event
      end
    end
    return travel_to, suitable_event, return_to_base, non_suitable
  end
end
