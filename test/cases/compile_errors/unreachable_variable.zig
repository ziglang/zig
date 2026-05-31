export fn f() void {
    const a: noreturn = {};
    _ = a;
}

// error
//
// :2:25: error: cannot cast to noreturn
