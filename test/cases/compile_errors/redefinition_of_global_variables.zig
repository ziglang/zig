var a: i32 = 1;
var a: i32 = 2;

// error
// backend=stage2
// target=native
//
// :1:5: error: duplicate struct member name 'a'
// :2:5: note: duplicate name here
// :1:1: note: struct declared here
