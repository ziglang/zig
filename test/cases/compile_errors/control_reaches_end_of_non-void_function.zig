fn a() i32 {}
export fn entry() void { _ = a(); }

// error
// backend=stage2
// target=native
//
// :1:13: error: expected type 'i32', found 'void'
// :1:8: note: function return type declared here
