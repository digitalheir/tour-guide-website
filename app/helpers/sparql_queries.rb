require 'sparql/client'
module SparqlQueries
  SPARQL_ENDPOINT = URI('http://api.artsholland.com/sparql')
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
  LIMIT = '10000'

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

  # TODO also query opening / closing times
  def self.venues_near(bounds)
    "#{PREFIXES}
    SELECT DISTINCT ?venue ?title ?imageUrl ?lat ?long {
      ?venue a ah:Venue.
      # Only select venues with coordinates
      ?venue geo:lat ?lat;
             geo:long ?long.

      # Filter within a square of 25km
      FILTER(
        ?lat > #{bounds.sw.lat} &&
        ?lat < #{bounds.ne.lat} &&
        ?long < #{bounds.ne.lng} &&
        ?long > #{bounds.sw.lng}
      ) .

      OPTIONAL {
        ?venue dc:title ?title.
      }

      OPTIONAL {
        ?venue ah:attachment ?venueAfbeelding.
        ?venueAfbeelding ah:attachmentType ah:AttachmentTypeAfbeelding.
        ?venueAfbeelding ah:url ?imageUrl.
      }
    }LIMIT #{LIMIT}"
  end

  # Same as events query, except get details for production
  def self.productions(bounds, start_time, end_time)
    "#{PREFIXES}
    SELECT DISTINCT ?production ?productionType ?genre ?title ?imageUrl ?homepage ?shortDescription ?description {
      ?event ah:eventStatus ?status;
             ah:production ?production; # An event is always an instance of a production
             ah:venue ?venue.

      FILTER(?status != ah:eventStatusCancelled && ?status != ah:SoldOut && ?status != ah:Postponed)

      # Only select events with venues within bounds
      ?venue geo:lat ?lat;
             geo:long ?long.

      # Only select events that start before the end of our tour (and optionally, end after the start of the tour)
      ?event time:hasBeginning ?start.
      FILTER(?start < \"#{end_time.iso8601}\"^^xsd:dateTime).

      # Filter within a square of 25km
      FILTER(
        ?lat > #{bounds.sw.lat} &&
        ?lat < #{bounds.ne.lat} &&
        ?long < #{bounds.ne.lng} &&
        ?long > #{bounds.sw.lng}
      ) .

      # End is optional, but *if* it exists, make sure that it's after start time. If it doesn't, make sure the event starts after the tour starts
      {
        ?event a ah:Event.
        ?event time:hasEnd ?end.
        FILTER(?end > \"#{start_time.iso8601}\"^^xsd:dateTime).
      } UNION {
        ?event a ah:Event.
        FILTER NOT EXISTS{?event time:hasEnd ?end.}
        FILTER(?start > \"#{(start_time).iso8601}\"^^xsd:dateTime).
      }

      OPTIONAL {
        ?production ah:languageNoProblem ?languageNoProblem
      }

      OPTIONAL {
        ?production ah:genre ?genre
      }

      OPTIONAL {
        ?production ah:productionType ?productionType
      }

      # Get titles if any
      OPTIONAL {
        ?production dc:title ?title
      }
      # Get homepage if any
      OPTIONAL {
        ?production foaf:homepage ?homepage .
      }

      OPTIONAL {
        ?production ah:shortDescription ?shortDescription.
      }
      OPTIONAL {
        ?production dc:description ?description.
      }

      # Get image urls if any
      OPTIONAL {
        ?production ah:attachment ?att.
        ?att ah:attachmentType ah:AttachmentTypeAfbeelding.
        ?att ah:url ?imageUrl.
      }
    }LIMIT 10000"
  end

  def self.events(bounds, start_time, end_time)
    "#{PREFIXES}
    SELECT DISTINCT ?event ?eventType ?production ?venue ?title ?imageUrl ?start ?end ?shortDescription ?description {
      ?event ah:eventStatus ?status;
             ah:production ?production; # An event is always an instance of a production
             ah:venue ?venue.

      FILTER(?status != ah:eventStatusCancelled && ?status != ah:SoldOut && ?status != ah:Postponed)

      # Only select events with venues within bounds
      ?venue geo:lat ?lat;
             geo:long ?long.

      # Only select events that start before the end of our tour (and optionally, end after the start of the tour)
      ?event time:hasBeginning ?start.
      FILTER(?start < \"#{end_time.iso8601}\"^^xsd:dateTime).

      # Filter within a square of 25km
      FILTER(
        ?lat > #{bounds.sw.lat} &&
        ?lat < #{bounds.ne.lat} &&
        ?long < #{bounds.ne.lng} &&
        ?long > #{bounds.sw.lng}
      ) .

      # End is optional, but *if* it exists, make sure that it's after start time. If it doesn't, make sure the event starts after the tour starts
      {
        ?event a ah:Event.
        ?event time:hasEnd ?end.
        FILTER(?end > \"#{start_time.iso8601}\"^^xsd:dateTime).
      } UNION {
        ?event a ah:Event.
        FILTER NOT EXISTS{?event time:hasEnd ?end.}
        FILTER(?start > \"#{(start_time).iso8601}\"^^xsd:dateTime).
      }

      # Get image urls if any
      OPTIONAL {
        ?event ah:attachment ?eventAfbeelding.
        ?eventAfbeelding ah:attachmentType ah:AttachmentTypeAfbeelding.
        ?eventAfbeelding ah:url ?imageUrl.
      }

      # Get description if any
      OPTIONAL {
        ?event ah:shortDescription ?shortDescription.
      }
      OPTIONAL {
        ?event dc:description ?description.
      }
    }ORDER BY DESC(?start) LIMIT 10000" # get newest events
  end
end