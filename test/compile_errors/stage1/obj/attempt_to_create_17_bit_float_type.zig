const builtin = @import("std").builtin;
comptime {
    _ = @Type(.{ .Float = .{ .bits = 17 } });
}

// attempt to create 17 bit float type
//
// tmp.zig:3:16: error: 17-bit float unsupported
