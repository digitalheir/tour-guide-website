require 'open-uri'
task :wake_up do
  open('http://tour-guide.herokuapp.com/')
end