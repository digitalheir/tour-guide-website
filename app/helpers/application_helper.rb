module ApplicationHelper
  def self.sample(set)
    set.each do |el|
      return el
    end
    nil
  end

  def find_string_in_map(map, lang)
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

  def self.get_background_style event
    image_url = sample event.images
    unless image_url
      #Try production images if we can't find an event image
      image_url = sample event.production.images
      unless image_url
        #Try venue images if we can't find an event / production image
        image_url = sample event.venue.images
      end
    end

    if image_url
      "background-image: url(#{image_url})"
    else
      'background-color: #afafaf'
      nil
    end
  end
end