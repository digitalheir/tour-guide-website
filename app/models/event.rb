require 'geokit'
require_relative '../helpers/sparql_queries'

class Event
  attr_reader :uri
  attr_reader :titles
  attr_reader :start
  attr_reader :end
  attr_reader :venue
  attr_reader :production
  attr_reader :images

  def initialize(uri, titles, start_time, end_time, venue, production, images, descriptions, short_descriptions)
    @uri = uri
    @titles = titles
    @start = start_time
    @end = end_time
    unless venue
      throws Error('Venue must be defined')
    end
    @venue = venue
    @production = production
    @images = images
    @short_descriptions = short_descriptions
    @descriptions = descriptions
  end

  def get_display_title(lang)
    title = nil
    if titles.length > 0
      title = find_title titles, lang
    end
    if title == nil and production.titles.length > 0
      title = find_title production.titles, lang
    end
    if title == nil and venue.titles.length > 0
      title = find_title venue.titles, lang
    end
    title
  end
  def find_title(map, lang)
    if map[lang] and map[lang].length > 0
      ApplicationHelper.sample(map[lang])
    else
      if map.length > 0
        #Get different language, preferrably English
        if map[:en] and map[:en].length > 0
          ApplicationHelper.sample(map[:en])
        elsif map[nil] and map[nil].length > 0
          ApplicationHelper.sample(map[nil])
        else
          map.each do |_, titles|
            return ApplicationHelper.sample(titles)
          end
        end
      else
        # No title available in map
        nil
      end
    end
  end

  # Returns how long this activity will probably take, in seconds.
  def projected_duration
    if @end and @start and @end - @start > 60 # difference should be at least 1 minute, or else we won't trust it
      @end - @start
    else
      30 * 60 # Hardcode at 30 minutes for now TODO make different estimates based on production (e.g., exhibit, movie)
    end
  end

  def is_suitable_event(from_time, until_time, from_latlng, return_latlng)
    travel_to = @venue.travel_time_from(from_time, from_latlng)

    wait_until_event_starts = @start - (from_time+travel_to) # TODO we can't walk into a movie that already started, but we *can* walk into an exhibition that has already started
    if wait_until_event_starts < 0
      wait_until_event_starts = 0
    end

    time_until_event_end = travel_to + wait_until_event_starts + projected_duration
    travel_from = @venue.travel_time_to(from_time + time_until_event_end, return_latlng)

    puts "Have to wait #{wait_until_event_starts} until event starts"
    if wait_until_event_starts > 1*60*60
      return false, travel_to, travel_from # Don't wait longer than 1 hour
    end

    time_left = until_time - from_time
    return (time_until_event_end + travel_from <= time_left), travel_to, travel_from
  end

  # Returns a map of venue uris to venues
  def self.get_events(venues, productions, bounds, start_time, end_time)
    events_sparql = SparqlQueries.events(bounds, start_time, end_time)
    puts "Query events from #{SparqlQueries::SPARQL_ENDPOINT}"
    # Make query
    response = Net::HTTP.new(SparqlQueries::SPARQL_ENDPOINT.host, SparqlQueries::SPARQL_ENDPOINT.port).start do |http|
      request = Net::HTTP::Post.new(SparqlQueries::SPARQL_ENDPOINT)
      request.set_form_data({:query => events_sparql})
      request['Accept']='application/sparql-results+xml'
      http.request(request)
    end

    events = nil
    case response
      when Net::HTTPSuccess # Response code 2xx: success
        results = SparqlQueries::SPARQL_CLIENT.parse_response(response)
        events = create_from_sparql_results(venues, productions, results)
      when Net::HTTPRedirection
        #TODO follow redirect
        puts 'redirect'
      else
        #TODO handle error
        puts 'error'
    end
    #Return events map
    events
  end

  def self.create_from_sparql_results(venues, productions, results)
    events = {}
    value_maps = {}
    results.each do |result|
      uri = result['event'].value
      value_map = value_maps[uri]
      unless value_map
        # Note that we use sets, so duplicate values are not added
        value_map = {:titles => {}, :descriptions => {}, :shortDescriptions => {}, :images => Set.new}
        value_maps[uri] = value_map
      end

      if result['eventType']
        value_map[:eventType] = result['eventType'].value
      end
      if result['start']
        value_map[:start] = Time.parse(result['start'].value)
      end
      if result['end']
        value_map[:end] = Time.parse(result['end'].value)
      end

      if result['venue']
        venue = venues[result['venue'].to_s]
        unless venue
          puts "WARNING: venue #{result['venue'].to_s} not found."
        end
        value_map[:venue] = venue
      end

      if result['production']
        production = productions[result['production'].to_s]
        unless production
          puts "WARNING: production #{result['production'].to_s} not found."
        end
        value_map[:production] = production
      end

      if result['title']
        add_string(value_map[:titles], result['title'])
      end

      if result['shortDescription']
        add_string(value_map[:shortDescriptions], result['shortDescription'])
      end
      if result['description']
        add_string(value_map[:descriptions], result['description'])
      end

      if result['imageUrl']
        value_map[:images] << result['imageUrl'].value
      end
    end

    value_maps.each do |uri, vals|
      events[uri] = Event.new(uri, vals[:titles], vals[:start], vals[:end], vals[:venue], vals[:production], vals[:images], vals[:descriptions], vals[:shortDescriptions])
    end
    return events
  end

  def self.add_string(map, title)
    titles_for_lang = map[title.language]
    unless titles_for_lang
      titles_for_lang=Set.new
      map[title.language] = titles_for_lang
    end
    titles_for_lang << title.value
  end
end