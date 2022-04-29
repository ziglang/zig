comptime {
    const a = 0x1.0p18495;
    _ = a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:15: error: float literal out of range of any type
