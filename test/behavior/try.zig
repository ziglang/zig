const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;

test "try on error union" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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
    if (failIfTrue(true)) {
        unreachable;
    } else |err| {
        try expect(err == error.ItBroke);
    }
}

test "`try`ing an if/else expression" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn getError() !void {
            return error.Test;
        }

        fn getError2() !void {
            var a: u8 = 'c';
            _ = &a;
            try if (a == 'a') getError() else if (a == 'b') getError() else getError();
        }
    };

    try std.testing.expectError(error.Test, S.getError2());
}

test "try forwards result location" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn foo(err: bool) error{Foo}!u32 {
            const result: error{ Foo, Bar }!u32 = if (err) error.Foo else 123;
            const res_int: u32 = try @errorCast(result);
            return res_int;
        }
    };

    try expect((S.foo(false) catch return error.TestUnexpectedResult) == 123);
    try std.testing.expectError(error.Foo, S.foo(true));
}

test "'return try' of empty error set in function returning non-error" {
    if (builtin.zig_backend == .stage2_x86) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn succeed0() error{}!u32 {
            return 123;
        }
        fn succeed1() !u32 {
            return 456;
        }
        fn tryNoError0() u32 {
            return try succeed0();
        }
        fn tryNoError1() u32 {
            return try succeed1();
        }
        fn tryNoError2() u32 {
            const e: error{}!u32 = 789;
            return try e;
        }
        fn doTheTest() !void {
            const res0 = tryNoError0();
            const res1 = tryNoError1();
            const res2 = tryNoError2();
            try expect(res0 == 123);
            try expect(res1 == 456);
            try expect(res2 == 789);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}
