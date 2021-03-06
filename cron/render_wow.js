#! /usr/bin/env node
var http = require('http');
var util = require('util');
var curl = require('curlrequest');
var request = require('request');
var cheerio = require('cheerio');
var server = process.argv[2];
var character = process.argv[3];
var level = process.argv[4];
var dir = process.argv[5];
var url = util.format('http://us.battle.net/wow/en/character/%s/%s/simple', server, character);
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
    var d = new Date();
    var dstr=d.toISOString().substr(0,10);
    var filename=util.format("%s%s-%s-lvl%s@%s.jpg", dir, server, character, level, dstr);
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
