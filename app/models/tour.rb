require 'chronic'
require 'sparql/client'
include ActionView::Helpers::DateHelper
#TODO use (concat('[',group_concat(?something;separator=","),']') as ?somethings) to aggregate multiple rows

class Tour
  # attr_reader :start_time
  attr_reader :str_start_time
  # attr_reader :end_time
  attr_reader :str_end_time
  attr_reader :events


  def initialize(start_time, end_time)
    if start_time.is_a? Time
      @str_start_time = "#{time_ago_in_words(start_time)} from now"
      @start_time = start_time
    else
      @str_start_time = start_time
      @start_time = Chronic::parse start_time
    end

    if end_time.is_a? Time
      @str_end_time = "#{time_ago_in_words(end_time)} from now"
      @end_time = end_time
    else
      @str_end_time = end_time
      @end_time = Chronic::parse end_time
    end
  end


end
