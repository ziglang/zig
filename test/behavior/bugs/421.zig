const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "bitCast to array" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    comptime try testBitCastArray();
    try testBitCastArray();
}

fn testBitCastArray() !void {
    try expect(extractOne64(0x0123456789abcdef0123456789abcdef) == 0x0123456789abcdef);
}

fn extractOne64(a: u128) u64 {
    const x = @bitCast([2]u64, a);
    return x[1];
}
