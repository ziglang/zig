const builtin = @import("std").builtin;
comptime {
    _ = @Type(.{ .float = .{ .bits = 17 } });
}

// error
//
// :3:9: error: 17-bit float unsupported
