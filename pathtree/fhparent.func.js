var csv = require('csv');

var columns = ['fh', 'name', 'parent'];
exports.columns = columns;

function makeCsvParser() {
  return csv.parse({ delimiter:',', escape:'\\', ltrim:true, columns:columns });
}
exports.makeCsvParser = makeCsvParser;

function makeCsvStringifier() {
  return csv.stringify({ columns:columns });
}
exports.makeCsvStringifier = makeCsvStringifier;
