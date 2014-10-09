// fhparent.js: parse nfsdump log for file handle and its parent
// stdin: nfsdump log
// stdout: CSV fh,name,parent

var util = require('util');
var stream = require('stream');
var csv = require('csv');

var OFFSET = {
  TIME:0,
  SRC:1,
  DST:2,
  DIRECTION:4,
  XID:5,
  OP:7,
  PARAM_START:8,
  STATUS:8,
  RET_START:9,
};

function ExtractFhParent() {
  this.calls = {};
}

ExtractFhParent.prototype.processCall = function(row) {
  var xid = row[OFFSET.XID], op = row[OFFSET.OP], params = row.slice(OFFSET.PARAM_START);
  var call = { op:op }, logCall = true;

  switch (op) {
  case 'mnt':
    call.dirpath = params[0];
    break;
  case 'lookup':
    call.fh = params[1];
    call.name = params[3];
    break;
  case 'create':
  case 'mkdir':
    call.fh = params[1];
    call.name = params[3];
    break;
  case 'readdirp':
    call.fh = params[1];
    break;
  default:
    logCall = false;
    break;
  }

  if (logCall) {
    this.calls[xid] = call;
  }

  return null;
};

ExtractFhParent.prototype.processReply = function(row) {
  var xid = row[OFFSET.XID], op = row[OFFSET.OP], status = row[OFFSET.STATUS], params = row.slice(OFFSET.RET_START);
  var call = this.calls[xid];
  if (!call) {
    return [];
  }
  delete this.calls[xid];
  var records = [];

  switch (op) {
  case 'mnt':
    if (status == 'OK') {
      records.push({ fh:params[1], name:call.dirpath, parent:'MOUNTPOINT' });
    }
    break;
  case 'lookup':
    if (status == 'OK') {
      // TODO
    }
    break;
  case 'create':
  case 'mkdir':
    if (status == 'OK') {
      records.push({ fh:params[1], name:call.name, parent:call.fh });
    }
    break;
  case 'readdirp':
    if (status == 'OK') {
      // TODO
    }
    break;
  }
  return records;
};

var extractFhParent = new ExtractFhParent();

var csvParser = csv.parse({ delimiter:' ', escape:'\\', ltrim:true });
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
var csvStringifier = csv.stringify({ columns:['fh','name','parent'] });
process.stdin.pipe(csvParser).pipe(csvTransform).pipe(csvStringifier).pipe(process.stdout);

