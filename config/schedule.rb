# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever
require 'yaml'
require 'ostruct'
def to_ostruct(object)
  case object
  when Hash
    OpenStruct.new(Hash[object.map {|k, v| [k, to_ostruct(v)] }])
  when Array
    object.map {|x| to_ostruct(x) }
  else
    object
  end
end
def conf
 return to_ostruct(YAML::load_file('/sites/pandapath/config/panda.yaml'))
end 
conf=conf()
puts conf.log_file
set :output, {:error => conf.proj_directory+conf.log_file, :standard => conf.proj_directory+conf.log_file}
every 1.minute do
  conf=conf()
  to_do="ruby #{conf.proj_directory}cron/ping.rb"
  puts to_do
  command to_do
end
