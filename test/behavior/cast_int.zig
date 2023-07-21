const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

test "@intCast i32 to u7" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: u128 = maxInt(u128);
    var y: i32 = 120;
    var z = x >> @as(u7, @intCast(y));
    try expect(z == 0xff);
}

test "coerce i8 to i32 and @intCast back" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: i8 = -5;
    var y: i32 = -5;
    try expect(y == x);

    var x2: i32 = -5;
    var y2: i8 = -5;
    try expect(y2 == @as(i8, @intCast(x2)));
}
