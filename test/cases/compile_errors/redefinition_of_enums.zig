const A = enum { x };
const A = enum { x };

// error
// backend=stage2
// target=native
//
// :1:7: error: duplicate struct member name 'A'
// :2:7: note: duplicate name here
// :1:1: note: struct declared here
