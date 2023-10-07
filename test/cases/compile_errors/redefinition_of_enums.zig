const A = enum { x };
const A = enum { x };

// error
// backend=stage2
// target=native
//
// :2:1: error: redeclaration of 'A'
// :1:1: note: other declaration here
