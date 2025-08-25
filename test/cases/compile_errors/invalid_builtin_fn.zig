fn f() @bogus(foo) {}
export fn entry() void {
    _ = f();
}

// error
// backend=stage2
// target=native
//
// :1:8: error: invalid builtin function: '@bogus'
