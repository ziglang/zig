const A = struct { x : i32, };
const A = struct { y : i32, };

// redefinition of struct
//
// tmp.zig:2:1: error: redeclaration of 'A'
// tmp.zig:1:1: note: other declaration here
