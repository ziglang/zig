const std = @import("std");

inline fn foo(comptime T: type) !T {
    return error.AnError;
}

fn main0() !void {
    _ = try foo(u8);
}

test "issue12644" {
    main0() catch |e| {
        try std.testing.expect(e == error.AnError);
    };
}
