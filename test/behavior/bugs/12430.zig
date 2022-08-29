const std = @import("std");

test {
    const T = comptime b: {
        break :b @Type(.{ .Int = .{
            .signedness = .unsigned,
            .bits = 8,
        } });
    };
    try std.testing.expect(T == u8);
}
