const builtin = @import("builtin");
const std = @import("std");
const expect = std.testing.expect;

const ComptimeReason = union(enum) {
    c_import: struct {
        a: u32,
    },
};

const Block = struct {
    reason: ?*const ComptimeReason,
};

test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var a: u32 = 16;
    var reason = .{ .c_import = .{ .a = a } };
    var block = Block{
        .reason = &reason,
    };
    try expect(block.reason.?.c_import.a == 16);
}
