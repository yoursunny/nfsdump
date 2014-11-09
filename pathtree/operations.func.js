var csv = require('csv');

var columns = ['t', 'op', 'name', 'version', 'start', 'count'];
exports.columns = columns;

function makeCsvStringifier() {
  return csv.stringify({ columns:columns });
}
exports.makeCsvStringifier = makeCsvStringifier;
