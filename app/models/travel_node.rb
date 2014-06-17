require 'set'

class TravelNode
  attr_accessor :from
  attr_accessor :to
  attr_accessor :to_venue
  attr_accessor :duration #in seconds

  def initialize from, to_venue, transportation_means, estimated_duration
    @from = from
    @to = to_venue.latlng
    @to_venue = to_venue
    @transportation_means = transportation_means
    # TODO call MapQuest / Google directions API to get the actual route
    @duration = estimated_duration
  end

  def venue_title lang
    title=nil
    if @to_venue
      title = @to_venue.get_title lang
    end
    title
  end
end
