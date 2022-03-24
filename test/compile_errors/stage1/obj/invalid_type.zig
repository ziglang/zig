fn a() bogus {}
export fn entry() void { _ = a(); }

// invalid type
//
// tmp.zig:1:8: error: use of undeclared identifier 'bogus'
