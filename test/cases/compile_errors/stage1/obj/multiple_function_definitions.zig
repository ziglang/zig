fn a() void {}
fn a() void {}
export fn entry() void { a(); }

// error
// backend=stage1
// target=native
//
// tmp.zig:2:1: error: redeclaration of 'a'
// tmp.zig:1:1: note: other declaration here
