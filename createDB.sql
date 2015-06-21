CREATE TABLE persona (
  persona_id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  realm TEXT NOT NULL,
  last_render INTEGER NOT NULL,
  level INTEGER NOT NULL,
  UNIQUE (name,realm)
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
CREATE TABLE items (
  item_id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  name TEXT NOT NULL,
  icon TEXT NOT NULL,
  quality TEXT NOT NULL,
  slot TEXT NOT NULL
);
CREATE TABLE render (
  render_id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  time INTEGER NOT NULL,
  persona_id INTEGER NOT NULL,
  FOREIGN KEY(persona_id) REFERENCES persona(persona_id)
);
CREATE TABLE ding (
  ding_id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  persona_id INTEGER NOT NULL,
  time integer NOT NULL,
  zone TEXT NOT NULL,
  top integer,
  left integer,
  level INTEGER NOT NULL,
  FOREIGN KEY(persona_id) REFERENCES persona(persona_id)
);
CREATE TABLE quest (
  quest_id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  persona_id INTEGER NOT NULL,
  time integer NOT NULL,
  zone TEXT NOT NULL,
  top integer,
  left integer,
  quest_lvl INTEGER,
  FOREIGN KEY(persona_id) REFERENCES persona(persona_id)
);
CREATE TABLE gear (
  gear_id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  persona_id INTEGER NOT NULL,
  time integer NOT NULL,
  zone TEXT NOT NULL,
  top integer,
  left integer,
  FOREIGN KEY(persona_id) REFERENCES persona(persona_id)
);
