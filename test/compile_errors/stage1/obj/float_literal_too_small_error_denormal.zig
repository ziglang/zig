comptime {
    const a = 0x1.0p-19000;
    _ = a;
}

// float literal too small error (denormal)
//
// tmp.zig:2:15: error: float literal out of range of any type
