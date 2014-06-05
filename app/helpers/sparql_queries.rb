module SparqlQueries
  SPARQL_CLIENT = SPARQL::Client.new('http://api.artsholland.com/sparql/')
# Fragments of SPARQL queries. We have multiple SPARQL queries, so re-use these strings
  PREFIXES = '  PREFIX ah: <http://purl.org/artsholland/1.0/>
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
  LIMIT = '1000'

  ##
  # SPARQL queries:
  #
  # Note that artsholland times are in timezone UTC, and the Netherlands are in timezone CEST.
  # The SPARQL client should account for that, but beware off-by-2-hours errors.
  ##

  # Returns a SPARQL query for all events that have an address, together with a bunch of metadata
  def self.events_that_have_lat_longs(start_time, end_time, bounds)
    "#{PREFIXES}
  SELECT DISTINCT ?event ?eventTitle ?productionTitle ?start ?end ?venue ?lat ?long ?address ?homepage ?eventImageUrl ?venueImageUrl {
  # Only select events that take place while we are about
  ?event time:hasBeginning ?start.

  #end is optional, but *if* it exists, make sure that it's after start time
  OPTIONAL{
    ?event time:hasEnd ?end.
    FILTER(?end > \"#{start_time.iso8601}\"^^xsd:dateTime).
  }

  FILTER(?start < \"#{start_time.iso8601}\"^^xsd:dateTime).

  # Get image urls if any
  OPTIONAL {
    ?event ah:attachment ?eventAfbeelding.
    ?eventAfbeelding ah:attachmentType ah:AttachmentTypeAfbeelding.
    ?eventAfbeelding ah:url ?eventImageUrl.
  }

  OPTIONAL {
    ?venue ah:attachment ?venueAfbeelding.
    ?venueAfbeelding ah:attachmentType ah:AttachmentTypeAfbeelding.
    ?venueAfbeelding ah:url ?venueImageUrl.
  }

  ?event ah:production ?production; # An event is always an instance of a production
         ah:venue ?venue. # An event must take place at a venue

  # For now only select venues with coordinates
  ?venue geo:lat ?lat;
         geo:long ?long.

  # Filter within a square of 25km
  FILTER(
    ?lat > #{bounds.sw.lat} &&
    ?lat < #{bounds.ne.lat} &&
    ?long < #{bounds.ne.lng} &&
    ?long > #{bounds.sw.lng}
  ) .

  # Resolve title:
  OPTIONAL {
    ?event dc:title ?eventTitle. # Not all events have a title...
  }
  OPTIONAL {
    ?production dc:title ?productionTitle # ...So sometimes we get the title from the production
  }
  OPTIONAL {
    ?production foaf:homepage ?homepage .
  }
} LIMIT #{LIMIT}"
  end

  # Returns a SPARQL query for all events that have an address, together with a bunch of metadata
  def events_that_have_addresses(start_time, end_time)
    "#{PREFIXES}
  SELECT DISTINCT ?event ?eventTitle ?productionTitle ?venue ?lat ?long ?address ?homepage ?eventImageUrl ?venueImageUrl{
  # Only select events that take place while we are about
  ?event time:hasBeginning ?start.
  ?event time:hasEnd ?end. #TODO end is optional, but *if* it exists, make sure that it's afer endDate

  FILTER(?start < \"#{start_time.iso8601}\"^^xsd:dateTime &&
      ?end > \"#{start_time.iso8601}\"^^xsd:dateTime).

  ?event ah:production ?production; # An event is always an instance of a production
         ah:venue ?venue. # An event must take place at a venue

  # Get image urls if any
  OPTIONAL {
    ?event ah:attachment ?eventAfbeelding.
    ?eventAfbeelding ah:attachmentType ah:AttachmentTypeAfbeelding.
    ?eventAfbeelding ah:url ?eventImageUrl.
  }

  OPTIONAL {
    ?venue ah:attachment ?venueAfbeelding.
    ?venueAfbeelding ah:attachmentType ah:AttachmentTypeAfbeelding.
    ?venueAfbeelding ah:url ?venueImageUrl.
  }

  # NOTE: Some venues (1748 out of 9042 at last count) do not have addresses. We ignore them.
  # TODO: only select vanues that have EITHER address OR latlong
  ?venue ah:locationAddress ?address.

  OPTIONAL{
    ?venue geo:lat ?lat;
         geo:long ?long.
  }

  # Resolve title:
  OPTIONAL {
    ?event dc:title ?eventTitle. # Not all events have a title...
  }
  OPTIONAL {
    ?production dc:title ?productionTitle # ...So sometimes we get the title from the production
  }
  OPTIONAL {
    ?production foaf:homepage ?homepage .
  }
} LIMIT #{LIMIT}
    "
  end
end