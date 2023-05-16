const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const math = std.math;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;
const native_endian = builtin.target.cpu.arch.endian();

test "@bitCast iX -> uX (32, 64)" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const bit_values = [_]usize{ 32, 64 };

    inline for (bit_values) |bits| {
        try testBitCast(bits);
        comptime try testBitCast(bits);
    }
}

test "@bitCast iX -> uX (8, 16, 128)" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const bit_values = [_]usize{ 8, 16, 128 };

    inline for (bit_values) |bits| {
        try testBitCast(bits);
        comptime try testBitCast(bits);
    }
}

test "@bitCast iX -> uX exotic integers" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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

    if (N > 24) {
        try expect(conv_uN(N, 0xf23456) == 0xf23456);
    }
}

fn conv_iN(comptime N: usize, x: std.meta.Int(.signed, N)) std.meta.Int(.unsigned, N) {
    return @bitCast(std.meta.Int(.unsigned, N), x);
}

fn conv_uN(comptime N: usize, x: std.meta.Int(.unsigned, N)) std.meta.Int(.signed, N) {
    return @bitCast(std.meta.Int(.signed, N), x);
}

test "bitcast uX to bytes" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const bit_values = [_]usize{ 1, 48, 27, 512, 493, 293, 125, 204, 112 };
    inline for (bit_values) |bits| {
        try testBitCast(bits);
        comptime try testBitCast(bits);
    }
}

fn testBitCastuXToBytes(comptime N: usize) !void {

    // The location of padding bits in these layouts are technically not defined
    // by LLVM, but we currently allow exotic integers to be cast (at comptime)
    // to types that expose their padding bits anyway.
    //
    // This test at least makes sure those bits are matched by the runtime behavior
    // on the platforms we target. If the above behavior is restricted after all,
    // this test should be deleted.

    const T = std.meta.Int(.unsigned, N);
    for ([_]T{ 0, ~@as(T, 0) }) |init_value| {
        var x: T = init_value;
        const bytes = std.mem.asBytes(&x);

        const byte_count = (N + 7) / 8;
        switch (native_endian) {
            .Little => {
                var byte_i = 0;
                while (byte_i < (byte_count - 1)) : (byte_i += 1) {
                    try expect(bytes[byte_i] == 0xff);
                }
                try expect(((bytes[byte_i] ^ 0xff) << -%@truncate(u3, N)) == 0);
            },
            .Big => {
                var byte_i = byte_count - 1;
                while (byte_i > 0) : (byte_i -= 1) {
                    try expect(bytes[byte_i] == 0xff);
                }
                try expect(((bytes[byte_i] ^ 0xff) << -%@truncate(u3, N)) == 0);
            },
        }
    }
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

// issue #3010: compiler segfault
test "bitcast literal [4]u8 param to u32" {
    const ip = @bitCast(u32, [_]u8{ 255, 255, 255, 255 });
    try expect(ip == maxInt(u32));
}

test "bitcast generates a temporary value" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    var y = @as(u16, 0x55AA);
    const x = @bitCast(u16, @bitCast([2]u8, y));
    try expect(y == x);
}

test "@bitCast packed structs at runtime and comptime" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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
    const Foo = packed struct {
        value: u8,
    };
    const casted = @bitCast(u8, Foo{ .value = 0xF });
    try expect(casted == 0xf);
}

