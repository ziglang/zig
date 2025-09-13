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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
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

test "'return try' of empty error set in function returning non-error" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
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

test "'return try' through conditional" {
    const S = struct {
        fn get(t: bool) !u32 {
            return try if (t) inner() else error.TestFailed;
        }
        fn inner() !u16 {
            return 123;
        }
    };

    {
        const result = try S.get(true);
        try expect(result == 123);
    }

    {
        const result = try comptime S.get(true);
        comptime std.debug.assert(result == 123);
    }
}

test "try ptr propagation const" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn foo0() !u32 {
            return 0;
        }

        fn foo1() error{Bad}!u32 {
            return 1;
        }

        fn foo2() anyerror!u32 {
            return 2;
        }

        fn doTheTest() !void {
            const res0: *const u32 = &(try foo0());
            const res1: *const u32 = &(try foo1());
            const res2: *const u32 = &(try foo2());
            try expect(res0.* == 0);
            try expect(res1.* == 1);
            try expect(res2.* == 2);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}

test "try ptr propagation mutate" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn foo0() !u32 {
            return 0;
        }

        fn foo1() error{Bad}!u32 {
            return 1;
        }

        fn foo2() anyerror!u32 {
            return 2;
        }

        fn doTheTest() !void {
            var f0 = foo0();
            var f1 = foo1();
            var f2 = foo2();

            const res0: *u32 = &(try f0);
            const res1: *u32 = &(try f1);
            const res2: *u32 = &(try f2);

            res0.* += 1;
            res1.* += 1;
            res2.* += 1;

            try expect(f0 catch unreachable == 1);
            try expect(f1 catch unreachable == 2);
            try expect(f2 catch unreachable == 3);

            try expect(res0.* == 1);
            try expect(res1.* == 2);
            try expect(res2.* == 3);
        }
    };
    try S.doTheTest();
    try comptime S.doTheTest();
}
