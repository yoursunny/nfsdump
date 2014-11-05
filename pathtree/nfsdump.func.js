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
