require 'set'

class ThingToDo
  attr_accessor :start
  attr_accessor :end
  attr_accessor :latlng

  attr_reader :uri
  attr_reader :lats
  attr_reader :longs
  attr_reader :production_titles
  attr_reader :event_titles
  attr_reader :venue_images
  attr_reader :event_images

  # Run on ThingToDo.new
  def initialize uri
    @uri = uri
    @start = nil
    @end = nil
    # Note that we use sets, so duplicate values are not added
    @lats = Set.new
    @longs = Set.new
    @venue_images = Set.new
    @event_images = Set.new
    @production_titles = {}
    @event_titles = {}
  end


  def add_venue_image(url)
    @venue_images << url
  end

  def add_event_image(url)
    @event_images << url
  end

  def add_production_title(title)
    titles_for_lang = @production_titles[title.language]
    unless titles_for_lang
      titles_for_lang=Set.new
      @production_titles[title.language] = titles_for_lang
    end
    titles_for_lang << title
  end

  def add_event_title(title)
    titles_for_lang = @event_titles[title.language]
    unless titles_for_lang
      titles_for_lang=Set.new
      @event_titles[title.language] = titles_for_lang
    end
    titles_for_lang << title
  end

  def get_display_title(lang)
    title = nil
    if event_titles.length > 0
      title = find_title event_titles, lang
    end
    if title == nil and production_titles.length > 0
      title = find_title production_titles, lang
    end
    title
  end

  def get_background_style
    image_url = ApplicationHelper.sample event_images
    unless image_url
      #Try venue images if we can't find an event image
      ApplicationHelper.sample venue_images
    end

    if image_url
      "background-image: url(#{image_url})"
    else
      'background-color: #afafaf'
      nil
    end
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
    30 * 60 # Hardcode 30 minutes for now
  end

  def have_time(from_time, until_time, travel_to, travel_from)
    time_left = until_time - from_time
    travel_to + projected_duration + travel_from <= time_left
  end

  def self.create_from_sparql_results(results)
    events = {}
    results.each do |result|
      uri = result['event'].value
      event = events[uri]
      unless event
        event = ThingToDo.new uri
        events[uri] = event
      end

      if result['lat']
        event.lats << Float(result['lat'].value)
      end
      if result['long']
        event.longs << Float(result['long'].value)
      end

      if result['productionTitle']
        event.add_production_title result['productionTitle']
      end

      if result['eventTitle']
        event.add_event_title result['eventTitle']
      end

      if result['venueImageUrl']
        event.add_venue_image result['venueImageUrl']
      end
      if result['eventImageUrl']
        event.add_event_image result['eventImageUrl']
      end
      if !(event.end) & result['end']
        event.end = Time.parse(result['end'].value)
      end
      if !(event.start) & result['start']
        event.start = Time.parse(result['start'].value)
      end
    end

    events.each do |_, event|
      avg_lat = (event.lats.reduce { |sum, val| sum+val })/event.lats.length # average latitude
      avg_long = (event.longs.reduce { |sum, val| sum+val })/event.longs.length # average longitude
      event.latlng = Geokit::LatLng.new(avg_lat, avg_long)
    end

    return events
  end
end
