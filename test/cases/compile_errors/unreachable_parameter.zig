fn f(a: noreturn) void {
    _ = a;
}
export fn entry() void {
    f();
}

// error
// backend=stage2
// target=native
//
// :1:6: error: parameter of type 'noreturn' not allowed
