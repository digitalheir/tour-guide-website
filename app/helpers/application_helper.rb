module ApplicationHelper
  def self.sample(set)
    set.each do |el|
      return el
    end
    nil
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