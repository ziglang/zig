const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var opt_x: ?[3]f32 = [_]f32{0.0} ** 3;

    const x = opt_x.?;
    opt_x.?[0] = 15.0;

    try expect(x[0] == 0.0);
}
