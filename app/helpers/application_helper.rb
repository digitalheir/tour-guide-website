require 'rdf'
require 'rdf/rdfxml'
require 'nokogiri'

include RDF
module ApplicationHelper
  def self.sample(set)
    set.each do |el|
      return el
    end
    nil
  end
end