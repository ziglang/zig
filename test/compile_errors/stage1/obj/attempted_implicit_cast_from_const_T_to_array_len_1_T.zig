export fn entry(byte: u8) void {
    const w: i32 = 1234;
    var x: *const i32 = &w;
    var y: *[1]i32 = x;
    y[0] += 1;
    _ = byte;
}

// attempted implicit cast from *const T to *[1]T
//
// tmp.zig:4:22: error: expected type '*[1]i32', found '*const i32'
// tmp.zig:4:22: note: cast discards const qualifier
