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

def config()
  conf = YAML::load_file('panda.yaml')
  return to_ostruct(conf)
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
    char_db=db.execute("SELECT persona_id, level, last_render, last_quest, last_location, gear_md5 FROM persona WHERE name=? AND realm=?",j['name'], j['realm'])
    if char_db.length>0
      if char_db[0][1]!=j['level']
        `node c.render_script`
        char_db[0][2]-Time.now.to_i
      end
      j=personify_json(j, char_db)
      puts j
      persona_update( j )
    else
      new_persona j
    end
  }
  return resp
end

def persona_update( char )
  db = SQLite3::Database.new "pandaren.db"
  c=quest_check(to_ostruct(char))
  c=gear_check(c)
  if c.dirty
    db.execute("UPDATE OR IGNORE persona SET last_quest=?, last_location=?, level=?  WHERE name=? AND realm=?", c.last_quest, c.last_location, c.level, char["name"], char["realm"])
  end
end

def personify_json(char, char_db)
  c=char_db.first
  char['pid']=c.shift
  char['level']=c.shift
  char['last_render']=c.shift
  char['last_quest']=c.shift
  char['last_location']=c.shift
  char['gear_md5']=c.shift
  return char
end

def new_persona( char )
  puts 'new_persona'
  db = SQLite3::Database.new "pandaren.db"
  t=Time.now.to_i
  c=to_ostruct( gear_massage(char) )
  i=c.items
  db.execute("INSERT INTO persona (name,realm,last_render,level) VALUES (?, ?, ?, ?)", c.name, c.realm, t, c.level)
  char_db=db.execute("SELECT persona_id, last_render, last_quest, gear_md5 FROM persona WHERE name=? AND realm=?", c.name, c.realm).first
  char=personify_json(char, char_db)
	db.execute( 'INSERT INTO current_gear VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? );', char['pid'], i.head.id, i.neck.id, i.shoulder.id, i.back.id, i.chest.id, i.shirt.id, i.tabard.id, i.wrist.id, i.hands.id, i.waist.id, i.legs.id, i.feet.id, i.finger1.id, i.finger2.id, i.trinket1.id, i.trinket2.id, i.mainHand.id, i.offHand.id )
  c=quest_check(c)
  c=gear_check(char)
  puts '/new_persona'
end

def quest_check( char )
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
  new_quests=Array.new quests
  loc=nil
  if new_quests.length>0
    loc=update_quest( new_quests )
  end
  while quests.length>0
    puts 'storing new quests'
    c=quests.shift
    last_quest=c
    db.execute("INSERT INTO quest_complete VALUES ( ?, ?, ? )", c, char.pid, t )
    c=quests.shift
    char.last_quest=c
  end
  if last_quest!=char.last_quest
    char.last_quest=last_quest
    char.last_location=loc
    char.dirty=true
  end
  puts '/quest update'
end

def update_quest( new_quests )
  db = SQLite3::Database.new "pandaren.db"
  c = config()
  quest_list=new_quests.join(', ')
  existing = db.execute("SELECT quest_id FROM quest;")
  puts existing
  puts quest_list
  puts 'update'
  existing = db.execute("SELECT * FROM quest WHERE quest_id IN ( ? );", quest_list)
  if existing.nil?
    existing=[]
  end
  puts existing
  puts 'update'
  puts existing[0].length
  puts 'update'
  quests=new_quests-existing.first
  print "Quest count: #{quests.length}"
  loc_id=nil
  quests.each{ |q|
    t="http://us.battle.net/api/wow/quest/#{q}?locale=en_US&apikey=#{c.wow_secret}"
    r = Curl::Easy.perform(t);
    j=JSON.parse(r.body);
    db.execute("INSERT OR IGNORE INTO location (zone) VALUES( ? );", j['category'])
    loc_id=db.last_insert_row_id
    db.execute("INSERT OR IGNORE INTO quest VALUES( ?, ?, ?, ? );", q, j['title'],j['level'],loc_id)
  }
  return loc_id
end

def gear_massage( char )
  columns=["head","neck","shoulder","back","chest","shirt","tabard","wrist","hands","waist","legs","feet","finger1","finger2","trinket1","trinket2","mainHand","offHand"]
  char.equipped.ids = []
  char.equipped.slots = []
  columns.each{ |slot|
    cur =char['items'][ slot ] 
    if cur.nil?||cur['id'].nil? then
      char['items'][ slot ]={id: 'NULL'}
    else
      char.equipped['ids'].push(cur['id'])
      char.equipped['slots'].push(slot)
    end
  }
  return char
end
 
def gear_check( char )
  md5=Digest::MD5.new
  c=to_ostruct( gear_massage(char) )
  i=c.items
  db = SQLite3::Database.new "pandaren.db"
  gear=[i.head.id, i.neck.id, i.shoulder.id, i.back.id, i.chest.id, i.shirt.id, i.tabard.id, i.wrist.id, i.hands.id, i.waist.id, i.legs.id, i.feet.id, i.finger1.id, i.finger2.id, i.trinket1.id, i.trinket2.id,i.mainHand.id, i.offHand.id, c.pid ]
  md5.update gear.join('')
  md5=String(md5)
	db.execute( 'UPDATE current_gear SET head=?, neck=?, shoulder=?, back=?, chest=?, shirt=?, tabard=?, wrist=?, hands=?, waist=?, legs=?, feet=?, finger1=?, finger2=?, trinket1=?, trinket2=?, mainHand=?, offHand=? WHERE persona_id=?;', )
  if c.gear_md5!=md5
    puts 'updating armory'
    c.dirty=true
    update_armory(c)
  end
  return c
end

def update_armory( char )
  puts 'equipped'
  puts char.equipped
  puts 'equipped'
  db = SQLite3::Database.new "pandaren.db"
  item_ids=char.equipped.ids.join(', ')
  existing = db.execute('SELECT item_id FROM item WHERE item_id IN (?);', item_ids)
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
