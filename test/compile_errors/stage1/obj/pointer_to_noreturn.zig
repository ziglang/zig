fn a() *noreturn {}
export fn entry() void { _ = a(); }

// pointer to noreturn
//
// tmp.zig:1:9: error: pointer to noreturn not allowed
