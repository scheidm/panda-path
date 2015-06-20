var express = require('express');
var app     = express();
function curl(url, file){
  var util = require('util');
  var exec = require('child_process').exec;
  var command = util.format('curl %s > %s', url, file);
  console.log(command);
  exec(command, function(error, stdout, stderr){

    console.log('stdout: ' + stdout);
    console.log('stderr: ' + stderr);

    if(error !== null) {
      console.log('exec error: ' + error);
    }else{
      console.log("curl complete");
    }
  });
}
function download_character_render(server,character){
  var http = require('http');
  var util = require('util');
  var request = require('request');
  var cheerio = require('cheerio');
	var url = util.format('http://us.battle.net/wow/en/character/%s/%s/simple',server,character);
  console.log("pinging "+url);

	request(url, function(error, response, html){
		if(!error){
      var juice = require('juice');
      var result = juice(html);
			var $ = cheerio.load(result);
      var image = $('#profile-wrapper').css('background-image')
      image = image.replace(/^url|[\(\)]/g, '');
      console.log("downloading "+image);
      var filename=util.format("%s-%s.jpg",server,character);
      curl(image, filename);
      console.log(filename);
    }else{
      console.log("server unreachable");
    }

  })
  console.log("download character render complete");
}
function api_call(server, character, fields, cb){
  console.log("api_call");
  var config = require('./config');
  var util = require('util');
  var request = require('request');
	var url = util.format('http://us.battle.net/api/wow/character/%s/%s?fields=%s&locale=en_US&apikey=%s', server, character, fields, config.api_key);
	request(url, function(error, response, json ){
		if(!error){
        j=JSON.parse(json);
        cb(j);
    }
  });
  console.log("api_call");
}
function query_gear_check(j){
  var fs = require("fs");
  var db_file = "pandaren.db";
  var sqlite3 = require("sqlite3").verbose();
  var db = new sqlite3.Database(db_file);
  var util = require('util');
	var query = util.format("SELECT * from current_gear WHERE (name = '%s' AND realm='%s')", j.name, j.realm);
  console.log(query);
  var missing=true;
  db.each(query, function(err, row) {
    missing=false;
    gear_check(j,row);
    console.log(row);
  });
  db.close();
  if(missing){
    console.log('missing');
    gear_check(j);
  }
  
}
function gear_check(j,current_ids){
  var util = require('util');
  var columns=["head","neck","shoulder","back","chest","shirt","tabard","wrist","hands","waist","legs","feet","finger1","finger2","trinket1","trinket2","mainHand","offHand"];
  var items_flagged=[];
  for ( var n in columns ){
    var slot=columns[n];
    if(!j.items[ slot  ]){
      j.items[ slot ]={id: "NULL"};
    }else{
      items_flagged.push( j.items[ slot ] );
    }
  }
  j.name='"'+j.name+'"';
  j.realm='"'+j.realm+'"';
  gear_update(j);
  console.log("gear_check");
}

function item_check(j, slot, current_ids){
  console.log('item_check');
  var util = require('util');
  var new_row = false;
  var new_gear=j.items[ slot ];
  var columns=["name","icon"];
  for ( var c in columns ){
    var column = columns[c];
    new_gear[column]='"'+new_gear[column]+'"';
  }
  var statement = util.format( 'INSERT OR IGNORE INTO items VALUES ( %s, %s, %s, %s, %s );',
    new_gear.id, new_gear.name, new_gear.icon, new_gear.quality, '"'+slot+'"' );
  if (typeof current_ids !== 'undefined') {
    if( parseint(current_ids[ slot ])==parseint(new_gear.id) ){
      console.log('same old '+slot);
    }else{
      console.log("new id "+new_gear.id);
    }
  }else{
    new_row = true;
  }
  console.log(statement);
  if(new_row){db_save(statement)};
}

function gear_update(j){
  var util = require('util');
	var update = util.format( "UPDATE OR IGNORE current_gear SET head=%s, neck=%s, shoulder=%s, back=%s, chest=%s, shirt=%s, tabard=%s, wrist=%s, hands=%s, waist=%s, legs=%s, feet=%s, finger1=%s, finger2=%s, trinket1=%s, trinket2=%s, mainHand=%s, offHand=%s WHERE name=%s AND realm=%s;", j.items.head.id, j.items.neck.id, j.items.shoulder.id, j.items.back.id, j.items.chest.id, j.items.shirt.id, j.items.tabard.id, j.items.wrist.id, j.items.hands.id, j.items.waist.id, j.items.legs.id, j.items.feet.id, j.items.finger1.id, j.items.finger2.id, j.items.trinket1.id, j.items.trinket2.id, j.items.mainHand.id, j.items.offHand.id,j.name, j.realm );
	var ignore = util.format( "INSERT OR IGNORE INTO current_gear VALUES ( %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,%s, %s, %s, %s, %s );", j.name, j.realm, j.items.head.id, j.items.neck.id, j.items.shoulder.id, j.items.back.id, j.items.chest.id, j.items.shirt.id, j.items.tabard.id, j.items.wrist.id, j.items.hands.id, j.items.waist.id, j.items.legs.id, j.items.feet.id, j.items.finger1.id, j.items.finger2.id, j.items.trinket1.id, j.items.trinket2.id, j.items.mainHand.id, j.items.offHand.id);
  db_save(update); 
  db_save(ignore); 
}

function db_save(statement){
  var fs = require("fs");
  var db_file = "pandaren.db";
  var sqlite3 = require("sqlite3").verbose();
  var db = new sqlite3.Database(db_file);
  db.serialize(function(){
    console.log("db_save");
    console.log(statement);
    console.log('state');
    stmt = db.prepare(statement);
    stmt.run();
    stmt.finalize();
  });
  db.close();
  console.log("db_save");
}

app.get('/scrape', function(req, res){
  //api_call("ysera", "mysunanstars", "items", query_gear_check);

  
  //console.log('main');
  //api_call("ysera", "mysunanstars", "items", gear_check);
  //var character = quest_update('ysera', 'Mysunanstars');
  //download_character_render("firetree","Corradhledo"); 
  res.send('Check your console!')
})

app.listen('8081')
console.log('Magic happens on port 8081');
exports = module.exports = app; 	
