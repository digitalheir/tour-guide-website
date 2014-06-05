require 'set'

class TravelNode
  attr_accessor :from
  attr_accessor :to
  attr_accessor :duration

  def initialize from, to, transportation_means
    @from = from
    @to = to
    @transportation_means = transportation_means

    # TODO call MapQuest / Google directions API to get the actual route
    @duration = 5 * 60 # Placeholder for 5 minutes
  end
end
