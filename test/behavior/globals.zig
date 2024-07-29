const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

var pos = [2]f32{ 0.0, 0.0 };
test "store to global array" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(pos[1] == 0.0);
    pos = [2]f32{ 0.0, 1.0 };
    try expect(pos[1] == 1.0);
}

var vpos = @Vector(2, f32){ 0.0, 0.0 };
test "store to global vector" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    try expect(vpos[1] == 0.0);
    vpos = @Vector(2, f32){ 0.0, 1.0 };
    try expect(vpos[1] == 1.0);
}

test "slices pointing at the same address as global array." {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const a = [_]u8{ 1, 2, 3 };

        fn checkAddress(s: []const u8) !void {
            for (s, 0..) |*i, j| {
                try expect(i == &a[j]);
            }
        }
    };

    try S.checkAddress(&S.a);
    try comptime S.checkAddress(&S.a);
}

test "global loads can affect liveness" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;

    const S = struct {
        const ByRef = struct {
            a: u32,
        };

        var global_ptr: *ByRef = undefined;

        fn f() void {
            global_ptr.* = .{ .a = 42 };
        }
    };

    var x: S.ByRef = .{ .a = 1 };
    S.global_ptr = &x;
    const y = x;
    S.f();
    try std.testing.expect(y.a == 1);
}
