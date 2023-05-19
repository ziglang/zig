const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

const U = union(enum) {
    x: u128,
    y: [17]u8,
};

fn foo(val: U) !void {
    try expect(val.x == 1);
}

test "runtime union init, most-aligned field != largest" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var x: u8 = 1;
    try foo(.{ .x = x });

    const val: U = @unionInit(U, "x", x);
    try expect(val.x == 1);

    const val2: U = .{ .x = x };
    try expect(val2.x == 1);
}
