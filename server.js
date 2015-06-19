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
  db.each(query, function(err, row) {
      console.log(row);
  });
}
function gear_check(j,current){
  console.log("gear_check");
  var columns=["head","neck","shoulder","back","chest","shirt","tabard","wrist","hands","waist","legs","feet","finger1","finger2","trinket1","trinket2","mainHand","offHand"];
  for ( var n in columns ){
    if(!j.items[ columns[n] ]){
      j.items[ columns[n] ]={id: "NULL"};
    }else{
    }
  }
  j.name='"'+j.name+'"';
  j.realm='"'+j.realm+'"';
  var util = require('util');
	var statement = util.format( 'INSERT INTO current_gear VALUES ( %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,%s, %s, %s, %s, %s );',
    j.name,
    j.realm,
    j.items.head.id,
    j.items.neck.id,
    j.items.shoulder.id,
    j.items.back.id,
    j.items.chest.id,
    j.items.shirt.id,
    j.items.tabard.id,
    j.items.wrist.id,
    j.items.hands.id,
    j.items.waist.id,
    j.items.legs.id,
    j.items.feet.id,
    j.items.finger1.id,
    j.items.finger2.id,
    j.items.trinket1.id,
    j.items.trinket2.id,
    j.items.mainHand.id,
    j.items.offHand.id);
  db_save(statement); 
  console.log("gear_check");
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
function dbCreate(){
  console.log("dbCreate");
  var fs = require("fs");
  var db_file = "pandaren.db";
  var sqlite3 = require("sqlite3").verbose();
  var db = new sqlite3.database(db_file);
  var seed = fs.readFile('createDB.sql', 'utf8', function (err,data) {
    if (err) {
      return console.log(err);
    }
    console.log(data);
    db.run(data);
    db.close();
  });
  console.log("dbCreate");
}

app.get('/scrape', function(req, res){
  api_call("ysera", "mysunanstars", "items", query_gear_check);

  
  //dbCreate();
  //console.log('main');
  //api_call("ysera", "mysunanstars", "items", gear_check);
  //var character = quest_update('ysera', 'Mysunanstars');
  //download_character_render("firetree","Corradhledo"); 
  res.send('Check your console!')
})

app.listen('8081')
console.log('Magic happens on port 8081');
exports = module.exports = app; 	
