export fn entry() void {
    const x = &@as(u8, 1) << 10;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :2:15: error: bit shifting operation expected integer type, found '*const u8'
