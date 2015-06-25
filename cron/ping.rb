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
  return to_ostruct(YAML::load_file('/sites/pandapath/config/panda.yaml'))
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
  start=Time.now
  puts "BEGIN #{start}"
  c=config()
  resp=[]
  dbfile="#{c.proj_directory}#{c.db_file}"
  db = SQLite3::Database.new dbfile
  c.characters.each{ |p|
    t="http://us.battle.net/api/wow/character/#{p.realm}/#{p.name}?fields=quests,items&locale=en_US&apikey=#{c.wow_secret}"
    puts "api call to: #{t}"
    r = Curl::Easy.perform(t);
    j=JSON.parse(r.body);
    resp.push j
    char=to_ostruct(j)
    char_db=db.execute("SELECT persona_id, level, last_render, last_quest, last_location, gear_md5 FROM persona WHERE name=? AND realm=?",char.name, char.realm)
    if char_db.length>0
      puts "search for name/realm:     id, level, last render, last quest, last location, gear md5"
      puts "Found for #{char.name}/#{char.realm}: #{char_db[0].join(',    ')}"
      rerender=false
      ding=false
      if char_db[0][1]!=char.level
        rerender=true
        ding=true
      end
      char=personify_json(char, char_db)
      char=rerender(c, char ) if char.last_render < Date.today.prev_month.to_time.to_i
      char=persona_update( char )
      ding_level_up(char) if ding
    else
      new_persona char
    end
  }
  end_time=Time.now
  puts "END #{end_time}, #{end_time-start} seconds to process #{c.characters.length} characters"
  return resp
end

def icon_fetch(icon)
  conf=config
  t="http://wow.zamimg.com/images/wow/icons/large/#{icon}.jpg"
  command="curl #{t} > #{conf.proj_directory}#{conf.icon_dir}#{icon}.jpg"
  puts command
  `#{command}`
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
def ding_level_up(c)
  t=Time.now.to_i
  conf=config()
  db = SQLite3::Database.new "#{conf.proj_directory}#{conf.db_file}"
  db.execute("INSERT INTO ding VALUES (?, ?, ?, ?)", c.level, c.pid, t, c.last_location)
end

def persona_update( char )
  puts "***** persona update for #{char.realm}/#{char.name} *****"
  c=quest_check(char)
  c=gear_check(c)
  store_persona(c)
  puts "***** END persona update for #{char.realm}/#{char.name} *****"
  return c
end

def store_persona(c)
  puts 'store_persona'
  conf=config()
  db = SQLite3::Database.new "#{conf.proj_directory}#{conf.db_file}"
  puts "last_render, last_quest, last_location, level, gear_md5, name, realm"
  puts "#{c.last_render}, #{c.last_quest}, #{c.last_location}, #{c.level}, #{c.gear_md5}, #{c.name}, #{c.realm}"
  db.execute("UPDATE persona SET last_render=?, last_quest=?, last_location=?, level=?, gear_md5=?  WHERE name=? AND realm=?", c.last_render,  c.last_quest, c.last_location, c.level, c.gear_md5, c.name, c.realm)
  puts "/store_persona\n\n"
end

def personify_json(char, char_db)
  c=char_db.first
  puts "personify: #{c}"
  char.pid=c.shift
  char.level=c.shift
  char.last_render=c.shift
  char.last_quest=c.shift
  char.last_location=c.shift
  char.last_location=1
  char.gear_md5=c.shift
  puts "/personify\n\n"
  return char
end

def new_persona( char )
  puts "***** new persona: #{char.realm}/#{char.name} *****"
  conf=config()
  db = SQLite3::Database.new "#{conf.proj_directory}#{conf.db_file}"
  c=gear_massage(char)
  i=c.items
  t=Time.now.to_i
  db.execute("INSERT INTO persona (name,realm,last_render,level) VALUES (?, ?, ?, ?)", c.name, c.realm, t, c.level)
    char_db=db.execute("SELECT persona_id, level, last_render, last_quest, last_location, gear_md5 FROM persona WHERE name=? AND realm=?",char.name, char.realm)
  puts "char_db #{char_db.first.join(',')}"
  char=personify_json(char, char_db)
	db.execute( 'INSERT INTO current_gear VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? );', char.pid, i.head.id, i.neck.id, i.shoulder.id, i.back.id, i.chest.id, i.shirt.id, i.tabard.id, i.wrist.id, i.hands.id, i.waist.id, i.legs.id, i.feet.id, i.finger1.id, i.finger2.id, i.trinket1.id, i.trinket2.id, i.mainHand.id, i.offHand.id )
  c=rerender(conf, c )
  c=quest_check(c, true)
  c=gear_check(char, true)
  ding_level_up(c)
  store_persona(c)
  puts "***** END new persona: #{char.realm}/#{char.name} *****"
