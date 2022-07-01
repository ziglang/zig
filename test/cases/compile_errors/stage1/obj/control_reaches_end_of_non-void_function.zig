fn a() i32 {}
export fn entry() void { _ = a(); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:12: error: expected type 'i32', found 'void'
