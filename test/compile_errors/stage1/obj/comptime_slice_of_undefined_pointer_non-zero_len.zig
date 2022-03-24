export fn entry() void {
    const slice = @as([*]i32, undefined)[0..1];
    _ = slice;
}

// comptime slice of undefined pointer non-zero len
//
// tmp.zig:2:41: error: non-zero length slice of undefined pointer
