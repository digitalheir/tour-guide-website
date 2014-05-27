require 'chronic'
class TourController < ApplicationController
  def generate
    tour = params['tour']
    if tour and tour['str_start_time'] and tour['str_end_time']
      str_end_time = tour['str_end_time']
      str_start_time = tour['str_start_time']

      @start_time = Chronic::parse str_start_time
      @end_time = Chronic::parse str_end_time


      if @start_time and @end_time
        # TODO check if time are less than 8 hours apart?

        @tour = Tour.new(str_start_time, str_end_time)
        @tour.generate_events(@start_time, @end_time)
        # puts @tour.events
      end
    end

    unless @tour
      render :status => 500 # TODO render something informative
    end
  end

  def welcome
    @tour = Tour.new('now', '8 hours from now')
  end
end
