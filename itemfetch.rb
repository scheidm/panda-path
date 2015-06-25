require 'sqlite3'
require 'yaml'
require 'ostruct'
def icon_fetch(icon)
  conf=config
  t="http://wow.zamimg.com/images/wow/icons/large/#{icon}.jpg"
  command="curl #{t} > #{conf.proj_directory}#{conf.icon_dir}#{icon}.jpg"
  puts command
  `#{command}`
end
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

def config()
  return to_ostruct(YAML::load_file('/sites/pandapath/config/panda.yaml'))
end

def rerender(c, char)
  puts 'rerender'
  script="#{c.proj_directory}#{c.render_script}"
  out_dir="#{c.proj_directory}#{c.render_dir}"
  command="node #{script} #{char.realm} #{char.name} #{char.level} #{out_dir}"
  puts command
  `#{command}`
  char.last_render=Time.now.to_i
  puts "/rerender\n\n"
  return char
end 

conf=config

#dbfile="#{conf.proj_directory}#{conf.db_file}"
#db = SQLite3::Database.new dbfile
#db.execute("select icon from item;") do |icon|
#  icon_fetch( icon[0] )
#end
conf.characters.each do |char|
  char['level']=16
  rerender(conf, to_ostruct(char))
end
