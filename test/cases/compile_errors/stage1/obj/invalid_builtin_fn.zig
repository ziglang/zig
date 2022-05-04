fn f() @bogus(foo) {
}
export fn entry() void { _ = f(); }

// error
// backend=stage1
// target=native
//
// tmp.zig:1:8: error: invalid builtin function: '@bogus'
