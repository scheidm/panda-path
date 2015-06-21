require 'ostruct'
require './ping'
require 'yaml'
require 'curb'
require 'json'
require 'sqlite3'



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

def sql
	#var query = util.format("SELECT * from current_gear WHERE (name = '%s' AND realm='%s')", j.name, j.realm);
  #var statement = util.format( 'INSERT OR IGNORE INTO items VALUES ( ?, ?, ?, ?, ? );',
  # new_gear.id, new_gear.name, new_gear.icon, new_gear.quality, '"'+slot+'"' );
	#var update = util.format( "UPDATE OR IGNORE current_gear SET head=?, neck=?, shoulder=?, back=?, chest=?, shirt=?, tabard=?, wrist=?, hands=?, waist=?, legs=?, feet=?, finger1=?, finger2=?, trinket1=?, trinket2=?, mainHand=?, offHand=? WHERE name=? AND realm=?;"
	#var ignore = util.format( "INSERT OR IGNORE INTO current_gear VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,?, ?, ?, ?, ? );"
end

def api_call
  c=config()
  resp=[]
  c.characters.each{ |p|
    t="http://us.battle.net/api/wow/character/#{p.server}/#{p.name}?fields=quests,items&locale=en_US&apikey=#{c.wow_secret}"
    r = Curl::Easy.perform(t);
    j=JSON.parse(r.body);
    resp.push j
    persona_update( to_ostruct(j) )
  }
  return resp
end

def persona_update( char )
  db = SQLite3::Database.new "pandaren.db"
  t=Time.now.to_i
  db.execute("INSERT OR IGNORE INTO persona (name,realm,last_render,level) VALUES (?, ?, ?, ?)", char.name, char.realm, t, char.level)
  db.execute("UPDATE OR IGNORE persona SET level=?, last_render=? WHERE name=? AND realm=?", char.level, t, char.name, char.realm)
end
