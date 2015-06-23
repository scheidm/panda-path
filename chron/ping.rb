require 'ostruct'
require 'digest'
require 'yaml'
require 'curb'
require 'json'
require 'sqlite3'
require 'headless'
require 'selenium-webdriver'



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

def wowhead_scrape(ids)
  headless = Headless.new
  headless.start

  driver = Selenium::WebDriver.for :firefox
  locs={}
  ids.each{ |id|
    driver.navigate.to "http://www.wowhead.com/quest=#{id}"
    loc_string=driver.page_source.slice(/pin-(start)?end[^>]*/)
    m=loc_string.match(/left: ([0-9.]*)%; top: ([0-9.]*)%/)
    locs[id]={ left: m[1], top: m[2] }
  }
  headless.destroy
  return locs
end

def api_call
  c=config()
  resp=[]
  db = SQLite3::Database.new "pandaren.db"
  c.characters.each{ |p|
    t="http://us.battle.net/api/wow/character/#{p.server}/#{p.name}?fields=quests,items&locale=en_US&apikey=#{c.wow_secret}"
    r = Curl::Easy.perform(t);
    j=JSON.parse(r.body);
    resp.push j
    char_db=db.execute("SELECT persona_id, last_render, last_quest, gear_md5 FROM persona WHERE name=? AND realm=?",j['name'], j['realm'])
    if char_db.length>0
      personif_json(char, char_db)
      persona_update( j, char_db )
    else
      new_persona j
    end
  }
  return resp
end

def persona_update( char,char_db )
  db = SQLite3::Database.new "pandaren.db"
  t=Time.now.to_i
  c=gear_check(char)
  c=quest_update(c)
  db.execute("UPDATE OR IGNORE persona SET level=?, last_render=? WHERE name=? AND realm=?", char["level"], t, char["name"], char["realm"])
end

def personify_json(char, char_db)
  char['pid']=char_db.shift
  char['last_render']=char_db.shift
  char['last_quest']=char_db.shift
  char['gear_md5']=char_db.shift
  return char
end

def new_persona( char )
  puts 'new_persona'
  db = SQLite3::Database.new "pandaren.db"
  t=Time.now.to_i
  c=to_ostruct( gear_massage(char) )
  puts c
  i=c.items
  db.execute("INSERT INTO persona (name,realm,last_render,level) VALUES (?, ?, ?, ?)", c.name, c.realm, t, c.level)
  char_db=db.execute("SELECT persona_id, last_render, last_quest, gear_md5 FROM persona WHERE name=? AND realm=?", c.name, c.realm).first
  char=personify_json(char, char_db)
	db.execute( 'INSERT INTO current_gear VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? );', char['pid'], i.head.id, i.neck.id, i.shoulder.id, i.back.id, i.chest.id, i.shirt.id, i.tabard.id, i.wrist.id, i.hands.id, i.waist.id, i.legs.id, i.feet.id, i.finger1.id, i.finger2.id, i.trinket1.id, i.trinket2.id, i.mainHand.id, i.offHand.id )
  c=gear_check(char)
  quest_update(c)
  puts db.changes
  puts '/new_persona'
end

def quest_update( char )
  db = SQLite3::Database.new "pandaren.db"
  puts 'quest update'
  quests = char.quests
  c=quests.shift
  t=Time.now.to_i
  last_quest=char.last_quest
  while !last_quest.nil?&&last_quest!=c&&quests.length>0
    puts 'eating old quests'
    c=quests.shift
  end
  while quests.length>0
    puts 'storing new quests'
    c=quests.shift
    last_quest=c
    db.execute("INSERT INTO quest_complete VALUES ( ?, ?, ? )", c, char.pid, t )
    c=quests.shift
  end
  if last_quest!=char.last_quest
    db.execute( 'UPDATE persona SET last_quest=? WHERE persona_id=?', last_quest, char.pid)
  end
  puts '/quest update'
end

def gear_massage( char )
  columns=["head","neck","shoulder","back","chest","shirt","tabard","wrist","hands","waist","legs","feet","finger1","finger2","trinket1","trinket2","mainHand","offHand"]
  char['equipped']={ 'ids' => [], 'slots' => []}
  columns.each{ |slot|
    cur =char['items'][ slot ] 
    puts cur
    if cur.nil?||cur['id'].nil? then
      char['items'][ slot ]={id: 'NULL'}
      puts 'nil'
    else
      char['equipped']['ids'].push(cur['id'])
      char['equipped']['slots'].push(slot)
    end
  }
  return char
end
 
def gear_check( char )
  md5=Digest::MD5.new
  c=to_ostruct( gear_massage(char) )
  i=c.items
  puts c
  db = SQLite3::Database.new "pandaren.db"
  gear=[i.head.id, i.neck.id, i.shoulder.id, i.back.id, i.chest.id, i.shirt.id, i.tabard.id, i.wrist.id, i.hands.id, i.waist.id, i.legs.id, i.feet.id, i.finger1.id, i.finger2.id, i.trinket1.id, i.trinket2.id,i.mainHand.id, i.offHand.id, c.pid ]
  md5.update gear.join('')
  md5=String(md5)
	db.execute( 'UPDATE current_gear SET head=?, neck=?, shoulder=?, back=?, chest=?, shirt=?, tabard=?, wrist=?, hands=?, waist=?, legs=?, feet=?, finger1=?, finger2=?, trinket1=?, trinket2=?, mainHand=?, offHand=? WHERE persona_id=?;', )
  if c.gear_md5!=md5
    puts 'updating armory'
    c.gear_md5=md5
    db.execute( 'UPDATE persona SET gear_md5=? WHERE persona_id=?;', md5, c.pid )
    update_armory(c)
  end
  return c
end

def update_armory( char )
  puts 'equipped'
  puts char.equipped
  puts 'equipped'
  db = SQLite3::Database.new "pandaren.db"
  existing = db.execute('SELECT item_id FROM item WHERE item_id IN (?);',char.equipped.ids.join(', '))
  if existing.nil?
    existing=[]
  end
  for i in 0..char.equipped.ids.length-1
    id=char.equipped.ids[i]
    slot=char.equipped.slots[i]
    item=char.items[slot]
    l=existing.length 
    existing.delete_if{ |x|
      x==id
    }
    if existing.length==l
      db.execute("INSERT OR IGNORE INTO item VALUES( ?, ?, ?, ?, ? );",id, item.name, item.icon, item.quality, slot)
    end
    t=Time.now.to_i
    db.execute("INSERT INTO gear (item_id, persona_id, time) VALUES ( ?, ?, ?);", id, char.pid,t)
  end
end
api_call
