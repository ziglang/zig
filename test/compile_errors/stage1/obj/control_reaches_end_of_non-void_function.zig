fn a() i32 {}
export fn entry() void { _ = a(); }

// control reaches end of non-void function
//
// tmp.zig:1:12: error: expected type 'i32', found 'void'
