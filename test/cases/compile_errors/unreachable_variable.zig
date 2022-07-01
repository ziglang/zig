export fn f() void {
    const a: noreturn = {};
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :2:25: error: expected type 'noreturn', found 'void'
