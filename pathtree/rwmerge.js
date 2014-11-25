// rwmerge.js: reconstruct operations from a particular client
// stdin: CSV t,op,name,version,start,count
//        sorted by name and op either order, t descending
// stdout: CSV t,op,name,version,start,count
//         unsorted

var util = require('util');
var operations_func = require('./operations.func.js')


function RwMerge(csvStringifier, options) {
  this.csvStringifier = csvStringifier;

  options = options || {};
  this.maxSlack = options.maxSlack || 4096;
  this.segmentSize = options.segmentSize || 4096;
  this.dirPerSegment = options.dirPerSegment || 32; // readdir: number of direntries per segment

  this.reset({ t:Infinity, op:'', name:'' });
}

RwMerge.prototype.computeSegment = function(offset){
  return Math.floor(offset / this.segmentSize);
};

RwMerge.prototype.reset = function(row){
  // attributes of current processing group of operations
  // if new row has different op or name, or new timestamp is too early,
  // the current group of operations ends and a new group is opened
  this.t = Infinity;
  this.op = row.op;
  this.name = row.name;
  this.segments = {}; // seg=>timestamp
  this.dirCount = 0;
  this.version = Infinity;
};

RwMerge.prototype.processRow = function(row){
  if (row.op != this.op || row.name != this.name || row.t < this.t - this.maxSlack) {
    this.recordOp();
    this.reset(row);
  }

  this.t = row.t;

  switch (row.op) {
  case 'read':
  case 'write':
    var begin = this.computeSegment(parseInt(row.start)),
        end = this.computeSegment(parseInt(row.start) + parseInt(row.count) - 1);
    for (var seg = begin; seg <= end; ++seg) {
      this.segments[seg] = row.t;
    }
    this.version = Math.min(this.version, row.version);
    break;
  case 'readdirp':
    this.dirCount += parseInt(row.count);
    this.version = Math.min(this.version, row.version);
    break;
  }
};

RwMerge.prototype.end = function(row){
  this.recordOp();
};

RwMerge.prototype.recordOp = function(){
  if (this.op == '') {
    return; // initial state
  }

  switch (this.op) {
  case 'read':
  case 'write':
    this.recordRW();
    break;
  case 'readdirp':
    this.recordReadDir();
    break;
  default:
    this.csvStringifier.write({ t:this.t, op:this.op, name:this.name });
    break;
  }
};

RwMerge.prototype.recordRW = function(){
  var that = this;

  var segments = Object.keys(this.segments);
  segments.sort(function(a, b){ return a - b; });

  // record one read/write command per consequtive extent of segments
  var begin = false, end = -Infinity;
  function recordExtent() {
    if (begin === false) { // initial state
      return;
    }
    that.csvStringifier.write({ t:that.segments[begin], op:that.op, name:that.name,
                                version:that.version, start:begin, count:end - begin + 1 });
  }

  segments.forEach(function(seg){
    seg = parseInt(seg);
    if (seg == end + 1) { // consequtive
      end = seg;
      return;
    }
    recordExtent(); // record previous extent
    begin = end = seg; // start new extent
  });
  recordExtent();
};

RwMerge.prototype.recordReadDir = function(){
  var count = Math.ceil(this.dirCount / this.dirPerSegment);
  this.csvStringifier.write({ t:this.t, op:this.op, name:this.name,
                              version:this.version, start:0, count:count });
};

var csvStringifier = operations_func.makeCsvStringifier();
csvStringifier.pipe(process.stdout);

var rwMerge = new RwMerge(csvStringifier);

var csvParser = operations_func.makeCsvParser();
csvParser.on('readable', function(){
  var row;
  while (row = csvParser.read()) {
    rwMerge.processRow(row);
  }
});
csvParser.on('finish', rwMerge.end.bind(rwMerge));
process.stdin.pipe(csvParser);
