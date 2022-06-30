export fn f() void {
    const a = 3;
    a = 4;
}

// error
// backend=stage2
// target=native
//
// :3:9: error: cannot assign to constant
