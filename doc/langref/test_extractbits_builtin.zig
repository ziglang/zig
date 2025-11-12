const std = @import("std");

test "extract bits" {
    try std.testing.expectEqual(@extractBits(0x12345678, 0xf0f0f0f0), 0x00001357);
}

// test
