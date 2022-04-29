fn a() bogus {}
export fn entry() void { _ = a(); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:8: error: use of undeclared identifier 'bogus'
