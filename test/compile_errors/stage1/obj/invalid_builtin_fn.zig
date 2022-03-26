fn f() @bogus(foo) {
}
export fn entry() void { _ = f(); }

// invalid builtin fn
//
// tmp.zig:1:8: error: invalid builtin function: '@bogus'
