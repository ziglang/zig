export fn entry() void {
    const x = &@as(u8, 1) << 10;
    _ = x;
}

// bit shifting only works on integer types
//
// tmp.zig:2:16: error: bit shifting operation expected integer type, found '*const u8'
