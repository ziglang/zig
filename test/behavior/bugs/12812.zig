const std = @import("std");
const builtin = @import("builtin");

test "issue12812" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var x: @Vector(2, u15) = .{ 1, 4 };
    const y: @Vector(2, u15) = .{ 1, 4 };
    try std.testing.expect((&x[1]).* == 4);
    try std.testing.expect((&y[1]).* == 4);
}
