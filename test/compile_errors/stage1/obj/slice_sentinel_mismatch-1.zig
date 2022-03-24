export fn entry() void {
    const y: [:1]const u8 = &[_:2]u8{ 1, 2 };
    _ = y;
}

// slice sentinel mismatch - 1
//
// tmp.zig:2:37: error: expected type '[:1]const u8', found '*const [2:2]u8'
