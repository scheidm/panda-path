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
function quest_update(server, character, res){
  var config = require('./config')
  var util = require('util');
  var request = require('request');
	var url = util.format('http://us.battle.net/api/wow/character/%s/%s?fields=quests&locale=en_US&apikey=%s',server,character,config.api_key);
	request(url, function(error, response, json ){
		if(!error){
      var fs = require('fs');
      var filename=util.format("%s-%s-quest.json",server,character);
      fs.writeFile(filename,json, function(err) {
        if(err) {
          return console.log(err);
        }
        console.log("The file was saved!");
      }); 
    }
  });
}

app.get('/scrape', function(req, res){
  var character = quest_update('ysera', 'Mysunanstars');

  
  //download_character_render("firetree","Corradhledo"); 
  res.send('Check your console!')
})

app.listen('8081')
console.log('Magic happens on port 8081');
exports = module.exports = app; 	
