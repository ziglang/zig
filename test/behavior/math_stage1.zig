const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;
const mem = std.mem;

test "@addWithOverflow" {
    var result: u8 = undefined;
    try expect(@addWithOverflow(u8, 250, 100, &result));
    try expect(!@addWithOverflow(u8, 100, 150, &result));
    try expect(result == 250);
}

// TODO test mulWithOverflow
// TODO test subWithOverflow

test "@shlWithOverflow" {
    var result: u16 = undefined;
    try expect(@shlWithOverflow(u16, 0b0010111111111111, 3, &result));
    try expect(!@shlWithOverflow(u16, 0b0010111111111111, 2, &result));
    try expect(result == 0b1011111111111100);
}

test "@*WithOverflow with u0 values" {
    var result: u0 = undefined;
    try expect(!@addWithOverflow(u0, 0, 0, &result));
    try expect(!@subWithOverflow(u0, 0, 0, &result));
    try expect(!@mulWithOverflow(u0, 0, 0, &result));
    try expect(!@shlWithOverflow(u0, 0, 0, &result));
}

test "@clz vectors" {
    try testClzVectors();
    comptime try testClzVectors();
}

fn testClzVectors() !void {
    @setEvalBranchQuota(10_000);
    try expectEqual(@clz(u8, @splat(64, @as(u8, 0b10001010))), @splat(64, @as(u4, 0)));
    try expectEqual(@clz(u8, @splat(64, @as(u8, 0b00001010))), @splat(64, @as(u4, 4)));
    try expectEqual(@clz(u8, @splat(64, @as(u8, 0b00011010))), @splat(64, @as(u4, 3)));
    try expectEqual(@clz(u8, @splat(64, @as(u8, 0b00000000))), @splat(64, @as(u4, 8)));
    try expectEqual(@clz(u128, @splat(64, @as(u128, 0xffffffffffffffff))), @splat(64, @as(u8, 64)));
    try expectEqual(@clz(u128, @splat(64, @as(u128, 0x10000000000000000))), @splat(64, @as(u8, 63)));
}

test "@ctz" {
    try testCtz();
    comptime try testCtz();
}

fn testCtz() !void {
    try expect(@ctz(u8, 0b10100000) == 5);
    try expect(@ctz(u8, 0b10001010) == 1);
    try expect(@ctz(u8, 0b00000000) == 8);
    try expect(@ctz(u16, 0b00000000) == 16);
}

test "@ctz vectors" {
    try testClzVectors();
    comptime try testClzVectors();
}

fn testCtzVectors() !void {
    @setEvalBranchQuota(10_000);
    try expectEqual(@ctz(u8, @splat(64, @as(u8, 0b10100000))), @splat(64, @as(u4, 5)));
    try expectEqual(@ctz(u8, @splat(64, @as(u8, 0b10001010))), @splat(64, @as(u4, 1)));
    try expectEqual(@ctz(u8, @splat(64, @as(u8, 0b00000000))), @splat(64, @as(u4, 8)));
    try expectEqual(@ctz(u16, @splat(64, @as(u16, 0b00000000))), @splat(64, @as(u5, 16)));
}

test "small int addition" {
    var x: u2 = 0;
    try expect(x == 0);

    x += 1;
    try expect(x == 1);

    x += 1;
    try expect(x == 2);

    x += 1;
    try expect(x == 3);

    var result: @TypeOf(x) = 3;
    try expect(@addWithOverflow(@TypeOf(x), x, 1, &result));

    try expect(result == 0);
}

test "allow signed integer division/remainder when values are comptime known and positive or exact" {
    try expect(5 / 3 == 1);
    try expect(-5 / -3 == 1);
    try expect(-6 / 3 == -2);

    try expect(5 % 3 == 2);
    try expect(-6 % 3 == 0);
}

