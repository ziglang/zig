const std = @import("std");
const builtin = @import("builtin");

const B = union(enum) {
    D: u8,
    E: u16,
};

const A = union(enum) {
    B: B,
    C: u8,
};

test "union that needs padding bytes inside an array" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var as = [_]A{
        A{ .B = B{ .D = 1 } },
        A{ .B = B{ .D = 1 } },
    };

    const a = as[0].B;
    try std.testing.expect(a.D == 1);
}
