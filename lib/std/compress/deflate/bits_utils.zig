const math = @import("std").math;

// Reverse bit-by-bit a N-bit code.
pub fn bitReverse(comptime T: type, value: T, N: usize) T {
    const r = @bitReverse(value);
    return r >> @as(math.Log2Int(T), @intCast(@typeInfo(T).Int.bits - N));
}

test "bitReverse" {
    const std = @import("std");

    const ReverseBitsTest = struct {
        in: u16,
        bit_count: u5,
        out: u16,
    };

    var reverse_bits_tests = [_]ReverseBitsTest{
        .{ .in = 1, .bit_count = 1, .out = 1 },
        .{ .in = 1, .bit_count = 2, .out = 2 },
        .{ .in = 1, .bit_count = 3, .out = 4 },
        .{ .in = 1, .bit_count = 4, .out = 8 },
        .{ .in = 1, .bit_count = 5, .out = 16 },
        .{ .in = 17, .bit_count = 5, .out = 17 },
        .{ .in = 257, .bit_count = 9, .out = 257 },
        .{ .in = 29, .bit_count = 5, .out = 23 },
    };

    for (reverse_bits_tests) |h| {
        var v = bitReverse(u16, h.in, h.bit_count);
        try std.testing.expectEqual(h.out, v);
    }
}
