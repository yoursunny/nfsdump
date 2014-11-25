var csv = require('csv');

var columns = ['t', 'op', 'name', 'version', 'start', 'count'];
exports.columns = columns;

function makeCsvParser() {
  return csv.parse({ delimiter:',', escape:'\\', columns:columns });
}
exports.makeCsvParser = makeCsvParser;

function makeCsvStringifier() {
  return csv.stringify({ columns:columns });
}
exports.makeCsvStringifier = makeCsvStringifier;
