export fn f() void {
    const a: noreturn = {};
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :2:25: error: cannot cast to noreturn
