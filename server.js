var express = require('express');
var app     = express();
function curl(url, file){
  var util = require('util');
  var exec = require('child_process').exec;
  var command = util.format('curl %s > %s', url, file);
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

app.get('/scrape', function(req, res){
  
  //download_character_render("firetree","Corradhledo"); 
  res.send('Check your console!')
})

app.listen('8081')
console.log('Magic happens on port 8081');
exports = module.exports = app; 	
