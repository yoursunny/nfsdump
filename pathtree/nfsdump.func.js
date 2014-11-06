var csv = require('csv');

// [key1, value1, key2, value2, ...]
exports.forEachKV = function(arr, f) {
  for (var i = 0; i < arr.length - 1; i += 2) {
    if (f(arr[i], arr[i + 1]) === false) {
      return;
    }
  }
};

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
  return csv.parse({ delimiter:' ', escape:'\\', ltrim:true });
}
exports.makeCsvParser = makeCsvParser;


function Parser(options) {
  if (!options) {
    options = {};
  }

  this.calls = {};

  // every cleanupInterval, unreplied calls older than callLifetime are deleted
  this.callLifetime = options.callLifetime || 15;
  this.cleanupInterval = options.cleanupInterval || 60;
  this.nextCleanup = 0;
}
exports.Parser = Parser;

Parser.prototype.parseFile = function(stream, cb) {
  var that = this;
  var csvParser = makeCsvParser();
  csvParser.on('readable', function(){
    var row;
    while (row = csvParser.read()) {
      that.processRow(row);
    }
  });
  csvParser.on('finish', function(){
    cb();
  });
  stream.pipe(csvParser);
};

Parser.prototype.processRow = function(row) {
  if (row.length < OFFSET.PARAM_START) {
    return;
  }

  switch (row[OFFSET.DIRECTION]) {
  case 'C3':
    this.processCall(row);
    break;
  case 'R3':
    this.processReply(row);
    break;
  }
};

// override to process a subset of rows
Parser.prototype.filter = function(row) {
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
