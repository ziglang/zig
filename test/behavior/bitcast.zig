const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;
const native_endian = builtin.target.cpu.arch.endian();

test "@bitCast iX -> uX (32, 64)" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const bit_values = [_]usize{ 32, 64 };

    inline for (bit_values) |bits| {
        try testBitCast(bits);
        comptime try testBitCast(bits);
    }
}

test "@bitCast iX -> uX (8, 16, 128)" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const bit_values = [_]usize{ 8, 16, 128 };

    inline for (bit_values) |bits| {
        try testBitCast(bits);
        comptime try testBitCast(bits);
    }
}

test "@bitCast iX -> uX exotic integers" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const bit_values = [_]usize{ 1, 48, 27, 512, 493, 293, 125, 204, 112 };

    inline for (bit_values) |bits| {
        try testBitCast(bits);
        comptime try testBitCast(bits);
    }
}

fn testBitCast(comptime N: usize) !void {
    const iN = std.meta.Int(.signed, N);
    const uN = std.meta.Int(.unsigned, N);

    try expect(conv_iN(N, -1) == maxInt(uN));
    try expect(conv_uN(N, maxInt(uN)) == -1);

    try expect(conv_iN(N, maxInt(iN)) == maxInt(iN));
    try expect(conv_uN(N, maxInt(iN)) == maxInt(iN));

    try expect(conv_uN(N, 1 << (N - 1)) == minInt(iN));
    try expect(conv_iN(N, minInt(iN)) == (1 << (N - 1)));

    try expect(conv_uN(N, 0) == 0);
    try expect(conv_iN(N, 0) == 0);

    try expect(conv_iN(N, -0) == 0);
}

fn conv_iN(comptime N: usize, x: std.meta.Int(.signed, N)) std.meta.Int(.unsigned, N) {
    return @bitCast(std.meta.Int(.unsigned, N), x);
}

fn conv_uN(comptime N: usize, x: std.meta.Int(.unsigned, N)) std.meta.Int(.signed, N) {
    return @bitCast(std.meta.Int(.signed, N), x);
}

test "nested bitcast" {
    const S = struct {
        fn moo(x: isize) !void {
            try expect(@intCast(isize, 42) == x);
        }

        fn foo(x: isize) !void {
            try @This().moo(
                @bitCast(isize, if (x != 0) @bitCast(usize, x) else @bitCast(usize, x)),
            );
        }
    };

    try S.foo(42);
    comptime try S.foo(42);
}

test "@bitCast enum to its integer type" {
    const SOCK = enum(c_int) {
        A,
        B,

        fn testBitCastExternEnum() !void {
            var SOCK_DGRAM = @This().B;
            var sock_dgram = @bitCast(c_int, SOCK_DGRAM);
            try expect(sock_dgram == 1);
        }
    };

    try SOCK.testBitCastExternEnum();
    comptime try SOCK.testBitCastExternEnum();
}

// issue #3010: compiler segfault
test "bitcast literal [4]u8 param to u32" {
    const ip = @bitCast(u32, [_]u8{ 255, 255, 255, 255 });
    try expect(ip == maxInt(u32));
}

test "bitcast generates a temporary value" {
    var y = @as(u16, 0x55AA);
    const x = @bitCast(u16, @bitCast([2]u8, y));
    try expect(y == x);
}

test "@bitCast packed structs at runtime and comptime" {
    if (builtin.zig_backend == .stage1) {
        // stage1 gets the wrong answer for a lot of targets
        return error.SkipZigTest;
    }
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const Full = packed struct {
        number: u16,
    };
    const Divided = packed struct {
        half1: u8,
        quarter3: u4,
        quarter4: u4,
    };
    const S = struct {
        fn doTheTest() !void {
            var full = Full{ .number = 0x1234 };
            var two_halves = @bitCast(Divided, full);
            try expect(two_halves.half1 == 0x34);
            try expect(two_halves.quarter3 == 0x2);
            try expect(two_halves.quarter4 == 0x1);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@bitCast extern structs at runtime and comptime" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const Full = extern struct {
        number: u16,
    };
    const TwoHalves = extern struct {
        half1: u8,
        half2: u8,
    };
    const S = struct {
        fn doTheTest() !void {
            var full = Full{ .number = 0x1234 };
            var two_halves = @bitCast(TwoHalves, full);
            switch (native_endian) {
                .Big => {
                    try expect(two_halves.half1 == 0x12);
                    try expect(two_halves.half2 == 0x34);
                },
                .Little => {
                    try expect(two_halves.half1 == 0x34);
                    try expect(two_halves.half2 == 0x12);
                },
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "bitcast packed struct to integer and back" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const LevelUpMove = packed struct {
        move_id: u9,
        level: u7,
    };
    const S = struct {
        fn doTheTest() !void {
            var move = LevelUpMove{ .move_id = 1, .level = 2 };
            var v = @bitCast(u16, move);
            var back_to_a_move = @bitCast(LevelUpMove, v);
            try expect(back_to_a_move.move_id == 1);
            try expect(back_to_a_move.level == 2);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "implicit cast to error union by returning" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = struct {
        fn entry() !void {
            try expect((func(-1) catch unreachable) == maxInt(u64));
        }
        pub fn func(sz: i64) anyerror!u64 {
            return @bitCast(u64, sz);
        }
    };
    try S.entry();
    comptime try S.entry();
}

test "bitcast packed struct literal to byte" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Foo = packed struct {
        value: u8,
    };
    const casted = @bitCast(u8, Foo{ .value = 0xF });
    try expect(casted == 0xf);
}

test "comptime bitcast used in expression has the correct type" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const Foo = packed struct {
        value: u8,
    };
    try expect(@bitCast(u8, Foo{ .value = 0xF }) == 0xf);
}

test "bitcast passed as tuple element" {
    const S = struct {
        fn foo(args: anytype) !void {
            comptime try expect(@TypeOf(args[0]) == f32);
            try expect(args[0] == 12.34);
        }
    };
    try S.foo(.{@bitCast(f32, @as(u32, 0x414570A4))});
}

test "triple level result location with bitcast sandwich passed as tuple element" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;

    const S = struct {
        fn foo(args: anytype) !void {
            comptime try expect(@TypeOf(args[0]) == f64);
            try expect(args[0] > 12.33 and args[0] < 12.35);
        }
    };
    try S.foo(.{@as(f64, @bitCast(f32, @as(u32, 0x414570A4)))});
}

test "@bitCast packed struct of floats" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const Foo = packed struct {
        a: f16 = 0,
        b: f32 = 1,
        c: f64 = 2,
        d: f128 = 3,
    };

    const Foo2 = packed struct {
        a: f16 = 0,
        b: f32 = 1,
        c: f64 = 2,
        d: f128 = 3,
    };

    const S = struct {
        fn doTheTest() !void {
            var foo = Foo{};
            var v = @bitCast(Foo2, foo);
            try expect(v.a == foo.a);
            try expect(v.b == foo.b);
            try expect(v.c == foo.c);
            try expect(v.d == foo.d);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}
