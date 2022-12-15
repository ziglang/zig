const std = @import("std");
const builtin = @import("builtin");

test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    const a = @Vector(2, bool){ true, true };
    const b = @Vector(1, bool){true};
    try std.testing.expect(@reduce(.And, a));
    try std.testing.expect(@reduce(.And, b));
}
