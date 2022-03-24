comptime {
    const x = @shlExact(@as(u8, 0b01010101), 2);
    _ = x;
}

// @shlExact shifts out 1 bits
//
// tmp.zig:2:15: error: operation caused overflow
