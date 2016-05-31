var csv = require('csv');

// [key1, value1, key2, value2, ...]
function forEachKV(arr, f) {
  for (var i = 0; i < arr.length - 1; i += 2) {
    if (f(arr[i], arr[i + 1]) === false) {
      return;
    }
  }
};
exports.forEachKV = forEachKV;

function getKV(arr, key) {
  var value = undefined;
  forEachKV(arr, function(k, v){
    if (k == key) {
      value = v;
      return false;
    }
  });
  return value;
};
exports.getKV = getKV;

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
exports.OFFSET = OFFSET;

function makeCsvParser() {
  return csv.parse({ delimiter:' ', escape:'\\', ltrim:true, relax_column_count:true });
}
exports.makeCsvParser = makeCsvParser;


function Parser(options) {
  options = options || {};

  this.calls = {};

  // every cleanupInterval, unreplied calls older than callLifetime are deleted
  this.callLifetime = options.callLifetime || 15;
  this.cleanupInterval = options.cleanupInterval || 60;
  this.nextCleanup = 0;
  this.finished = false;
}
exports.Parser = Parser;

Parser.prototype.parseFile = function(stream, cb) {
  var that = this;
  this.finishCb = cb;

  this.csvParser = makeCsvParser();
  this.csvParser.on('readable', this.readCsv.bind(this));
  this.csvParser.on('finish', function(){
    that.finished = true;
    that.readCsv();
  });

  stream.pipe(this.csvParser);
};

Parser.prototype.readCsv = function() {
  var row;
  while (!this.paused && (row = this.csvParser.read())) {
    this.processRow(row);
  }

  if (this.finished && !this.paused) {
    this.finishCb();
    this.finished = false;
  }
};

Parser.prototype.pause = function() {
  this.paused = true;
};

Parser.prototype.resume = function() {
  this.paused = false;
  this.readCsv();
};

Parser.prototype.processRow = function(row) {
  if (row.length < OFFSET.PARAM_START) {
    return;
  }

  switch (row[OFFSET.DIRECTION]) {
  case 'C3':
    if (this.filterCall(row)) {
      this.processCall(row);
    }
    break;
  case 'R3':
    this.processReply(row);
    break;
  }
};

// override to process a subset of rows
Parser.prototype.filterCall = function(row) {
  return true;
};

Parser.prototype.processCall = function(row) {
  var client = row[OFFSET.SRC], xid = row[OFFSET.XID], op = row[OFFSET.OP];
  if (op == 'unknown') {
    return;
  }

  row.timestamp = parseInt(row[OFFSET.TIME]);
  this.cleanup(row.timestamp);
  this.calls[client + '.' + xid] = row;
};

Parser.prototype.processReply = function(row) {
  var client = row[OFFSET.DST], xid = row[OFFSET.XID], op = row[OFFSET.OP];
  var call = this.calls[client + '.' + xid];
  if (!call) {
    return;
  }
  delete this.calls[client + '.' + xid];

  this.process(op, call, row);
};

// override to process a call-reply pair
Parser.prototype.process = function(op, call, reply) {
};

Parser.prototype.cleanup = function(timestamp) {
  if (timestamp < this.nextCleanup) {
    return;
  }
  this.nextCleanup = timestamp;

  var that = this;
  var expiry = timestamp - this.callLifetime;
  Object.keys(this.calls).forEach(function(key){
    if (that.calls[key].timestamp < expiry) {
      delete that.calls[key];
    }
  });
};
