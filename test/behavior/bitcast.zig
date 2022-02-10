const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;
const native_endian = builtin.target.cpu.arch.endian();

test "@bitCast i32 -> u32" {
    try testBitCast_i32_u32();
    comptime try testBitCast_i32_u32();
}

fn testBitCast_i32_u32() !void {
    try expect(conv_i32(-1) == maxInt(u32));
    try expect(conv_u32(maxInt(u32)) == -1);
    try expect(conv_u32(0x8000_0000) == minInt(i32));
    try expect(conv_i32(minInt(i32)) == 0x8000_0000);
}

fn conv_i32(x: i32) u32 {
    return @bitCast(u32, x);
}
fn conv_u32(x: u32) i32 {
    return @bitCast(i32, x);
}

test "@bitCast i48 -> u48" {
    try testBitCast_i48_u48();
    comptime try testBitCast_i48_u48();
}

fn testBitCast_i48_u48() !void {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try expect(conv_i48(-1) == maxInt(u48));
    try expect(conv_u48(maxInt(u48)) == -1);
    try expect(conv_u48(0x8000_0000_0000) == minInt(i48));
    try expect(conv_i48(minInt(i48)) == 0x8000_0000_0000);
}

fn conv_i48(x: i48) u48 {
    return @bitCast(u48, x);
}

fn conv_u48(x: u48) i48 {
    return @bitCast(i48, x);
}

test "@bitCast i27 -> u27" {
    try testBitCast_i27_u27();
    comptime try testBitCast_i27_u27();
}

fn testBitCast_i27_u27() !void {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try expect(conv_i27(-1) == maxInt(u27));
    try expect(conv_u27(maxInt(u27)) == -1);
    try expect(conv_u27(0x400_0000) == minInt(i27));
    try expect(conv_i27(minInt(i27)) == 0x400_0000);
}

fn conv_i27(x: i27) u27 {
    return @bitCast(u27, x);
}

fn conv_u27(x: u27) i27 {
    return @bitCast(i27, x);
}

test "@bitCast i512 -> u512" {
    try testBitCast_i512_u512();
    comptime try testBitCast_i512_u512();
}

fn testBitCast_i512_u512() !void {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try expect(conv_i512(-1) == maxInt(u512));
    try expect(conv_u512(maxInt(u512)) == -1);
    try expect(conv_u512(@as(u512, 1) << 511) == minInt(i512));
    try expect(conv_i512(minInt(i512)) == (@as(u512, 1) << 511));
}

fn conv_i512(x: i512) u512 {
    return @bitCast(u512, x);
}

fn conv_u512(x: u512) i512 {
    return @bitCast(i512, x);
}

test "bitcast result to _" {
    _ = @bitCast(u8, @as(i8, 1));
}

test "@bitCast i493 -> u493" {
    try testBitCast_i493_u493();
    comptime try testBitCast_i493_u493();
}

fn testBitCast_i493_u493() !void {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    try expect(conv_i493(-1) == maxInt(u493));
    try expect(conv_u493(maxInt(u493)) == -1);
    try expect(conv_u493(@as(u493, 1) << 492) == minInt(i493));
    try expect(conv_i493(minInt(i493)) == (@as(u493, 1) << 492));
}

fn conv_i493(x: i493) u493 {
    return @bitCast(u493, x);
}

fn conv_u493(x: u493) i493 {
    return @bitCast(i493, x);
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
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

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
            switch (native_endian) {
                .Big => {
                    try expect(two_halves.half1 == 0x12);
                    try expect(two_halves.quarter3 == 0x3);
                    try expect(two_halves.quarter4 == 0x4);
                },
                .Little => {
                    try expect(two_halves.half1 == 0x34);
                    try expect(two_halves.quarter3 == 0x2);
                    try expect(two_halves.quarter4 == 0x1);
                },
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "@bitCast extern structs at runtime and comptime" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

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
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const Foo = packed struct {
        value: u8,
    };
    const casted = @bitCast(u8, Foo{ .value = 0xF });
    try expect(casted == 0xf);
}

test "comptime bitcast used in expression has the correct type" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const Foo = packed struct {
        value: u8,
    };
    try expect(@bitCast(u8, Foo{ .value = 0xF }) == 0xf);
}

test "bitcast passed as tuple element" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

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
