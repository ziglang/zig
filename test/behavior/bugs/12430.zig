const std = @import("std");

test {
    const T = comptime b: {
        break :b @Int(.unsigned, 8);
    };
    try std.testing.expect(T == u8);
}
