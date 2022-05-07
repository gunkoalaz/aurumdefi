const BigNumber = require('bignumber.js');

let timestamp = new BigNumber(Date.now()/1000);
let nextday = timestamp.plus(60*60*24);
console.log("Current timestamp =   " + timestamp.toFixed(0));
console.log("Next 24hr timestamp = " + nextday.toFixed(0));