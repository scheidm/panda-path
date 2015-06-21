#! /usr/bin/env node
var http = require('http');
var util = require('util');
var curl = require('curlrequest');
var request = require('request');
var cheerio = require('cheerio');
var server = "ysera";
var character = "mysunanstars";
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
    var util = require('util');
    var filename=util.format("%s-%s.jpg",server,character);
    var exec = require('child_process').exec;
    var command = util.format('curl %s > %s', image, filename);
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
    console.log(filename);
  }else{
    console.log("server unreachable");
  }
})
