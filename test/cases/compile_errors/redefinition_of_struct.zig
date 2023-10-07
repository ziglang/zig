const A = struct { x: i32 };
const A = struct { y: i32 };

// error
// backend=stage2
// target=native
//
// :2:1: error: redeclaration of 'A'
// :1:1: note: other declaration here
