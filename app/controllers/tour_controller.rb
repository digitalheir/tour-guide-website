require 'chronic'
require 'openssl'
require 'geokit'

class TourController < ApplicationController
  def generate
    tour = params['tour']
    if tour and tour['str_start_time'] and tour['str_end_time']
      str_end_time = tour['str_end_time']
      str_start_time = tour['str_start_time']

      @start_time = Chronic::parse str_start_time
      @end_time = Chronic::parse str_end_time

      # TODO check if time are less than 8 hours apart and valid, etc
      user_location = Geokit::LatLng.new(Float(params['lat']), Float(params['long']))
      events = TourHelper::find_events(@start_time, @end_time, user_location)
      puts "Found #{events.length} things to do between #{@start_time} and #{@end_time}"
      @tour = TourHelper::generate_tour(events, @start_time, @end_time, user_location)

      puts "Calculated a tour with #{@tour.length} nodes"
    end

    unless @tour
      render :status => 500 # TODO render something informative
    end
  end

  def welcome
    @tour = Tour.new('now', '8 hours from now')
  end
end
