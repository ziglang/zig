const builtin = @import("std").builtin;
comptime {
    _ = @Type(.{ .Float = .{ .bits = 17 } });
}

// error
// backend=stage2
// target=native
//
// :3:9: error: 17-bit float unsupported
