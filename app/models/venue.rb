require 'geokit'
require_relative '../helpers/sparql_queries'

class Venue
  attr_reader :latlng
  attr_reader :images
  attr_reader :titles
  attr_reader :uri

  def initialize(uri, titles, images, latlng, lats, longs)
    @uri = uri

    @latlng = latlng
    @lats = lats
    @longs = longs
    @images = images
    @titles = titles
  end

  # Returns how long traveling to here will probably take, in seconds.
  # Based on a conservative walking speed of 4 km/h, multiplied by 1.2 to account for the fact that you probably can't walk in a straight line
  def travel_time(from)
    1.2 * (@latlng.distance_to(from, {units: :kms}) / 4) * 60 * 60
  end

  # TODO maybe use a smarter algorithm?
  def travel_time_to(at_time, to)
    travel_time to
  end

  def travel_time_from(at_time, from)
    travel_time from
  end

  # Returns a map of venue uris to venues
  def self.get_venues(bounds)
    venues_sparql = SparqlQueries.venues_near(bounds)

    puts "Quering venues to #{SparqlQueries::SPARQL_ENDPOINT}"
    # make query

    response = Net::HTTP.new(SparqlQueries::SPARQL_ENDPOINT.host, SparqlQueries::SPARQL_ENDPOINT.port).start do |http|
      request = Net::HTTP::Post.new(SparqlQueries::SPARQL_ENDPOINT)
      request.set_form_data({:query => venues_sparql})
      request['Accept']='application/sparql-results+xml'
      http.request(request)
    end

    venues = nil
    case response
      when Net::HTTPSuccess # Response code 2xx: success
        results = SparqlQueries::SPARQL_CLIENT.parse_response(response)
        venues = Venue.create_from_sparql_results(results)
      when Net::HTTPRedirection
        #TODO follow redirect
        puts 'redirect'
      else
        #TODO handle error
        puts 'error'
    end
    #Return events map
    venues
  end

  def self.create_from_sparql_results(results)
    venues = {}
    values_map = {}
    results.each do |result|
      uri = result['venue'].value
      venue = values_map[uri]
      unless venue
        # Note that we use sets, so duplicate values are not added
        venue = {:lats => Set.new, :longs => Set.new, :titles => {}, :images => Set.new}
        values_map[uri] = venue
      end

      if result['lat']
        venue[:lats] << Float(result['lat'].value)
      end
      if result['long']
        venue[:longs] << Float(result['long'].value)
      end

      if result['title']
        add_title venue[:titles], result['title']
      end

      if result['imageUrl']
        venue[:images] << result['imageUrl'].value
      end
    end

    values_map.each do |uri, vals|
      avg_lat = (vals[:lats].reduce { |sum, val| sum+val })/vals[:lats].length # average latitude
      avg_long = (vals[:longs].reduce { |sum, val| sum+val })/vals[:longs].length # average longitude
      latlng = Geokit::LatLng.new(avg_lat, avg_long)

      venues[uri.to_s] = Venue.new(uri, vals[:titles], vals[:images], latlng, vals[:lats], vals[:longs])
    end
    return venues
  end

  def self.add_title(map, title)
    titles_for_lang = map[title.language]
    unless titles_for_lang
      titles_for_lang=Set.new
      map[title.language] = titles_for_lang
    end
    titles_for_lang << title.value
  end
end