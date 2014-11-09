// operations.js: reconstruct operations from a particular client
// argv: fullpath-file clientIP-hex
// stdin: nfsdump log
// stdout: CSV fh,name,parent

var util = require('util');
var fs = require('fs');
var csv = require('csv');
var nfsdump_func = require('./nfsdump.func.js')
var fullpath_func = require('./fullpath.func.js')
var operations_func = require('./operations.func.js')

var getKV = nfsdump_func.getKV;
var OFFSET = nfsdump_func.OFFSET;

function ExtractOperations(fullpathMap, csvStringifier, options) {
  nfsdump_func.Parser.call(this, options);
  this.fullpathMap = fullpathMap;
  this.csvStringifier = csvStringifier;

  options = options || {};
  this.segmentSize = options.segmentSize || 4096;
  this.client = options.client || true;
}
util.inherits(ExtractOperations, nfsdump_func.Parser);

ExtractOperations.prototype.getFullPath = function(fh) {
  var p = this.fullpathMap[fh];
  return p || false;
};

ExtractOperations.prototype.filterCall = function(row) {
  return this.client === true || row[OFFSET.SRC].substr(0, 8) == this.client;
};

ExtractOperations.prototype.record = function(outputRow) {
  this.csvStringifier.write(outputRow);
};

ExtractOperations.prototype.process = function(op, call, reply) {
  var t = call[OFFSET.TIME], callp = call.slice(OFFSET.PARAM_START),
      status = reply[OFFSET.STATUS], replyp = reply.slice(OFFSET.RET_START);

  var record = function(fields) {
    if (!fields.name) {
      return;
    }
    fields.t = t;
    fields.op = op;
    this.record(fields);
  }.bind(this);

  // TODO track mtime of every file, to serve as file version
  switch (op) {
  case 'getattr':
    record({ name:this.getFullPath(callp[1]) });
    break;
  case 'lookup':
    record({ name:this.getFullPath(replyp[1]) });
    break;
  case 'access':
    record({ name:this.getFullPath(callp[1]) });
    break;
  case 'readlink':
    record({ name:this.getFullPath(callp[1]) });
    break;
  case 'read':
    // TODO merge consequtive reads
    record({ name:this.getFullPath(callp[1]), version:'TODO',
             start:parseInt('0x' + callp[3]), count:parseInt('0x' + getKV(replyp, 'count')) });
    break;
  case 'write':
    // TODO merge consequtive writes
    record({ name:this.getFullPath(callp[1]), version:'TODO',
             start:parseInt('0x' + callp[3]), count:parseInt('0x' + getKV(replyp, 'count')) });
    break;
  //case 'readdir':
  //  break;
  case 'readdirp':
    // TODO record only if cookie!=0, and count number of response segments
    record({ name:this.getFullPath(callp[1]) });
    break;
  case 'setattr':
    record({ name:this.getFullPath(callp[1]) });
    break;
  case 'create':
    record({ name:this.getFullPath(replyp[1]) });
    break;
  case 'mkdir':
    record({ name:this.getFullPath(replyp[1]) });
    break;
  case 'symlink':
    record({ name:this.getFullPath(replyp[1]) });
    break;
  case 'remove':
    var dirName = this.getFullPath(callp[1]);
    if (dirName !== false) {
      record({ name:dirName + '/' + callp[3] });
    }
    break;
  case 'rmdir':
    var dirName = this.getFullPath(callp[1]);
    if (dirName !== false) {
      record({ name:dirName + '/' + callp[3] });
    }
    break;
  case 'rename':
    var dirName = this.getFullPath(callp[1]);
    if (dirName !== false) {
      record({ name:dirName + '/' + callp[3] });
    }
    break;
  }
};

var fullpathFile = process.argv[2];
var fullpathMap;
fullpath_func.readAsMap(fs.createReadStream(fullpathFile), {}, function(map){
  fullpathMap = map;
  run();
});

var csvStringifier = operations_func.makeCsvStringifier();
csvStringifier.pipe(process.stdout);

var extractOperations;
function run() {
  extractOperations = new ExtractOperations(fullpathMap, csvStringifier, { client:process.argv[3] });
  extractOperations.parseFile(process.stdin, function(){});
}
