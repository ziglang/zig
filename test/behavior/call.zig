const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "super basic invocations" {
    const foo = struct {
        fn foo() i32 {
            return 1234;
        }
    }.foo;
    try expect(@call(.auto, foo, .{}) == 1234);
    comptime assert(@call(.always_inline, foo, .{}) == 1234);
    {
        // comptime call without comptime keyword
        const result = @call(.compile_time, foo, .{}) == 1234;
        comptime assert(result);
    }
}

test "basic invocations" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const foo = struct {
        fn foo() i32 {
            return 1234;
        }
    }.foo;
    try expect(@call(.auto, foo, .{}) == 1234);
    comptime {
        // modifiers that allow comptime calls
        try expect(@call(.auto, foo, .{}) == 1234);
        try expect(@call(.no_async, foo, .{}) == 1234);
        try expect(@call(.always_tail, foo, .{}) == 1234);
        try expect(@call(.always_inline, foo, .{}) == 1234);
    }
    {
        // comptime call without comptime keyword
        const result = @call(.compile_time, foo, .{}) == 1234;
        comptime assert(result);
    }
    {
        // call of non comptime-known function
        var alias_foo = &foo;
        _ = &alias_foo;
        try expect(@call(.no_async, alias_foo, .{}) == 1234);
        try expect(@call(.never_tail, alias_foo, .{}) == 1234);
        try expect(@call(.never_inline, alias_foo, .{}) == 1234);
    }
}

test "tuple parameters" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const add = struct {
        fn add(a: i32, b: i32) i32 {
            return a + b;
        }
    }.add;
    var a: i32 = 12;
    var b: i32 = 34;
    _ = .{ &a, &b };
    try expect(@call(.auto, add, .{ a, 34 }) == 46);
    try expect(@call(.auto, add, .{ 12, b }) == 46);
    try expect(@call(.auto, add, .{ a, b }) == 46);
    try expect(@call(.auto, add, .{ 12, 34 }) == 46);
    if (false) {
        comptime assert(@call(.auto, add, .{ 12, 34 }) == 46); // TODO
    }
    try expect(comptime @call(.auto, add, .{ 12, 34 }) == 46);
    {
        const separate_args0 = .{ a, b };
        const separate_args1 = .{ a, 34 };
        const separate_args2 = .{ 12, 34 };
        const separate_args3 = .{ 12, b };
        try expect(@call(.always_inline, add, separate_args0) == 46);
        try expect(@call(.always_inline, add, separate_args1) == 46);
        try expect(@call(.always_inline, add, separate_args2) == 46);
        try expect(@call(.always_inline, add, separate_args3) == 46);
    }
}

test "result location of function call argument through runtime condition and struct init" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const E = enum { a, b };
    const S = struct {
        e: E,
    };
    const namespace = struct {
        fn foo(s: S) !void {
            try expect(s.e == .b);
        }
    };
    var runtime = true;
    _ = &runtime;
    try namespace.foo(.{
        .e = if (!runtime) .a else .b,
    });
}

test "function call with 40 arguments" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const S = struct {
        fn doTheTest(thirty_nine: i32) !void {
            const result = add(
                0,
                1,
                2,
                3,
                4,
                5,
                6,
                7,
                8,
                9,
                10,
                11,
                12,
                13,
                14,
                15,
                16,
                17,
                18,
                19,
                20,
                21,
                22,
                23,
                24,
                25,
                26,
                27,
                28,
                29,
                30,
                31,
                32,
                33,
                34,
                35,
                36,
                37,
                38,
                thirty_nine,
                40,
            );
            try expect(result == 820);
            try expect(thirty_nine == 39);
        }

        fn add(
            a0: i32,
            a1: i32,
            a2: i32,
            a3: i32,
            a4: i32,
            a5: i32,
            a6: i32,
            a7: i32,
            a8: i32,
            a9: i32,
            a10: i32,
            a11: i32,
            a12: i32,
            a13: i32,
            a14: i32,
            a15: i32,
            a16: i32,
            a17: i32,
            a18: i32,
            a19: i32,
            a20: i32,
            a21: i32,
            a22: i32,
            a23: i32,
            a24: i32,
            a25: i32,
            a26: i32,
            a27: i32,
            a28: i32,
            a29: i32,
            a30: i32,
            a31: i32,
            a32: i32,
            a33: i32,
            a34: i32,
            a35: i32,
            a36: i32,
            a37: i32,
            a38: i32,
            a39: i32,
            a40: i32,
        ) i32 {
            return a0 +
                a1 +
                a2 +
                a3 +
                a4 +
                a5 +
                a6 +
                a7 +
                a8 +
                a9 +
                a10 +
                a11 +
                a12 +
                a13 +
                a14 +
                a15 +
                a16 +
                a17 +
                a18 +
                a19 +
                a20 +
                a21 +
                a22 +
                a23 +
                a24 +
                a25 +
                a26 +
                a27 +
                a28 +
                a29 +
                a30 +
                a31 +
                a32 +
                a33 +
                a34 +
                a35 +
                a36 +
                a37 +
                a38 +
                a39 +
                a40;
        }
    };
    try S.doTheTest(39);
}

