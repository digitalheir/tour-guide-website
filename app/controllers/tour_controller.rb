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
      tour_start=@start_time.utc

      @end_time = Chronic::parse str_end_time
      tour_end = @end_time.utc

      # TODO check if time are less than 8 hours apart and valid, etc
      user_location = Geokit::LatLng.new(Float(params['lat']), Float(params['long']))

      bounds = Geokit::Bounds::from_point_and_radius(user_location, 25, {units: :kms})
      venues = Venue::get_venues(bounds)
      puts "Found #{venues.length} nearby venues"

      productions = Production::get_productions(bounds, tour_start, tour_end)
      puts "Found #{productions.length} nearby productions with posible events"

      # Find events
      events = Event::get_events(venues, productions, bounds, tour_start, tour_end)
      puts "Found #{events.length} things to do between #{tour_start} and #{tour_end}"

      # Run algorithm to combine a location (latitude/longitude-pair) with these events to make a tour
      @tour = TourHelper::generate_tour(events.values, tour_start, tour_end, user_location)

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
