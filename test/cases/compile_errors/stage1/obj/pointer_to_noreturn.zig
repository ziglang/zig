fn a() *noreturn {}
export fn entry() void { _ = a(); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:9: error: pointer to noreturn not allowed
