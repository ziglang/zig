const std = @import("std");
const builtin = @import("builtin");

inline fn foo(comptime T: type) !T {
    return error.AnError;
}

fn main0() !void {
    _ = try foo(u8);
}

test "issue12644" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    main0() catch |e| {
        try std.testing.expect(e == error.AnError);
    };
}
