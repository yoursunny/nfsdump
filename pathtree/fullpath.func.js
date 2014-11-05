var csv = require('csv');

var columns = ['fh', 'top', 'path'];
exports.columns = columns;

function makeCsvParser() {
  return csv.parse({ delimiter:',', escape:'\\', columns:columns });
}
exports.makeCsvParser = makeCsvParser;

function makeCsvStringifier() {
  return csv.stringify({ columns:columns });
}
exports.makeCsvStringifier = makeCsvStringifier;

function defaultUnresolvedHandler(row) {
  return '/UNRESOLVED-' + row.top + '/' + row.path;
}

// options.unresolvedHandler = function(row) {
//   return path; // use a fake path
//   return false; // skip this record
// }
function readAsMap(stream, options, cb) {
  var unresolvedHandler = defaultUnresolvedHandler;
  if (options.unresolvedHandler === false) {
    unresolvedHandler = function(){ return false; };
  }
  else if (options.unresolvedHandler) {
    unresolvedHandler = options.unresolvedHandler;
  }

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
