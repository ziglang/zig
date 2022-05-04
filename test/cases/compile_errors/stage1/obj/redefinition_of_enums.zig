const A = enum {x};
const A = enum {x};

// error
// backend=stage1
// target=native
//
// tmp.zig:2:1: error: redeclaration of 'A'
// tmp.zig:1:1: note: other declaration here
