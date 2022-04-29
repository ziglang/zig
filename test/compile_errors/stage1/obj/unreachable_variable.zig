export fn f() void {
    const a: noreturn = {};
    _ = a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:25: error: expected type 'noreturn', found 'void'
