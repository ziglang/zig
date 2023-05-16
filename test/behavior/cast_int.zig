const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

test "@intCast i32 to u7" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: u128 = maxInt(u128);
    var y: i32 = 120;
    var z = x >> @intCast(u7, y);
    try expect(z == 0xff);
}