test "arguments to comptime parameters generated in comptime blocks" {
    const S = struct {
        fn fortyTwo() i32 {
            return 42;
        }

        fn foo(comptime x: i32) void {
            if (x != 42) @compileError("bad");
        }
    };
    S.foo(S.fortyTwo());
}

test "forced tail call" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm) {
        if (builtin.cpu.arch.isMIPS() or builtin.cpu.arch.isPowerPC() or builtin.cpu.arch.isWasm()) {
            return error.SkipZigTest;
        }
    }

    if (builtin.zig_backend == .stage2_c and builtin.os.tag == .windows) return error.SkipZigTest; // MSVC doesn't support always tail calls

    const S = struct {
        fn fibonacciTailInternal(n: u16, a: u16, b: u16) u16 {
            if (n == 0) return a;
            if (n == 1) return b;
            return @call(
                .always_tail,
                fibonacciTailInternal,
                .{ n - 1, b, a + b },
            );
        }

        fn fibonacciTail(n: u16) u16 {
            return fibonacciTailInternal(n, 0, 1);
        }
    };
    try expect(S.fibonacciTail(10) == 55);
}

test "inline call preserves tail call" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm) {
        if (builtin.cpu.arch.isMIPS() or builtin.cpu.arch.isPowerPC() or builtin.cpu.arch.isWasm()) {
            return error.SkipZigTest;
        }
    }

    if (builtin.zig_backend == .stage2_c and builtin.os.tag == .windows) return error.SkipZigTest; // MSVC doesn't support always tail calls

    const max = std.math.maxInt(u16);
    const S = struct {
        var a: u16 = 0;
        fn foo() void {
            return bar();
        }

        inline fn bar() void {
            if (a == max) return;
            // Stack overflow if not tail called
            var buf: [max]u16 = undefined;
            buf[a] = a;
            a += 1;
            return @call(.always_tail, foo, .{});
        }
    };
    S.foo();
    try expect(S.a == std.math.maxInt(u16));
}

test "inline call doesn't re-evaluate non generic struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo(f: struct { a: u8, b: u8 }) !void {
            try expect(f.a == 123);
            try expect(f.b == 45);
        }
    };
    const ArgTuple = std.meta.ArgsTuple(@TypeOf(S.foo));
    try @call(.always_inline, S.foo, ArgTuple{.{ .a = 123, .b = 45 }});
    try comptime @call(.always_inline, S.foo, ArgTuple{.{ .a = 123, .b = 45 }});
}

test "Enum constructed by @Type passed as generic argument" {
    const S = struct {
        const E = std.meta.FieldEnum(struct {
            prev_pos: bool,
            pos: bool,
            vel: bool,
            damp_vel: bool,
            acc: bool,
            rgba: bool,
            prev_scale: bool,
            scale: bool,
            prev_rotation: bool,
            rotation: bool,
            angular_vel: bool,
            alive: bool,
        });
        fn foo(comptime a: E, b: u32) !void {
            try expect(@intFromEnum(a) == b);
        }
    };
    inline for (@typeInfo(S.E).@"enum".fields, 0..) |_, i| {
        try S.foo(@as(S.E, @enumFromInt(i)), i);
    }
}

test "generic function with generic function parameter" {
    const S = struct {
        fn f(comptime a: fn (anytype) anyerror!void, b: anytype) anyerror!void {
            try a(b);
        }
        fn g(a: anytype) anyerror!void {
            try expect(a == 123);
        }
    };
    try S.f(S.g, 123);
}

test "recursive inline call with comptime known argument" {
    const S = struct {
        inline fn foo(x: i32) i32 {
            if (x <= 0) {
                return 0;
            } else {
                return x * 2 + foo(x - 1);
            }
        }
    };

    try expect(S.foo(4) == 20);
}

test "inline while with @call" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        fn inc(a: *u32) void {
            a.* += 1;
        }
    };
    var a: u32 = 0;
    comptime var i = 0;
    inline while (i < 10) : (i += 1) {
        @call(.auto, S.inc, .{&a});
    }
    try expect(a == 10);
}

test "method call as parameter type" {
    const S = struct {
        fn foo(x: anytype, y: @TypeOf(x).Inner()) @TypeOf(y) {
            return y;
        }
        fn Inner() type {
            return u64;
        }
    };
    try expectEqual(@as(u64, 123), S.foo(S{}, 123));
    try expectEqual(@as(u64, 500), S.foo(S{}, 500));
}

