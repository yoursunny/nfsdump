// fhparent.js: parse nfsdump log for file handle and its parent
// stdin: nfsdump log
// stdout: CSV fh,name,parent

var util = require('util');
var nfsdump_func = require('./nfsdump.func.js')
var fhparent_func = require('./fhparent.func.js')

var forEachKV = nfsdump_func.forEachKV;
var OFFSET = nfsdump_func.OFFSET;

function ExtractFhParent(csvStringifier, options) {
  nfsdump_func.Parser.call(this, options);
  this.csvStringifier = csvStringifier;
}
util.inherits(ExtractFhParent, nfsdump_func.Parser);

ExtractFhParent.prototype.record = function(outputRow) {
  this.csvStringifier.write(outputRow);
};

ExtractFhParent.prototype.process = function(op, call, reply) {
  var status = reply[OFFSET.STATUS], callp = call.slice(OFFSET.PARAM_START), replyp = reply.slice(OFFSET.RET_START);

  switch (op) {
  case 'mnt':
    if (status == 'OK') {
      this.record({ fh:replyp[1], name:callp[0], parent:'MOUNTPOINT' });
    }
    break;
  case 'lookup':
    if (status == 'OK') {
      this.record({ fh:replyp[1], name:callp[3], parent:callp[1] });
    }
    break;
  case 'readdirp':
    if (status == 'OK') {
      var currentIndex = 0, currentName = '';
      forEachKV(replyp, function(key, value) {
        if (key == 'name-' + currentIndex) {
          currentName = value;
        }
        else if (key == 'fh-' + currentIndex) {
          if (currentName != '.' && currentName != '..') {
            this.record({ fh:value, name:currentName, parent:callp[1] });
          }
          ++currentIndex;
        }
      }.bind(this));
    }
    break;
  case 'create':
  case 'mkdir':
  case 'symlink':
  case 'mknod':
    if (status == 'OK') {
      this.record({ fh:replyp[1], name:callp[3], parent:callp[1] });
    }
    break;
  case 'link':
    if (status == 'OK') {
      this.record({ fh:callp[1], name:callp[5], parent:callp[3] });
    }
    break;
  //case 'rename':
  //rename is ignored, because fh for the name doesn't appear
  }
};

var csvStringifier = fhparent_func.makeCsvStringifier();
csvStringifier.pipe(process.stdout);

var extractFhParent = new ExtractFhParent(csvStringifier);
extractFhParent.parseFile(process.stdin, function(){});
