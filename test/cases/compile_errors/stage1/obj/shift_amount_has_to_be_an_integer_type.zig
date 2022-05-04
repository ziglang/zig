export fn entry() void {
    const x = 1 << &@as(u8, 10);
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:21: error: shift amount has to be an integer type, but found '*const u8'
