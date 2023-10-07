const builtin = @import("builtin");
const std = @import("std");

const S = packed struct { a: u0 = 0 };
test {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var a: u8 = 0;
    try std.io.null_writer.print("\n{} {}\n", .{ a, S{} });
}
