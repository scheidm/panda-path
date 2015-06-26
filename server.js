var express = require('express');
var app     = express();
app.set('view engine', 'jade');
app.set('views', './views')
app.use(express.static('compiled'));
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
function endpoint_sql_execute(queries){
  console.log("db_save");
  var fs = require("fs");
  var db_file = "pandaren.db";
  var sqlite3 = require("sqlite3").verbose();
  var db = new sqlite3.Database(db_file);
  db.serialize(function(){
    for( var x in queries){
      statement = queries[x];
      console.log(statement);
      db.run(statement);
    }
  });
  db.close();
  console.log("db_save");
}
app.get('/map', function (req, res) {
  var fs = require("fs");
  var db_file = "pandaren.db";
  var sqlite3 = require("sqlite3").verbose();
  var db = new sqlite3.Database(db_file);

  res.render('index', { title: 'Hey', message: 'Hello there!'});
});

//app.use( express.static('compiled') );
app.get('/maps', function(req, res){
  var haml = require('hamljs');
  var fs = require('fs');

  var hamlView = fs.readFileSync('source/haml/layouts/default.html.haml', 'utf8');

  var data = {
    title: "Hello Node",
    contents: "<h1>Hello World</h1>"
  };
  res.end( haml.render(hamlView, {locals: data}) );
})
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
