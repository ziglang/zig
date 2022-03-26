export fn entry() void {
    const x = 1 << &@as(u8, 10);
    _ = x;
}

// shift amount has to be an integer type
//
// tmp.zig:2:21: error: shift amount has to be an integer type, but found '*const u8'
