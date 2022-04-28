export fn entry() void {
    const x = &@as(u8, 1) << 10;
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:16: error: bit shifting operation expected integer type, found '*const u8'
