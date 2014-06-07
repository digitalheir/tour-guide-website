require 'set'

class TravelNode
  attr_accessor :from
  attr_accessor :to
  attr_accessor :duration #in seconds

  def initialize from, to, transportation_means, estimated_duration
    @from = from
    @to = to
    @transportation_means = transportation_means
    # TODO call MapQuest / Google directions API to get the actual route
    @duration = estimated_duration
  end
end
