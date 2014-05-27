require 'set'

class ThingToDo
  attr_reader :lats
  attr_reader :longs
  attr_reader :production_titles
  attr_reader :event_titles
  attr_reader :venue_images
  attr_reader :event_images

  def initialize()
    @lats = Set.new
    @longs = Set.new
    @venue_images = Set.new
    @event_images = Set.new
    @production_titles = {}
    @event_titles = {}
  end

  def self.handle_sparql_result(results)
    events = {}
    results.each do |result|
      uri = result['event'].value #TODO these are SPARQL variables. Make ruby constants out of them
      event = events[uri]
      unless event
        event = ThingToDo.new
        events[uri] = event
      end

      if result['lat'] #TODO if not already exists
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

      # ah:AttachmentTypeAfbeelding [http]
      # ah:AttachmentTypeVideo [http]
      # ah:AttachmentTypeTwitter [http]
      # ah:AttachmentTypeLink [http]
      # ah:AttachmentTypeImage [http]
      # ah:AttachmentTypeKML [http]
      if result['venueImageUrl']
        event.add_venue_image result['venueImageUrl']
      end
      if result['eventImageUrl']
        event.add_event_image result['eventImageUrl']
      end
    end
    return events
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

  def get_display_title lang
    title = nil
    if event_titles.length > 0
      title = get_title event_titles, lang
    end
    if title == nil and production_titles.length > 0
      title = get_title production_titles, lang
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
      # "background-color: #eee"
      nil
    end
  end

  def get_title map, lang
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
        # No titles
        nil
      end
    end
  end
end