test "comptime bitcast used in expression has the correct type" {
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
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

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

test "comptime @bitCast packed struct to int and back" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    if (builtin.zig_backend == .stage2_llvm and native_endian == .Big) {
        // https://github.com/ziglang/zig/issues/13782
        return error.SkipZigTest;
    }

    const S = packed struct {
        void: void = {},
        uint: u8 = 13,
        uint_bit_aligned: u3 = 2,
        iint_pos: i4 = 1,
        iint_neg4: i3 = -4,
        iint_neg2: i3 = -2,
        float: f32 = 3.14,
        @"enum": enum(u2) { A, B = 1, C, D } = .B,
        vectorb: @Vector(3, bool) = .{ true, false, true },
        vectori: @Vector(2, u8) = .{ 127, 42 },
        vectorf: @Vector(2, f16) = .{ 3.14, 2.71 },
    };
    const Int = @typeInfo(S).Struct.backing_integer.?;

    // S -> Int
    var s: S = .{};
    try expectEqual(@bitCast(Int, s), comptime @bitCast(Int, S{}));

    // Int -> S
    var i: Int = 0;
    const rt_cast = @bitCast(S, i);
    const ct_cast = comptime @bitCast(S, @as(Int, 0));
    inline for (@typeInfo(S).Struct.fields) |field| {
        try expectEqual(@field(rt_cast, field.name), @field(ct_cast, field.name));
    }
}

test "comptime bitcast with fields following f80" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const FloatT = extern struct { f: f80, x: u128 align(16) };
    const x: FloatT = .{ .f = 0.5, .x = 123 };
    var x_as_uint: u256 = comptime @bitCast(u256, x);

    try expect(x.f == @bitCast(FloatT, x_as_uint).f);
    try expect(x.x == @bitCast(FloatT, x_as_uint).x);
}

test "bitcast vector to integer and back" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const arr: [16]bool = [_]bool{ true, false } ++ [_]bool{true} ** 14;
    var x = @splat(16, true);
    x[1] = false;
    try expect(@bitCast(u16, x) == comptime @bitCast(u16, @as(@Vector(16, bool), arr)));
}

fn bitCastWrapper16(x: f16) u16 {
    return @bitCast(u16, x);
}
fn bitCastWrapper32(x: f32) u32 {
    return @bitCast(u32, x);
}
fn bitCastWrapper64(x: f64) u64 {
    return @bitCast(u64, x);
}
fn bitCastWrapper128(x: f128) u128 {
    return @bitCast(u128, x);
}
test "bitcast nan float does modify signaling bit" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    // TODO: https://github.com/ziglang/zig/issues/14366
    if (builtin.cpu.arch == .arm and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;

    // 16 bit
    const snan_f16_const = math.nan_f16;
    try expectEqual(math.nan_u16, @bitCast(u16, snan_f16_const));
    try expectEqual(math.nan_u16, bitCastWrapper16(snan_f16_const));

    var snan_f16_var = math.nan_f16;
    try expectEqual(math.nan_u16, @bitCast(u16, snan_f16_var));
    try expectEqual(math.nan_u16, bitCastWrapper16(snan_f16_var));

    // 32 bit
    const snan_f32_const = math.nan_f32;
    try expectEqual(math.nan_u32, @bitCast(u32, snan_f32_const));
    try expectEqual(math.nan_u32, bitCastWrapper32(snan_f32_const));

    var snan_f32_var = math.nan_f32;
    try expectEqual(math.nan_u32, @bitCast(u32, snan_f32_var));
    try expectEqual(math.nan_u32, bitCastWrapper32(snan_f32_var));

    // 64 bit
    const snan_f64_const = math.nan_f64;
    try expectEqual(math.nan_u64, @bitCast(u64, snan_f64_const));
    try expectEqual(math.nan_u64, bitCastWrapper64(snan_f64_const));

    var snan_f64_var = math.nan_f64;
    try expectEqual(math.nan_u64, @bitCast(u64, snan_f64_var));
    try expectEqual(math.nan_u64, bitCastWrapper64(snan_f64_var));

    // 128 bit
    const snan_f128_const = math.nan_f128;
    try expectEqual(math.nan_u128, @bitCast(u128, snan_f128_const));
    try expectEqual(math.nan_u128, bitCastWrapper128(snan_f128_const));

    var snan_f128_var = math.nan_f128;
    try expectEqual(math.nan_u128, @bitCast(u128, snan_f128_var));
    try expectEqual(math.nan_u128, bitCastWrapper128(snan_f128_var));
}
