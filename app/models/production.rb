require 'geokit'

class Production
  attr_reader :uri
  attr_reader :production_type
  attr_reader :genres
  attr_reader :titles
  attr_reader :images
  attr_reader :homepage
  attr_reader :short_descriptions
  attr_reader :descriptions

  def initialize(uri, production_type, genres, titles, images, homepage, short_descriptions, descriptions)
    @uri=uri
    @production_type = production_type
    @genres = genres
    @titles = titles
    @images = images
    @homepage = homepage
    @short_descriptions = short_descriptions
    @descriptions = descriptions
  end

  def get_sh_description lang
    desc = find_string_in_map(@short_descriptions, lang)
    unless desc
      desc = find_string_in_map(@descriptions, lang)
    end
    desc
  end

  def self.get_productions(bounds, start_time, end_time)
    query = SparqlQueries.productions(bounds, start_time, end_time)
    puts "Query productions from #{SparqlQueries::SPARQL_ENDPOINT}"
    # Make query
    response = Net::HTTP.new(SparqlQueries::SPARQL_ENDPOINT.host, SparqlQueries::SPARQL_ENDPOINT.port).start do |http|
      request = Net::HTTP::Post.new(SparqlQueries::SPARQL_ENDPOINT)
      request.set_form_data({:query => query})
      request['Accept']='application/sparql-results+xml'
      http.request(request)
    end

    productions = nil
    case response
      when Net::HTTPSuccess # Response code 2xx: success
        results = SparqlQueries::SPARQL_CLIENT.parse_response(response)
        productions = create_from_sparql_results(results)
      when Net::HTTPRedirection
        #TODO follow redirect
        puts 'redirect'
      else
        #TODO handle error
        puts 'error'
    end
    #Return map
    productions
  end

  def self.create_from_sparql_results(results)
    # ?production ?productionType ?genre ?title ?imageUrl ?homepage ?shortDescription ?description
    productions = {}
    values_map = {}
    results.each do |result|
      uri = result['production'].value
      production = values_map[uri]
      unless production
        # Note that we use sets, so duplicate values are not added
        production = {:genres => Set.new, :titles => {}, :images => Set.new, :shortDescriptions => {}, :descriptions => {}}
        values_map[uri] = production
      end

      if result['productionType']
        production[:productionType] = result['productionType']
      end

      if result['genre']
        production[:genres] << result['genre']
      end

      if result['title']
        add_string(production[:titles], result['title'])
      end

      if result['imageUrl']
        production[:images] << result['imageUrl'].value
      end

      if result['homepage']
        production[:homepage] = result['homepage'].value
      end
      if result['shortDescription']
        add_string(production[:shortDescriptions], result['shortDescription'])
      end
      if result['description']
        add_string(production[:descriptions], result['description'])
      end
    end

    values_map.each do |uri, vals|
      productions[uri] = Production.new(uri,
                                        vals[:productionType],
                                        vals[:genres],
                                        vals[:titles],
                                        vals[:images],
                                        vals[:homepage],
                                        vals[:shortDescriptions],
                                        vals[:descriptions])
    end
    return productions
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