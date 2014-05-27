require 'chronic'
require 'sparql/client'
include ActionView::Helpers::DateHelper
#TODO use (concat('[',group_concat(?something;separator=","),']') as ?somethings) to aggregate multiple rows

SPARQL_CLIENT = SPARQL::Client.new("http://api.artsholland.com/sparql/")
PREFIXES = 'PREFIX ah: <http://purl.org/artsholland/1.0/>
      PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
  PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  PREFIX owl: <http://www.w3.org/2002/07/owl#>
  PREFIX dc: <http://purl.org/dc/terms/>
      PREFIX foaf: <http://xmlns.com/foaf/0.1/>
      PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
  PREFIX time: <http://www.w3.org/2006/time#>
  PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
  PREFIX vcard: <http://www.w3.org/2006/vcard/ns#>
  PREFIX osgeo: <http://rdf.opensahara.com/type/geo/>
      PREFIX bd: <http://www.bigdata.com/rdf/search#>
  PREFIX search: <http://rdf.opensahara.com/search#>
  PREFIX fn: <http://www.w3.org/2005/xpath-functions#>
  PREFIX gr: <http://purl.org/goodrelations/v1#>
  PREFIX gn: <http://www.geonames.org/ontology#>'
LIMIT = '500'
VENUE_HAS_LAT_LONG='?venue geo:lat ?lat;
         geo:long ?long.'
OPTIONAL_IMAGES = 'OPTIONAL {
    ?event ah:attachment ?eventAfbeelding.
    ?eventAfbeelding ah:attachmentType ah:AttachmentTypeAfbeelding.
    ?eventAfbeelding ah:url ?eventImageUrl.
  }

  OPTIONAL {
    ?venue ah:attachment ?venueAfbeelding.
    ?venueAfbeelding ah:attachmentType ah:AttachmentTypeAfbeelding.
    ?venueAfbeelding ah:url ?venueImageUrl.
  }'
EVENT_PRODUCTION_VENUE = '?event ah:production ?production; # An event is always an instance of a production
         ah:venue ?venue. # An event must take place at a venue'
OPTIONAL_TITLES = '# Resolve title:
  OPTIONAL {
    ?event dc:title ?eventTitle. # Not all events have a title...
  }
  OPTIONAL {
    ?production dc:title ?productionTitle # ...So sometimes we get the title from the production
  }'
OPTIONAL_HOMEPAGE='OPTIONAL {
    ?production foaf:homepage ?homepage .
  }'

class Tour
  # attr_reader :start_time
  attr_reader :str_start_time
  # attr_reader :end_time
  attr_reader :str_end_time
  attr_reader :events


  def initialize(start_time, end_time)
    if start_time.is_a? Time
      @str_start_time = "#{time_ago_in_words(start_time)} from now"
      @start_time = start_time
    else
      @str_start_time = start_time
      @start_time = Chronic::parse start_time
    end

    if end_time.is_a? Time
      @str_end_time = "#{time_ago_in_words(end_time)} from now"
      @end_time = end_time
    else
      @str_end_time = end_time
      @end_time = Chronic::parse end_time
    end
  end

  def generate_events(startTime, endTime)
    query = query_events_with_lat_longs(startTime, endTime)

    # Make query against artsholland sparql endpoint (SPARQL client makes the server return a 500 for some reason)
    uri = URI('http://api.artsholland.com/sparql')
    res = Net::HTTP.new(uri.host, uri.port).start do |http|
      request = Net::HTTP::Post.new(uri)
      request.set_form_data({:query => query})
      request["Accept"]='application/sparql-results+xml'
      http.request(request)
    end

    case res
      when Net::HTTPSuccess
        results = SPARQL_CLIENT.parse_response(res)
        @events = ThingToDo.handle_sparql_result(results)
      when Net::HTTPRedirection
        #TODO follow redirect
        puts 'redirect'
      else
        #TODO handle error
        puts 'error'
    end
  end

    # TODO artsholland times are in timezone UTC. Maybe that's an error on their part and we should lose our ECT timezone.
  def query_events_with_lat_longs(startTime, endTime)
    "#{PREFIXES}
SELECT DISTINCT ?event ?eventTitle ?productionTitle ?venue ?lat ?long ?address ?homepage ?eventImageUrl ?venueImageUrl {
  # Only select events that take place while we are about
  ?event time:hasBeginning ?start.
  ?event time:hasEnd ?end. #TODO end is optional, but *if* it exists, make sure that it's afer endDate

  FILTER(?start < \"#{startTime.iso8601}\"^^xsd:dateTime &&
      ?end > \"#{endTime.iso8601}\"^^xsd:dateTime).

  #{OPTIONAL_IMAGES}

  #{EVENT_PRODUCTION_VENUE}

  # For now only select venues with coordinates
  #{VENUE_HAS_LAT_LONG}

  #{OPTIONAL_TITLES}
  #{OPTIONAL_HOMEPAGE}
} LIMIT #{LIMIT}
"
  end

  def query_events_with_addresses(startTime, endTime)
    "#{PREFIXES}
SELECT DISTINCT ?event ?eventTitle ?productionTitle ?venue ?lat ?long ?address ?homepage ?eventImageUrl ?venueImageUrl{
  # Only select events that take place while we are about
  ?event time:hasBeginning ?start.
  ?event time:hasEnd ?end. #TODO end is optional, but *if* it exists, make sure that it's afer endDate

      FILTER(?start < \"#{startTime.iso8601}\"^^xsd:dateTime &&
      ?end > \"#{endTime.iso8601}\"^^xsd:dateTime).

      #{EVENT_PRODUCTION_VENUE}

#{OPTIONAL_IMAGES}

  # NOTE: Some venues (1748 out of 9042 at last count) do not have addresses. We ignore them.
  # TODO: only select vanues that have EITHER address OR latlong
  ?venue ah:locationAddress ?address.

  OPTIONAL{
    #{VENUE_HAS_LAT_LONG}
  }

  #{OPTIONAL_TITLES}
  #{OPTIONAL_HOMEPAGE}
} LIMIT #{LIMIT}
"
  end
end
