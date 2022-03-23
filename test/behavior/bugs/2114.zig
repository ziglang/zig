const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const math = std.math;

fn ctz(x: anytype) usize {
    return @ctz(@TypeOf(x), x);
}

test "fixed" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO

    try testCtz();
    comptime try testCtz();
}

fn testCtz() !void {
    try expect(ctz(@as(u128, 0x40000000000000000000000000000000)) == 126);
    try expect(math.rotl(u128, @as(u128, 0x40000000000000000000000000000000), @as(u8, 1)) == @as(u128, 0x80000000000000000000000000000000));
    try expect(ctz(@as(u128, 0x80000000000000000000000000000000)) == 127);
    try expect(ctz(math.rotl(u128, @as(u128, 0x40000000000000000000000000000000), @as(u8, 1))) == 127);
}
