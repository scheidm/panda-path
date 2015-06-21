require 'ostruct'
require './ping'
require 'yaml'
require 'curb'
require 'json'



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

def split(filearg)
  filename=filearg.split('.')[0]
  return filename.split('/')
end

def config()
  conf = YAML::load_file('panda.yaml')
  return to_ostruct(conf)
end

def main()
  s=ARGV[0]
  context = config()
  print s.sub(context.source_dir,'')
  structure=split(s)
  if structure[2]=='layouts' then
    print 'layout updated'
    updates=Dir.glob(context.source_dir+'pages/**/*').select{ |e| File.file? e }
    updates.each{ |page|
      print "update #{page}\n"
      update(page)
    }
  else 
    update(s)
  end
end
c=config()
cur=c.characters.first
t="http://us.battle.net/api/wow/character/#{cur.server}/#{cur.name}?fields=quests,items&locale=en_US&apikey=#{c.wow_secret}"
r = Curl::Easy.perform(t);
j=JSON.parse(r.body);
puts j
