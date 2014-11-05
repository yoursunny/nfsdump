// fhparent.js: parse nfsdump log for file handle and its parent
// stdin: nfsdump log
// stdout: CSV fh,name,parent

var util = require('util');
var stream = require('stream');
var csv = require('csv');
var nfsdump_func = require('./nfsdump.func.js')
var fhparent_func = require('./fhparent.func.js')

var forEachKV = nfsdump_func.forEachKV;
var OFFSET = nfsdump_func.OFFSET;

function ExtractFhParent() {
  this.calls = {};
}

ExtractFhParent.prototype.processCall = function(row) {
  var client = row[OFFSET.SRC], xid = row[OFFSET.XID], op = row[OFFSET.OP], params = row.slice(OFFSET.PARAM_START);
  var call = { op:op }, logCall = true;

  switch (op) {
  case 'mnt':
    call.dirpath = params[0];
    break;
  case 'lookup':
    call.fh = params[1];
    call.name = params[3];
    break;
  case 'readdirp':
    call.fh = params[1];
    break;
  case 'create':
  case 'mkdir':
  case 'symlink':
  case 'mknod':
    call.fh = params[1];
    call.name = params[3];
    break;
  case 'link':
    call.fh = params[1];
    call.fh2 = params[3];
    call.name = params[5];
    break;
  //case 'rename':
  //rename is ignored, because fh for the name doesn't appear
  default:
    logCall = false;
    break;
  }

  if (logCall) {
    this.calls[client + '.' + xid] = call;
  }

  return null;
};

ExtractFhParent.prototype.processReply = function(row) {
  var client = row[OFFSET.DST], xid = row[OFFSET.XID], op = row[OFFSET.OP], status = row[OFFSET.STATUS], params = row.slice(OFFSET.RET_START);
  var call = this.calls[client + '.' + xid];
  if (!call) {
    return [];
  }
  delete this.calls[client + '.' + xid];
  var records = [];

  switch (op) {
  case 'mnt':
    if (status == 'OK') {
      records.push({ fh:params[1], name:call.dirpath, parent:'MOUNTPOINT' });
    }
    break;
  case 'lookup':
    if (status == 'OK') {
      records.push({ fh:params[1], name:call.name, parent:call.fh });
    }
    break;
  case 'readdirp':
    if (status == 'OK') {
      var currentIndex = 0, currentName = '';
      forEachKV(params, function(key, value) {
        if (key == 'name-' + currentIndex) {
          currentName = value;
        }
        else if (key == 'fh-' + currentIndex) {
          if (currentName != '.' && currentName != '..') {
            records.push({ fh:value, name:currentName, parent:call.fh });
          }
          ++currentIndex;
        }
      });
    }
    break;
  case 'create':
  case 'mkdir':
  case 'symlink':
  case 'mknod':
    if (status == 'OK') {
      records.push({ fh:params[1], name:call.name, parent:call.fh });
    }
    break;
  case 'link':
    if (status == 'OK') {
      records.push({ fh:call.fh, name:call.name, parent:call.fh2 });
    }
    break;
  }
  return records;
};

var extractFhParent = new ExtractFhParent();

var csvParser = nfsdump_func.makeCsvParser();
var csvTransform = csv.transform(function(row, cb){
  if (row.length < OFFSET.PARAM_START) {
    cb(null);
    return;
  }

  switch (row[OFFSET.DIRECTION]) {
  case 'C3':
    extractFhParent.processCall(row);
    cb(null);
    break;
  case 'R3':
    var records = extractFhParent.processReply(row);
    records.unshift(null);
    cb.apply(undefined, records);
    break;
  }
}, { parallel:1 });
var csvStringifier = fhparent_func.makeCsvStringifier();
process.stdin.pipe(csvParser).pipe(csvTransform).pipe(csvStringifier).pipe(process.stdout);