test "quad hex float literal parsing accurate" {
    const a: f128 = 0x1.1111222233334444555566667777p+0;

    // implied 1 is dropped, with an exponent of 0 (0x3fff) after biasing.
    const expected: u128 = 0x3fff1111222233334444555566667777;
    try expect(@bitCast(u128, a) == expected);

    // non-normalized
    const b: f128 = 0x11.111222233334444555566667777p-4;
    try expect(@bitCast(u128, b) == expected);

    const S = struct {
        fn doTheTest() !void {
            {
                var f: f128 = 0x1.2eab345678439abcdefea56782346p+5;
                try expect(@bitCast(u128, f) == 0x40042eab345678439abcdefea5678234);
            }
            {
                var f: f128 = 0x1.edcb34a235253948765432134674fp-1;
                try expect(@bitCast(u128, f) == 0x3ffeedcb34a235253948765432134674);
            }
            {
                var f: f128 = 0x1.353e45674d89abacc3a2ebf3ff4ffp-50;
                try expect(@bitCast(u128, f) == 0x3fcd353e45674d89abacc3a2ebf3ff50);
            }
            {
                var f: f128 = 0x1.ed8764648369535adf4be3214567fp-9;
                try expect(@bitCast(u128, f) == 0x3ff6ed8764648369535adf4be3214568);
            }
            const exp2ft = [_]f64{
                0x1.6a09e667f3bcdp-1,
                0x1.7a11473eb0187p-1,
                0x1.8ace5422aa0dbp-1,
                0x1.9c49182a3f090p-1,
                0x1.ae89f995ad3adp-1,
                0x1.c199bdd85529cp-1,
                0x1.d5818dcfba487p-1,
                0x1.ea4afa2a490dap-1,
                0x1.0000000000000p+0,
                0x1.0b5586cf9890fp+0,
                0x1.172b83c7d517bp+0,
                0x1.2387a6e756238p+0,
                0x1.306fe0a31b715p+0,
                0x1.3dea64c123422p+0,
                0x1.4bfdad5362a27p+0,
                0x1.5ab07dd485429p+0,
                0x1.8p23,
                0x1.62e430p-1,
                0x1.ebfbe0p-3,
                0x1.c6b348p-5,
                0x1.3b2c9cp-7,
                0x1.0p127,
                -0x1.0p-149,
            };

            const answers = [_]u64{
                0x3fe6a09e667f3bcd,
                0x3fe7a11473eb0187,
                0x3fe8ace5422aa0db,
                0x3fe9c49182a3f090,
                0x3feae89f995ad3ad,
                0x3fec199bdd85529c,
                0x3fed5818dcfba487,
                0x3feea4afa2a490da,
                0x3ff0000000000000,
                0x3ff0b5586cf9890f,
                0x3ff172b83c7d517b,
                0x3ff2387a6e756238,
                0x3ff306fe0a31b715,
                0x3ff3dea64c123422,
                0x3ff4bfdad5362a27,
                0x3ff5ab07dd485429,
                0x4168000000000000,
                0x3fe62e4300000000,
                0x3fcebfbe00000000,
                0x3fac6b3480000000,
                0x3f83b2c9c0000000,
                0x47e0000000000000,
                0xb6a0000000000000,
            };

            for (exp2ft) |x, i| {
                try expect(@bitCast(u64, x) == answers[i]);
            }
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "truncating shift left" {
    try testShlTrunc(maxInt(u16));
    comptime try testShlTrunc(maxInt(u16));
}
fn testShlTrunc(x: u16) !void {
    const shifted = x << 1;
    try expect(shifted == 65534);
}

test "exact shift left" {
    try testShlExact(0b00110101);
    comptime try testShlExact(0b00110101);
}
fn testShlExact(x: u8) !void {
    const shifted = @shlExact(x, 2);
    try expect(shifted == 0b11010100);
}

test "exact shift right" {
    try testShrExact(0b10110100);
    comptime try testShrExact(0b10110100);
}
fn testShrExact(x: u8) !void {
    const shifted = @shrExact(x, 2);
    try expect(shifted == 0b00101101);
}

test "shift left/right on u0 operand" {
    const S = struct {
        fn doTheTest() !void {
            var x: u0 = 0;
            var y: u0 = 0;
            try expectEqual(@as(u0, 0), x << 0);
            try expectEqual(@as(u0, 0), x >> 0);
            try expectEqual(@as(u0, 0), x << y);
            try expectEqual(@as(u0, 0), x >> y);
            try expectEqual(@as(u0, 0), @shlExact(x, 0));
            try expectEqual(@as(u0, 0), @shrExact(x, 0));
            try expectEqual(@as(u0, 0), @shlExact(x, y));
            try expectEqual(@as(u0, 0), @shrExact(x, y));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "comptime float rem int" {
    comptime {
        var x = @as(f32, 1) % 2;
        try expect(x == 1.0);
    }
}

test "remainder division" {
    comptime try remdiv(f16);
    comptime try remdiv(f32);
    comptime try remdiv(f64);
    comptime try remdiv(f128);
    try remdiv(f16);
    try remdiv(f64);
    try remdiv(f128);
}

fn remdiv(comptime T: type) !void {
    try expect(@as(T, 1) == @as(T, 1) % @as(T, 2));
    try expect(@as(T, 1) == @as(T, 7) % @as(T, 3));
}

test "@sqrt" {
    try testSqrt(f64, 12.0);
    comptime try testSqrt(f64, 12.0);
    try testSqrt(f32, 13.0);
    comptime try testSqrt(f32, 13.0);
    try testSqrt(f16, 13.0);
    comptime try testSqrt(f16, 13.0);

    const x = 14.0;
    const y = x * x;
    const z = @sqrt(y);
    comptime try expect(z == x);
}

fn testSqrt(comptime T: type, x: T) !void {
    try expect(@sqrt(x * x) == x);
}

test "@fabs" {
    try testFabs(f128, 12.0);
    comptime try testFabs(f128, 12.0);
    try testFabs(f64, 12.0);
    comptime try testFabs(f64, 12.0);
    try testFabs(f32, 12.0);
    comptime try testFabs(f32, 12.0);
    try testFabs(f16, 12.0);
    comptime try testFabs(f16, 12.0);

    const x = 14.0;
    const y = -x;
    const z = @fabs(y);
    comptime try expectEqual(x, z);
}

fn testFabs(comptime T: type, x: T) !void {
    const y = -x;
    const z = @fabs(y);
    try expectEqual(x, z);
}

test "@floor" {
    // FIXME: Generates a floorl function call
    // testFloor(f128, 12.0);
    comptime try testFloor(f128, 12.0);
    try testFloor(f64, 12.0);
    comptime try testFloor(f64, 12.0);
    try testFloor(f32, 12.0);
    comptime try testFloor(f32, 12.0);
    try testFloor(f16, 12.0);
    comptime try testFloor(f16, 12.0);

    const x = 14.0;
    const y = x + 0.7;
    const z = @floor(y);
    comptime try expectEqual(x, z);
}

fn testFloor(comptime T: type, x: T) !void {
    const y = x + 0.6;
    const z = @floor(y);
    try expectEqual(x, z);
}

test "@ceil" {
    // FIXME: Generates a ceill function call
    //testCeil(f128, 12.0);
    comptime try testCeil(f128, 12.0);
    try testCeil(f64, 12.0);
    comptime try testCeil(f64, 12.0);
    try testCeil(f32, 12.0);
    comptime try testCeil(f32, 12.0);
    try testCeil(f16, 12.0);
    comptime try testCeil(f16, 12.0);

    const x = 14.0;
    const y = x - 0.7;
    const z = @ceil(y);
    comptime try expectEqual(x, z);
}

fn testCeil(comptime T: type, x: T) !void {
    const y = x - 0.8;
    const z = @ceil(y);
    try expectEqual(x, z);
}

test "@trunc" {
    // FIXME: Generates a truncl function call
    //testTrunc(f128, 12.0);
    comptime try testTrunc(f128, 12.0);
    try testTrunc(f64, 12.0);
    comptime try testTrunc(f64, 12.0);
    try testTrunc(f32, 12.0);
    comptime try testTrunc(f32, 12.0);
    try testTrunc(f16, 12.0);
    comptime try testTrunc(f16, 12.0);

    const x = 14.0;
    const y = x + 0.7;
    const z = @trunc(y);
    comptime try expectEqual(x, z);
}

fn testTrunc(comptime T: type, x: T) !void {
    {
        const y = x + 0.8;
        const z = @trunc(y);
        try expectEqual(x, z);
    }

    {
        const y = -x - 0.8;
        const z = @trunc(y);
        try expectEqual(-x, z);
    }
}

test "@round" {
    // FIXME: Generates a roundl function call
    //testRound(f128, 12.0);
    comptime try testRound(f128, 12.0);
    try testRound(f64, 12.0);
    comptime try testRound(f64, 12.0);
    try testRound(f32, 12.0);
    comptime try testRound(f32, 12.0);
    try testRound(f16, 12.0);
    comptime try testRound(f16, 12.0);

    const x = 14.0;
    const y = x + 0.4;
    const z = @round(y);
    comptime try expectEqual(x, z);
}

fn testRound(comptime T: type, x: T) !void {
    const y = x - 0.5;
    const z = @round(y);
    try expectEqual(x, z);
}

test "vector integer addition" {
    const S = struct {
        fn doTheTest() !void {
            var a: std.meta.Vector(4, i32) = [_]i32{ 1, 2, 3, 4 };
            var b: std.meta.Vector(4, i32) = [_]i32{ 5, 6, 7, 8 };
            var result = a + b;
            var result_array: [4]i32 = result;
            const expected = [_]i32{ 6, 8, 10, 12 };
            try expectEqualSlices(i32, &expected, &result_array);
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "NaN comparison" {
    try testNanEqNan(f16);
    try testNanEqNan(f32);
    try testNanEqNan(f64);
    try testNanEqNan(f128);
    comptime try testNanEqNan(f16);
    comptime try testNanEqNan(f32);
    comptime try testNanEqNan(f64);
    comptime try testNanEqNan(f128);
}

fn testNanEqNan(comptime F: type) !void {
    var nan1 = std.math.nan(F);
    var nan2 = std.math.nan(F);
    try expect(nan1 != nan2);
    try expect(!(nan1 == nan2));
    try expect(!(nan1 > nan2));
    try expect(!(nan1 >= nan2));
    try expect(!(nan1 < nan2));
    try expect(!(nan1 <= nan2));
}

test "vector comparison" {
    const S = struct {
        fn doTheTest() !void {
            var a: std.meta.Vector(6, i32) = [_]i32{ 1, 3, -1, 5, 7, 9 };
            var b: std.meta.Vector(6, i32) = [_]i32{ -1, 3, 0, 6, 10, -10 };
            try expect(mem.eql(bool, &@as([6]bool, a < b), &[_]bool{ false, false, true, true, true, false }));
            try expect(mem.eql(bool, &@as([6]bool, a <= b), &[_]bool{ false, true, true, true, true, false }));
            try expect(mem.eql(bool, &@as([6]bool, a == b), &[_]bool{ false, true, false, false, false, false }));
            try expect(mem.eql(bool, &@as([6]bool, a != b), &[_]bool{ true, false, true, true, true, true }));
            try expect(mem.eql(bool, &@as([6]bool, a > b), &[_]bool{ true, false, false, false, false, true }));
            try expect(mem.eql(bool, &@as([6]bool, a >= b), &[_]bool{ true, true, false, false, false, true }));
        }
    };
    try S.doTheTest();
    comptime try S.doTheTest();
}

test "compare undefined literal with comptime_int" {
    var x = undefined == 1;
    // x is now undefined with type bool
    x = true;
    try expect(x);
}

test "signed zeros are represented properly" {
    const S = struct {
        fn doTheTest() !void {
            inline for ([_]type{ f16, f32, f64, f128 }) |T| {
                const ST = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);
                var as_fp_val = -@as(T, 0.0);
                var as_uint_val = @bitCast(ST, as_fp_val);
                // Ensure the sign bit is set.
                try expect(as_uint_val >> (@typeInfo(T).Float.bits - 1) == 1);
            }
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}
