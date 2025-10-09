const std = @import("std");

test "deposit bits" {
    try std.testing.expectEqual(@depositBits(0x00001234, 0xf0f0f0f0), 0x10203040);
}

// test
