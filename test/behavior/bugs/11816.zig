const std = @import("std");
const builtin = @import("builtin");

test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: u32 = 3;
    const val: usize = while (true) switch (x) {
        1 => break 2,
        else => x -= 1,
    };
    try std.testing.expect(val == 2);
}
