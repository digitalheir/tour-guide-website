require 'open-uri'
task :wake_up do
  puts "YAAAWWWWN #{open('http://tour-guide.herokuapp.com/')}"
end