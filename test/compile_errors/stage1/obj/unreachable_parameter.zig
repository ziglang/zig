fn f(a: noreturn) void { _ = a; }
export fn entry() void { f(); }

// unreachable parameter
//
// tmp.zig:1:9: error: parameter of type 'noreturn' not allowed
