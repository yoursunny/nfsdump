// fullpath.js: reconstruct full path for each filehandle from fhparent mapping
// stdin: CSV fh,name,parent
// stdout: CSV fh,top-level unresolved fh,path

var util = require('util');
var fhparent_func = require('./fhparent.func.js')
var fullpath_func = require('./fullpath.func.js')

var PROGRESS = 100000; // interval of progress report, 0 to disable
var progressHeading = 'PROGRESS';
var progressCount = 0;
function incrementProgress() {
  if (PROGRESS > 0 && (++progressCount) % PROGRESS == 0) {
    console.warn(progressHeading, progressCount, process.memoryUsage().rss);
  }
}

var relations = {}; // fh=>{name:name,[parent:parent_fh],[mountpoint:true]}

function processRow(row) {
  var fh = row.fh, parent = row.parent;
  var relation = { name:row.name };
  if (parent == 'MOUNTPOINT') {
    relation.mountpoint = true;
  }
  else {
    relation.parent = parent;
  }
  relations[fh] = relation;
}

var csvParser = fhparent_func.makeCsvParser();
csvParser.on('readable', function(){
  var row;
  while (row = csvParser.read()) {
    processRow(row);
    incrementProgress();
  }
});
csvParser.on('finish', function(){
  writeResults();
});
if (PROGRESS > 0) {
  progressHeading = 'parse';
  progressCount = 0;
}
process.stdin.pipe(csvParser);


var csvStringifier = fullpath_func.makeCsvStringifier();
csvStringifier.pipe(process.stdout);

function constructPath(fh, tail) {
  var relation = relations[fh];
  if (!relation) { // unresolved
    return { 'top':fh, 'path':tail };
  }

  tail = tail ? '/' + tail : '';

  if (relation.mountpoint) {
    return { 'top':'', 'path':relation.name + tail };
  }

  return constructPath(relation.parent, relation.name + tail);
}

function writeResults() {
  if (PROGRESS > 0) {
    progressHeading = 'output';
    progressCount = 0;
  }
  Object.keys(relations).forEach(function(fh){
    var p = constructPath(fh);
    p.fh = fh;
    csvStringifier.write(p);
    incrementProgress()
  });
}
