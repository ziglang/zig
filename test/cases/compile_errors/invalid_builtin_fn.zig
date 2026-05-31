fn f() @bogus(foo) {}
export fn entry() void {
    _ = f();
}

// error
//
// :1:8: error: invalid builtin function: '@bogus'
