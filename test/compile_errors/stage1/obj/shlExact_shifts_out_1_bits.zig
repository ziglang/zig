comptime {
    const x = @shlExact(@as(u8, 0b01010101), 2);
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:15: error: operation caused overflow
