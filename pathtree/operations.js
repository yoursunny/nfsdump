// operations.js: reconstruct operations from a particular client
// argv: clientIP-hex
// stdin: nfsdump log
// stdout: CSV t,op,name,version,start,count
//         unsorted

var util = require('util');
var nfsdump_func = require('./nfsdump.func.js')
var fullpath_func = require('./fullpath.func.js')
var operations_func = require('./operations.func.js')

var forEachKV = nfsdump_func.forEachKV;
var getKV = nfsdump_func.getKV;
var OFFSET = nfsdump_func.OFFSET;

function ExtractOperations(fullpathQuerier, csvStringifier, options) {
  nfsdump_func.Parser.call(this, options);
  this.fullpathQuerier = fullpathQuerier;
  this.csvStringifier = csvStringifier;

  options = options || {};
  this.segmentSize = options.segmentSize || 4096;
  this.client = options.client || true;
}
util.inherits(ExtractOperations, nfsdump_func.Parser);

ExtractOperations.prototype.queryFullPath = function(fh, cb) {
  this.fullpathQuerier.lookup(fh, cb);
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
      if (fields.name_fh) {
        this.queryFullPath(fields.name_fh, function(p){
          if (!p) {
            return;
          }
          fields.name = p;
          if (fields.name_append) {
            fields.name += '/' + fields.name_append;
          }
          record(fields);
        });
      }
      return;
    }
    fields.t = t;
    fields.op = op;
    this.record(fields);
  }.bind(this);

  switch (op) {
  case 'getattr':
    record({ name_fh:callp[1] });
    break;
  case 'lookup':
    record({ name_fh:callp[1], name_append:callp[3] });
    break;
  case 'access':
    record({ name_fh:callp[1] });
    break;
  case 'readlink':
    record({ name_fh:callp[1] });
    break;
  case 'read':
    record({ name_fh:callp[1], version:getKV(replyp, 'mtime'),
             start:parseInt('0x' + callp[3]), count:parseInt('0x' + getKV(replyp, 'count')) });
    break;
  case 'write':
    record({ name_fh:callp[1], version:getKV(replyp, 'mtime'),
             start:parseInt('0x' + callp[3]), count:parseInt('0x' + getKV(replyp, 'count')) });
    break;
  //case 'readdir':
  //  break;
  case 'readdirp':
    var fileEntryCount = 0;
    forEachKV(replyp, function(k, v){
      if (k.substr(0, 5) == 'name-') {
        ++fileEntryCount;
      }
    });
    record({ name_fh:callp[1], version:getKV(replyp, 'mtime'),
             start:callp[3], count:fileEntryCount });
    break;
  case 'setattr':
    record({ name_fh:callp[1] });
    break;
  case 'create':
    record({ name_fh:replyp[1] });
    break;
  case 'mkdir':
    record({ name_fh:replyp[1] });
    break;
  case 'symlink':
    record({ name_fh:replyp[1] });
    break;
  case 'remove':
    record({ name_fh:callp[1], name_append:callp[3] });
    break;
  case 'rmdir':
    record({ name_fh:callp[1], name_append:callp[3] });
    break;
  case 'rename':
    record({ name_fh:callp[1], name_append:callp[3] });
    break;
  }
};

var fullpathQuerier = new fullpath_func.svcQuerier({ path:'fullpath-svc.sock' }, {}, run);

var csvStringifier = operations_func.makeCsvStringifier();
csvStringifier.pipe(process.stdout);

var extractOperations;
function run() {
  extractOperations = new ExtractOperations(fullpathQuerier, csvStringifier, { client:process.argv[3] });
  extractOperations.parseFile(process.stdin, function(){ fullpathQuerier.close(); });
}
