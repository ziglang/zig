fn f(a: noreturn) void { _ = a; }
export fn entry() void { f(); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:9: error: parameter of type 'noreturn' not allowed
