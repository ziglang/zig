const std = @import("std");
const builtin = @import("builtin");

test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var x: u32 = 3;
    const val: usize = while (true) switch (x) {
        1 => break 2,
        else => x -= 1,
    };
    try std.testing.expect(val == 2);
}
