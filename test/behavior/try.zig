const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "try on error union" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try tryOnErrorUnionImpl();
    try comptime tryOnErrorUnionImpl();
}

fn tryOnErrorUnionImpl() !void {
    const x = if (returnsTen()) |val| val + 1 else |err| switch (err) {
        error.ItBroke, error.NoMem => 1,
        error.CrappedOut => @as(i32, 2),
        else => unreachable,
    };
    try expect(x == 11);
}

fn returnsTen() anyerror!i32 {
    return 10;
}

test "try without vars" {
    const result1 = if (failIfTrue(true)) 1 else |_| @as(i32, 2);
    try expect(result1 == 2);

    const result2 = if (failIfTrue(false)) 1 else |_| @as(i32, 2);
    try expect(result2 == 1);
}

fn failIfTrue(ok: bool) anyerror!void {
    if (ok) {
        return error.ItBroke;
    } else {
        return;
    }
}

test "try then not executed with assignment" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    if (failIfTrue(true)) {
        unreachable;
    } else |err| {
        try expect(err == error.ItBroke);
    }
}
