const builtin = @import("builtin");
const expect = @import("std").testing.expect;

test "bitCast to array" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

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
