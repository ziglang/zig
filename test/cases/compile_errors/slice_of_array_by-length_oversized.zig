export fn entry1() void {
    var buf: [5]u8 = undefined;
    var a: u32 = 6;
    _ = &a;
    _ = buf[a..][0..10];
}

export fn entry2() void {
    var buf: [5]u8 = undefined;
    const a: u32 = 6;
    _ = buf[a..][0..10];
}

// error
// backend=stage2
// target=native
//
// :5:21: error: length 10 out of bounds for array of length 5
// :11:21: error: length 10 out of bounds for array of length 5
