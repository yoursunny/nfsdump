// operations.js: reconstruct operations from a particular client
// argv: fullpath-file clientIP-hex
// stdout: CSV fh,name,parent

var util = require('util');
var stream = require('stream');
var csv = require('csv');
var nfsdump_func = require('./nfsdump.func.js')
var fullpath_func = require('./fullpath.func.js')

var forEachKV = nfsdump_func.forEachKV;
var OFFSET = nfsdump_func.OFFSET;

//fullpath_func.readAsMap(process.stdin, {}, function(map){
//  console.log(map);
//});
