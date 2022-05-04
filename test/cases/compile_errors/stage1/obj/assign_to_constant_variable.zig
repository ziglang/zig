export fn f() void {
    const a = 3;
    a = 4;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:9: error: cannot assign to constant
