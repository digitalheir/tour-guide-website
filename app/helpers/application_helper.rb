module ApplicationHelper
  def self.sample(set)
    set.each do |el|
      return el
    end
    nil
  end
end