end

def quest_check( char, new_character=false )
  conf=config()
  db = SQLite3::Database.new "#{conf.proj_directory}#{conf.db_file}"
  puts 'quest check'
  quests = char.quests
  c=quests.shift
  t=Time.now.to_i
  last_quest=char.last_quest
  puts 'eating old quests'
  while !new_character&&last_quest!=c&&quests.length>0
    c=quests.shift
  end
  new_quests=Array.new quests
  if new_quests.length>0
    update_quest( new_quests )
  end
  puts "storing #{quests.length} new quests"
  while quests.length>0
    c=quests.shift
    db.execute("INSERT INTO quest_complete VALUES ( ?, ?, ? )", c, char.pid, t )
    c=quests.shift
    char.last_quest=c
  end
  if last_quest!=char.last_quest
    char.dirty=true
  end
  puts "/quest check\n\n"
  return char
end

def update_quest( new_quests )
  conf=config()
  db = SQLite3::Database.new "#{conf.proj_directory}#{conf.db_file}"
  c = config()
  puts 'update quest'
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
  puts "Quest count: #{quests.length}"
  loc_id=nil
  quests.each{ |q|
    t="http://us.battle.net/api/wow/quest/#{q}?locale=en_US&apikey=#{c.wow_secret}"
    r = Curl::Easy.perform(t);
    j=JSON.parse(r.body);
    c=to_ostruct(j)
    db.execute("INSERT OR IGNORE INTO location (zone) VALUES( ? );", c.category)
    loc_id=db.last_insert_row_id
    puts "#{q},#{c.title},#{c.level},#{loc_id}"
    db.execute("INSERT OR IGNORE INTO quest VALUES( ?, ?, ?, ? );", q, c.title, c.level, loc_id)
  }
  puts "/update quest\n\n"
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
  puts 'gear check'
  md5=Digest::MD5.new
  c=gear_massage(c) unless skip_massage
  i=c.items
  conf=config()
  db = SQLite3::Database.new "#{conf.proj_directory}#{conf.db_file}"
  gear=[i.head.id, i.neck.id, i.shoulder.id, i.back.id, i.chest.id, i.shirt.id, i.tabard.id, i.wrist.id, i.hands.id, i.waist.id, i.legs.id, i.feet.id, i.finger1.id, i.finger2.id, i.trinket1.id, i.trinket2.id,i.mainHand.id, i.offHand.id, c.pid ]
  md5.update gear.join('')
  md5=String(md5)
	db.execute( 'UPDATE current_gear SET head=?, neck=?, shoulder=?, back=?, chest=?, shirt=?, tabard=?, wrist=?, hands=?, waist=?, legs=?, feet=?, finger1=?, finger2=?, trinket1=?, trinket2=?, mainHand=?, offHand=? WHERE persona_id=?;', )
  #puts "new md5: #{md5}"
  #puts "old md5: #{c.gear_md5}"
  if c.gear_md5!=md5
    c.dirty=true
    c.gear_md5=md5
    update_armory(c)
  end
  puts "/gear check\n\n"
  return c
end

def update_armory( char )
  puts 'update armory'
  conf=config()
  db = SQLite3::Database.new "#{conf.proj_directory}#{conf.db_file}"
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
      icon_fetch item.icon
      puts "#{id},#{item.name},#{item.icon},#{item.quality},#{item.slot}"
      db.execute("INSERT OR IGNORE INTO item VALUES( ?, ?, ?, ?, ? );",id, item.name, item.icon, item.quality, slot)
    end
    t=Time.now.to_i
    db.execute("INSERT OR IGNORE INTO gear (item_id, persona_id, time, loc_id) VALUES ( ?, ?, ?, ?);", id, char.pid,t, char.last_location)
  end
  puts "/update armory\n\n"
end
send( ARGV[0] )
