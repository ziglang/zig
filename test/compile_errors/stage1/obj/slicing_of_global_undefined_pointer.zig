var buf: *[1]u8 = undefined;
export fn entry() void {
    _ = buf[0..1];
}

// slicing of global undefined pointer
//
// tmp.zig:3:12: error: non-zero length slice of undefined pointer
