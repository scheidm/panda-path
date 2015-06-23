require 'ostruct'
require 'date'
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
    c=to_ostruct(j)
    char_db=db.execute("SELECT persona_id, level, last_render, last_quest, last_location, gear_md5 FROM persona WHERE name=? AND realm=?",c.name, c.realm)
    puts char_db[0]
    if char_db.length>0
      rerender=false
      ding=false
      puts char_db[0][1]
      puts c.level
      if char_db[0][1]!=c.level
        rerender=true
        ding=true
      end
      puts ding
      c=personify_json(c, char_db)
      rerender if c.last_render < Date.today.prev_month.to_time.to_i
      c=persona_update( c )
      ding_level_up(c) if ding
    else
      new_persona c
    end
  }
  return resp
end

def ding_level_up(c)
  t=Time.now.to_i
  db = SQLite3::Database.new "pandaren.db"
  db.execute("INSERT INTO ding VALUES (?, ?, ?, ?)", c.level, c.pid, t, c.last_location)
end

def persona_update( char )
  db = SQLite3::Database.new "pandaren.db"
  c=quest_check(char)
  c=gear_check(c)
  if c.dirty
    db.execute("UPDATE OR IGNORE persona SET last_quest=?, last_location=?, level=?  WHERE name=? AND realm=?", c.last_quest, c.last_location, c.level, char["name"], char["realm"])
  end
  return c
end

def personify_json(char, char_db)
  c=char_db.first
  char.pid=c.shift
  char.level=c.shift
  char.last_render=c.shift
  char.last_quest=c.shift
  char.last_location=c.shift
  char.last_location=1
  char.gear_md5=c.shift
  return char
end

def new_persona( char )
  puts 'new_persona'
  db = SQLite3::Database.new "pandaren.db"
  t=Time.now.to_i
  c=gear_massage(char)
  i=c.items
  db.execute("INSERT INTO persona (name,realm,last_render,level) VALUES (?, ?, ?, ?)", c.name, c.realm, t, c.level)
  char_db=db.execute("SELECT persona_id, last_render, last_quest, gear_md5 FROM persona WHERE name=? AND realm=?", c.name, c.realm)
  char=personify_json(char, char_db)
	db.execute( 'INSERT INTO current_gear VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? );', char.pid, i.head.id, i.neck.id, i.shoulder.id, i.back.id, i.chest.id, i.shirt.id, i.tabard.id, i.wrist.id, i.hands.id, i.waist.id, i.legs.id, i.feet.id, i.finger1.id, i.finger2.id, i.trinket1.id, i.trinket2.id, i.mainHand.id, i.offHand.id )
  c=quest_check(c, true)
  c=gear_check(char, true)
  ding_level_up(c)
  puts '/new_persona'
end

def quest_check( char, new_character=false )
  db = SQLite3::Database.new "pandaren.db"
  puts 'quest update'
  quests = char.quests
  c=quests.shift
  t=Time.now.to_i
  last_quest=char.last_quest
  puts "Last quest: #{char.last_quest}"
  puts last_quest
  while !new_character&&last_quest!=c&&quests.length>0
    puts 'eating old quests'
    c=quests.shift
  end
  new_quests=Array.new quests
  if new_quests.length>0
    update_quest( new_quests )
  end
  while quests.length>0
    puts "storing new quests: #{c}"
    c=quests.shift
    db.execute("INSERT INTO quest_complete VALUES ( ?, ?, ? )", c, char.pid, t )
    c=quests.shift
    char.last_quest=c
  end
  puts "Last quest: #{char.last_quest}"
  if last_quest!=char.last_quest
    char.last_quest=last_quest
    char.dirty=true
  end
  puts '/quest update'
  return char
end

def update_quest( new_quests )
  db = SQLite3::Database.new "pandaren.db"
  c = config()
  puts 'update'
  #quest_list=new_quests.join(', ')
  #existing = db.execute("SELECT quest_id FROM quest WHERE quest_id IN ( ? ) ORDER BY quest_id ASC;", quest_list)
  #This is such a kludge, figure out why the above isn't working asap
  existing=[]
  db.execute("SELECT quest_id FROM quest;") do |id|
    existing.push id[0]
  end
  if existing.nil?
    existing=[]
  end
  quests=new_quests-existing
  print "Quest count: #{quests.length}"
  loc_id=nil
  quests.each{ |q|
    t="http://us.battle.net/api/wow/quest/#{q}?locale=en_US&apikey=#{c.wow_secret}"
    r = Curl::Easy.perform(t);
    j=JSON.parse(r.body);
    c=to_ostruct(j)
    db.execute("INSERT OR IGNORE INTO location (zone) VALUES( ? );", c.category)
    loc_id=db.last_insert_row_id
    db.execute("INSERT OR IGNORE INTO quest VALUES( ?, ?, ?, ? );", q, c.title, c.level, loc_id)
  }
  return loc_id
end

def gear_massage( char )
  columns=["head","neck","shoulder","back","chest","shirt","tabard","wrist","hands","waist","legs","feet","finger1","finger2","trinket1","trinket2","mainHand","offHand"]
  equipped = OpenStruct.new
  equipped.ids = []
  equipped.slots = []
  char.equipped=equipped
  columns.each{ |slot|
    cur =char.items[ slot ] 
    puts cur
    if cur.nil?||cur['id'].nil? then
      i=OpenStruct.new
      i.id='NULL'
      char.items[ slot ]=i
    else
      char.equipped.ids.push(cur['id'])
      char.equipped.slots.push(slot)
    end
  }
  return char
end
 
def gear_check( c, skip_massage=false )
  md5=Digest::MD5.new
  c=gear_massage(c) unless skip_massage
  i=c.items
  puts i
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
  puts 'equipped'
  db = SQLite3::Database.new "pandaren.db"
  item_ids=char.equipped.ids.join(', ')
  existing = db.execute('SELECT item_id FROM item WHERE item_id IN (?);', item_ids)
  if existing.nil?
    existing=[]
  end
  puts char.equipped
  for i in 0..char.equipped.ids.length-1
    id=char.equipped.ids[i]
    slot=char.equipped.slots[i]
    item=char.items[slot]
    l=existing.length 
    existing.delete_if{ |x|
      x==id
    }
    if existing.length==l
      puts "#{id},#{item.name},#{item.icon},#{item.quality},#{item.slot}"
      db.execute("INSERT OR IGNORE INTO item VALUES( ?, ?, ?, ?, ? );",id, item.name, item.icon, item.quality, slot)
    end
    t=Time.now.to_i
    db.execute("INSERT OR IGNORE INTO gear (item_id, persona_id, time, loc_id) VALUES ( ?, ?, ?, ?);", id, char.pid,t, char.last_location)
  end
end
api_call
