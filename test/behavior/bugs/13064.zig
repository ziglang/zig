const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: [10][10]u32 = undefined;

    x[0][1] = 0;
    const a = x[0];
    x[0][1] = 15;

    try expect(a[1] == 0);
}
