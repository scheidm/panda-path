CREATE TABLE persona (
  persona_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  realm TEXT NOT NULL,
  last_render INTEGER NOT NULL,
  level INTEGER NOT NULL,
  UNIQUE (name,realm)
);
CREATE TABLE quest (
  quest_id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  zone TEXT NOT NULL,
  top integer,
  left integer,
  quest_lvl INTEGER
);
CREATE TABLE item (
  item_id INTEGER PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  quality TEXT NOT NULL,
  slot TEXT NOT NULL
);
CREATE TABLE current_gear (
  persona_id INTEGER PRIMARY KEY NOT NULL,
  head INTEGER DEFAULT NULL,
  neck INTEGER DEFAULT NULL,
  shoulder INTEGER DEFAULT NULL,
  back INTEGER DEFAULT NULL,
  chest INTEGER DEFAULT NULL,
  shirt INTEGER DEFAULT NULL,
  tabard INTEGER DEFAULT NULL,
  wrist INTEGER DEFAULT NULL,
  hands INTEGER DEFAULT NULL,
  waist INTEGER DEFAULT NULL,
  legs INTEGER DEFAULT NULL,
  feet INTEGER DEFAULT NULL,
  finger1 INTEGER DEFAULT NULL,
  finger2 INTEGER DEFAULT NULL,
  trinket1 INTEGER DEFAULT NULL,
  trinket2 INTEGER DEFAULT NULL,
  mainHand INTEGER DEFAULT NULL,
  offHand INTEGER DEFAULT NULL,
  FOREIGN KEY(persona_id) REFERENCES persona(persona_id)
);
CREATE TABLE render (
  render_id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  time INTEGER NOT NULL,
  persona_id INTEGER NOT NULL,
  FOREIGN KEY(persona_id) REFERENCES persona(persona_id)
);
CREATE TABLE ding (
  level INTEGER NOT NULL,
  persona_id INTEGER NOT NULL,
  time integer NOT NULL,
  zone TEXT NOT NULL,
  top integer,
  left integer,
  FOREIGN KEY(persona_id) REFERENCES persona(persona_id),
  UNIQUE(level, persona_id)
);
CREATE TABLE quest_complete(
  quest_id INTEGER NOT NULL,
  persona_id INTEGER NOT NULL,
  time integer NOT NULL,
  FOREIGN KEY(quest_id) REFERENCES quest(quest_id),
  FOREIGN KEY(persona_id) REFERENCES persona(persona_id),
  UNIQUE (quest_id, persona_id)
);
CREATE TABLE gear (
  item_id INTEGER NOT NULL,
  persona_id INTEGER NOT NULL,
  time integer NOT NULL,
  zone TEXT NOT NULL,
  top integer,
  left integer,
  FOREIGN KEY(persona_id) REFERENCES persona(persona_id),
  FOREIGN KEY(item_id) REFERENCES item(item_id),
  UNIQUE (item_id, persona_id)
);
