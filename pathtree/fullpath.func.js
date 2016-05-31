var csv = require('csv');
var net = require('net');

var columns = ['fh', 'top', 'path'];
exports.columns = columns;

function makeCsvParser(needEndHack) {
  var parser = csv.parse({ delimiter:',', escape:'\\', columns:columns, relax_column_count:true, skip_empty_lines:needEndHack || null });
  if (needEndHack) {
    // https://github.com/wdavidw/node-csv-parse/issues/96 workaround
    parser.__write2 = parser.__write;
    parser.__write = function(chars, end, callback) {
      this.__write2(chars, false, callback);
      if (end || (this.buf.length > 0 && this.buf.charAt(this.buf.length - 1) == '\n')) {
        this.__write2('\n\n\n', end, function(){});
      }
    };
  }
  return parser;
}
exports.makeCsvParser = makeCsvParser;

function makeCsvStringifier() {
  return csv.stringify({ columns:columns });
}
exports.makeCsvStringifier = makeCsvStringifier;

function defaultUnresolvedHandler(row) {
  return '/UNRESOLVED-' + row.top + '/' + row.path;
}
function makeUnresolvedHandler(option_unresolvedHandler) {
  if (option_unresolvedHandler === false) {
    return function(){ return false; };
  }
  else if (option_unresolvedHandler) {
    return option_unresolvedHandler;
  }
  return defaultUnresolvedHandler;
}

// options.unresolvedHandler = function(row) {
//   return path; // use a fake path
//   return false; // skip this record
// }
function readAsMap(stream, options, cb) {
  var unresolvedHandler = makeUnresolvedHandler(options.unresolvedHandler);
  var map = {}; // fh => path
  var processRow = function(row){
    if (row.top) {
      var path = unresolvedHandler(row);
      if (path) {
        map[row.fh] = path;
      }
    }
    else {
      map[row.fh] = row.path;
    }
  };

  var csvParser = makeCsvParser();
  csvParser.on('readable', function(){
    var row;
    while (row = csvParser.read()) {
      processRow(row);
    }
  });
  csvParser.on('finish', function(){
    cb(map);
  });
  stream.pipe(csvParser);
}
exports.readAsMap = readAsMap;

// query fullpath from a map
function mapQuerier(stream, options, readyCb) {
  var that = this;
  readAsMap(stream, options, function(map){
    that.map = map;
    readyCb();
  });
}
mapQuerier.prototype.lookup = function(fh, cb) {
  cb(this.map[fh]);
};
mapQuerier.prototype.close = function() {
};
exports.mapQuerier = mapQuerier;

// query fullpath from a service
function svcQuerier(socketOptions, options, readyCb) {
  var that = this;

  this.unresolvedHandler = makeUnresolvedHandler(options.unresolvedHandler);
  this.buffer = '';
  this.pending = {}; // fh=>[cb,...]

  this.csvParser = makeCsvParser(true);
  this.csvParser.on('readable', function(){
    var row;
    while (row = that.csvParser.read()) {
      that.processResult(row);
    }
  });

  this.sock = net.connect(socketOptions);
  this.sock.setEncoding('utf8');
  this.sock.on('connect', function(){
    that.sock.pipe(that.csvParser);
    readyCb();
  });
}
svcQuerier.prototype.lookup = function(fh, cb) {
  var callbacks = this.pending[fh];
  if (!callbacks) {
    callbacks = this.pending[fh] = [];
  }
  callbacks.push(cb);

  this.sock.write(fh + '\n');
};
svcQuerier.prototype.processResult = function(row) {
  var callbacks = this.pending[row.fh];
  if (!callbacks) {
    return;
  }
  delete this.pending[row.fh];

  var path = false;
  if (row.path) {
    if (row.top == '') {
      path = row.path;
    }
    else {
      path = this.unresolvedHandler(row);
    }
  }
  callbacks.forEach(function(cb){
    cb(path);
  });
};
svcQuerier.prototype.close = function() {
  this.sock.end();
};
exports.svcQuerier = svcQuerier;