test "non-anytype generic parameters provide result type" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn f(comptime T: type, y: T) !void {
            try expectEqual(@as(T, 123), y);
        }

        fn g(x: anytype, y: @TypeOf(x)) !void {
            try expectEqual(@as(@TypeOf(x), 0x222), y);
        }
    };

    var rt_u16: u16 = 123;
    var rt_u32: u32 = 0x10000222;
    _ = .{ &rt_u16, &rt_u32 };

    try S.f(u8, @intCast(rt_u16));
    try S.f(u8, @intCast(123));

    try S.g(rt_u16, @truncate(rt_u32));
    try S.g(rt_u16, @truncate(0x10000222));

    try comptime S.f(u8, @intCast(123));
    try comptime S.g(@as(u16, undefined), @truncate(0x99990222));
}

test "argument to generic function has correct result type" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo(_: anytype, e: enum { a, b }) bool {
            return e == .b;
        }

        fn doTheTest() !void {
            var t = true;
            _ = &t;

            // Since the enum literal passes through a runtime conditional here, these can only
            // compile if RLS provides the correct result type to the argument
            try expect(foo({}, if (!t) .a else .b));
            try expect(!foo("dummy", if (t) .a else .b));
            try expect(foo({}, if (t) .b else .a));
            try expect(!foo(123, if (t) .a else .a));
            try expect(foo(123, if (t) .b else .b));
        }
    };

    try S.doTheTest();
    try comptime S.doTheTest();
}

test "call inline fn through pointer" {
    const S = struct {
        inline fn foo(x: u8) !void {
            try expect(x == 123);
        }
    };
    const f = &S.foo;
    try f(123);
}

test "call coerced function" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const T = struct {
        x: f64,
        const T = @This();
        usingnamespace Implement(1);
        const F = fn (comptime f64) type;
        const Implement: F = opaque {
            fn implementer(comptime val: anytype) type {
                return opaque {
                    fn incr(self: T) T {
                        return .{ .x = self.x + val };
                    }
                };
            }
        }.implementer;
    };

    const a = T{ .x = 3 };
    try std.testing.expect(a.incr().x == 4);
}

test "call function in comptime field" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const S = struct {
        comptime capacity: fn () u64 = capacity_,
        fn capacity_() u64 {
            return 64;
        }
    };
    try std.testing.expect((S{}).capacity() == 64);
}

test "call function pointer in comptime field" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const Auto = struct {
        auto: [max_len]u8 = undefined,
        offset: u64 = 0,

        comptime capacityFn: *const fn () u64 = capacity,

        const max_len: u64 = 32;

        fn capacity() u64 {
            return max_len;
        }
    };

    const a: Auto = .{ .offset = 16, .capacityFn = Auto.capacity };
    try std.testing.expect(a.capacityFn() == 32);
    try std.testing.expect((a.capacityFn)() == 32);
}

test "generic function pointer can be called" {
    const S = struct {
        var ok = false;
        fn foo(x: anytype) void {
            ok = x;
        }
    };
    const x = &S.foo;
    x(true);
    try expect(S.ok);
}

test "value returned from comptime function is comptime known" {
    const S = struct {
        fn fields(comptime T: type) switch (@typeInfo(T)) {
            .@"struct" => []const std.builtin.Type.StructField,
            else => unreachable,
        } {
            return switch (@typeInfo(T)) {
                .@"struct" => |info| info.fields,
                else => unreachable,
            };
        }
    };
    const fields_list = S.fields(@TypeOf(.{}));
    if (fields_list.len != 0)
        @compileError("Argument count mismatch");
}

test "registers get overwritten when ignoring return" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.cpu.arch != .x86_64 or builtin.os.tag != .linux) return error.SkipZigTest;

    const S = struct {
        fn open() usize {
            return 42;
        }
        fn write(fd: usize, a: [*]const u8, len: usize) usize {
            return syscall4(.WRITE, fd, @intFromPtr(a), len);
        }
        fn syscall4(_: enum { WRITE }, _: usize, _: usize, _: usize) usize {
            return 23;
        }
        fn close(fd: usize) usize {
            if (fd != 42)
                unreachable;
            return 0;
        }
    };

    const fd = S.open();
    _ = S.write(fd, "a", 1);
    _ = S.close(fd);
}

test "call with union with zero sized field is not memorized incorrectly" {
    const U = union(enum) {
        T: type,
        N: void,
        fn S(comptime query: @This()) type {
            return struct {
                fn tag() type {
                    return query.T;
                }
            };
        }
    };
    const s1 = U.S(U{ .T = u32 }).tag();
    try std.testing.expectEqual(u32, s1);

    const s2 = U.S(U{ .T = u64 }).tag();
    try std.testing.expectEqual(u64, s2);
}

test "function call with cast to anyopaque pointer" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    const Foo = struct {
        y: u8,
        var foo: @This() = undefined;
        const t = &foo;

        fn bar(pointer: ?*anyopaque) void {
            _ = pointer;
        }
    };
    Foo.bar(Foo.t);
}
