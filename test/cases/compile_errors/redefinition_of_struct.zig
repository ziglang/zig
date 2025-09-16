const A = struct { x: i32 };
const A = struct { y: i32 };

// error
//
// :1:7: error: duplicate struct member name 'A'
// :2:7: note: duplicate name here
// :1:1: note: struct declared here
