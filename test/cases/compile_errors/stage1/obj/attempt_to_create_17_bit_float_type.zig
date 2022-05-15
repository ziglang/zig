const builtin = @import("std").builtin;
comptime {
    _ = @Type(.{ .Float = .{ .bits = 17 } });
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:16: error: 17-bit float unsupported
