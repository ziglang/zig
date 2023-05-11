const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;

var x: u8 = 1;

// This excludes builtin functions that return void or noreturn that cannot be tested.
test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest; // TODO

    var val: u8 = undefined;
    try testing.expectEqual({}, @atomicStore(u8, &val, 0, .Unordered));
    try testing.expectEqual(void, @TypeOf(@breakpoint()));
    try testing.expectEqual({}, @export(x, .{ .name = "x" }));
    try testing.expectEqual({}, @fence(.Acquire));
    try testing.expectEqual({}, @memcpy(@intToPtr([*]u8, 1)[0..0], @intToPtr([*]u8, 1)[0..0]));
    try testing.expectEqual({}, @memset(@intToPtr([*]u8, 1)[0..0], undefined));
    try testing.expectEqual(noreturn, @TypeOf(if (true) @panic("") else {}));
    try testing.expectEqual({}, @prefetch(&val, .{}));
    try testing.expectEqual({}, @setAlignStack(16));
    try testing.expectEqual({}, @setCold(true));
    try testing.expectEqual({}, @setEvalBranchQuota(0));
    try testing.expectEqual({}, @setFloatMode(.Optimized));
    try testing.expectEqual({}, @setRuntimeSafety(true));
    try testing.expectEqual(noreturn, @TypeOf(if (true) @trap() else {}));
}
