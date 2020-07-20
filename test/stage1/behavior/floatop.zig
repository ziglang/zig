const std = @import("std");
const expect = std.testing.expect;
const math = std.math;
const pi = std.math.pi;
const e = std.math.e;
const Vector = std.meta.Vector;

const epsilon = 0.000001;

test "@sqrt" {
    comptime testSqrt();
    testSqrt();
}

fn testSqrt() void {
    {
        var a: f16 = 4;
        expect(@sqrt(a) == 2);
    }
    {
        var a: f32 = 9;
        expect(@sqrt(a) == 3);
        var b: f32 = 1.1;
        expect(math.approxEq(f32, @sqrt(b), 1.0488088481701516, epsilon));
    }
    {
        var a: f64 = 25;
        expect(@sqrt(a) == 5);
    }
    {
        const a: comptime_float = 25.0;
        expect(@sqrt(a) == 5.0);
    }
    // TODO https://github.com/ziglang/zig/issues/4026
    //{
    //    var a: f128 = 49;
    //    expect(@sqrt(a) == 7);
    //}
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
        var result = @sqrt(v);
        expect(math.approxEq(f32, @sqrt(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @sqrt(@as(f32, 2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @sqrt(@as(f32, 3.3)), result[2], epsilon));
        expect(math.approxEq(f32, @sqrt(@as(f32, 4.4)), result[3], epsilon));
    }
}

test "more @sqrt f16 tests" {
    // TODO these are not all passing at comptime
    expect(@sqrt(@as(f16, 0.0)) == 0.0);
    expect(math.approxEq(f16, @sqrt(@as(f16, 2.0)), 1.414214, epsilon));
    expect(math.approxEq(f16, @sqrt(@as(f16, 3.6)), 1.897367, epsilon));
    expect(@sqrt(@as(f16, 4.0)) == 2.0);
    expect(math.approxEq(f16, @sqrt(@as(f16, 7.539840)), 2.745877, epsilon));
    expect(math.approxEq(f16, @sqrt(@as(f16, 19.230934)), 4.385309, epsilon));
    expect(@sqrt(@as(f16, 64.0)) == 8.0);
    expect(math.approxEq(f16, @sqrt(@as(f16, 64.1)), 8.006248, epsilon));
    expect(math.approxEq(f16, @sqrt(@as(f16, 8942.230469)), 94.563370, epsilon));

    // special cases
    expect(math.isPositiveInf(@sqrt(@as(f16, math.inf(f16)))));
    expect(@sqrt(@as(f16, 0.0)) == 0.0);
    expect(@sqrt(@as(f16, -0.0)) == -0.0);
    expect(math.isNan(@sqrt(@as(f16, -1.0))));
    expect(math.isNan(@sqrt(@as(f16, math.nan(f16)))));
}

test "@sin" {
    comptime testSin();
    testSin();
}

fn testSin() void {
    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f16 = 0;
        expect(@sin(a) == 0);
    }
    {
        var a: f32 = 0;
        expect(@sin(a) == 0);
    }
    {
        var a: f64 = 0;
        expect(@sin(a) == 0);
    }
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
        var result = @sin(v);
        expect(math.approxEq(f32, @sin(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @sin(@as(f32, 2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @sin(@as(f32, 3.3)), result[2], epsilon));
        expect(math.approxEq(f32, @sin(@as(f32, 4.4)), result[3], epsilon));
    }
}

test "@cos" {
    comptime testCos();
    testCos();
}

fn testCos() void {
    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f16 = 0;
        expect(@cos(a) == 1);
    }
    {
        var a: f32 = 0;
        expect(@cos(a) == 1);
    }
    {
        var a: f64 = 0;
        expect(@cos(a) == 1);
    }
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, 2.2, 3.3, 4.4 };
        var result = @cos(v);
        expect(math.approxEq(f32, @cos(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @cos(@as(f32, 2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @cos(@as(f32, 3.3)), result[2], epsilon));
        expect(math.approxEq(f32, @cos(@as(f32, 4.4)), result[3], epsilon));
    }
}

test "@exp" {
    comptime testExp();
    testExp();
}

fn testExp() void {
    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f16 = 0;
        expect(@exp(a) == 1);
    }
    {
        var a: f32 = 0;
        expect(@exp(a) == 1);
    }
    {
        var a: f64 = 0;
        expect(@exp(a) == 1);
    }
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        var result = @exp(v);
        expect(math.approxEq(f32, @exp(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @exp(@as(f32, 2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @exp(@as(f32, 0.3)), result[2], epsilon));
        expect(math.approxEq(f32, @exp(@as(f32, 0.4)), result[3], epsilon));
    }
}

test "@exp2" {
    comptime testExp2();
    testExp2();
}

fn testExp2() void {
    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f16 = 2;
        expect(@exp2(a) == 4);
    }
    {
        var a: f32 = 2;
        expect(@exp2(a) == 4);
    }
    {
        var a: f64 = 2;
        expect(@exp2(a) == 4);
    }
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        var result = @exp2(v);
        expect(math.approxEq(f32, @exp2(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @exp2(@as(f32, 2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @exp2(@as(f32, 0.3)), result[2], epsilon));
        expect(math.approxEq(f32, @exp2(@as(f32, 0.4)), result[3], epsilon));
    }
}

test "@log" {
    // Old musl (and glibc?), and our current math.ln implementation do not return 1
    // so also accept those values.
    comptime testLog();
    testLog();
}

fn testLog() void {
    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f16 = e;
        expect(math.approxEq(f16, @log(a), 1, epsilon));
    }
    {
        var a: f32 = e;
        expect(@log(a) == 1 or @log(a) == @bitCast(f32, @as(u32, 0x3f7fffff)));
    }
    {
        var a: f64 = e;
        expect(@log(a) == 1 or @log(a) == @bitCast(f64, @as(u64, 0x3ff0000000000000)));
    }
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        var result = @log(v);
        expect(math.approxEq(f32, @log(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @log(@as(f32, 2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @log(@as(f32, 0.3)), result[2], epsilon));
        expect(math.approxEq(f32, @log(@as(f32, 0.4)), result[3], epsilon));
    }
}

test "@log2" {
    comptime testLog2();
    testLog2();
}

fn testLog2() void {
    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f16 = 4;
        expect(@log2(a) == 2);
    }
    {
        var a: f32 = 4;
        expect(@log2(a) == 2);
    }
    {
        var a: f64 = 4;
        expect(@log2(a) == 2);
    }
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        var result = @log2(v);
        expect(math.approxEq(f32, @log2(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @log2(@as(f32, 2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @log2(@as(f32, 0.3)), result[2], epsilon));
        expect(math.approxEq(f32, @log2(@as(f32, 0.4)), result[3], epsilon));
    }
}

test "@log10" {
    comptime testLog10();
    testLog10();
}

fn testLog10() void {
    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f16 = 100;
        expect(@log10(a) == 2);
    }
    {
        var a: f32 = 100;
        expect(@log10(a) == 2);
    }
    {
        var a: f64 = 1000;
        expect(@log10(a) == 3);
    }
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, 2.2, 0.3, 0.4 };
        var result = @log10(v);
        expect(math.approxEq(f32, @log10(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @log10(@as(f32, 2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @log10(@as(f32, 0.3)), result[2], epsilon));
        expect(math.approxEq(f32, @log10(@as(f32, 0.4)), result[3], epsilon));
    }
}

test "@fabs" {
    comptime testFabs();
    testFabs();
}

fn testFabs() void {
    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f16 = -2.5;
        var b: f16 = 2.5;
        expect(@fabs(a) == 2.5);
        expect(@fabs(b) == 2.5);
    }
    {
        var a: f32 = -2.5;
        var b: f32 = 2.5;
        expect(@fabs(a) == 2.5);
        expect(@fabs(b) == 2.5);
    }
    {
        var a: f64 = -2.5;
        var b: f64 = 2.5;
        expect(@fabs(a) == 2.5);
        expect(@fabs(b) == 2.5);
    }
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
        var result = @fabs(v);
        expect(math.approxEq(f32, @fabs(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @fabs(@as(f32, -2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @fabs(@as(f32, 0.3)), result[2], epsilon));
        expect(math.approxEq(f32, @fabs(@as(f32, -0.4)), result[3], epsilon));
    }
}

test "@floor" {
    comptime testFloor();
    testFloor();
}

fn testFloor() void {
    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f16 = 2.1;
        expect(@floor(a) == 2);
    }
    {
        var a: f32 = 2.1;
        expect(@floor(a) == 2);
    }
    {
        var a: f64 = 3.5;
        expect(@floor(a) == 3);
    }
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
        var result = @floor(v);
        expect(math.approxEq(f32, @floor(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @floor(@as(f32, -2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @floor(@as(f32, 0.3)), result[2], epsilon));
        expect(math.approxEq(f32, @floor(@as(f32, -0.4)), result[3], epsilon));
    }
}

test "@ceil" {
    comptime testCeil();
    testCeil();
}

fn testCeil() void {
    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f16 = 2.1;
        expect(@ceil(a) == 3);
    }
    {
        var a: f32 = 2.1;
        expect(@ceil(a) == 3);
    }
    {
        var a: f64 = 3.5;
        expect(@ceil(a) == 4);
    }
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
        var result = @ceil(v);
        expect(math.approxEq(f32, @ceil(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @ceil(@as(f32, -2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @ceil(@as(f32, 0.3)), result[2], epsilon));
        expect(math.approxEq(f32, @ceil(@as(f32, -0.4)), result[3], epsilon));
    }
}

test "@trunc" {
    comptime testTrunc();
    testTrunc();
}

fn testTrunc() void {
    // TODO test f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f16 = 2.1;
        expect(@trunc(a) == 2);
    }
    {
        var a: f32 = 2.1;
        expect(@trunc(a) == 2);
    }
    {
        var a: f64 = -3.5;
        expect(@trunc(a) == -3);
    }
    {
        var v: Vector(4, f32) = [_]f32{ 1.1, -2.2, 0.3, -0.4 };
        var result = @trunc(v);
        expect(math.approxEq(f32, @trunc(@as(f32, 1.1)), result[0], epsilon));
        expect(math.approxEq(f32, @trunc(@as(f32, -2.2)), result[1], epsilon));
        expect(math.approxEq(f32, @trunc(@as(f32, 0.3)), result[2], epsilon));
        expect(math.approxEq(f32, @trunc(@as(f32, -0.4)), result[3], epsilon));
    }
}

test "floating point comparisons" {
    testFloatComparisons();
    comptime testFloatComparisons();
}

fn testFloatComparisons() void {
    inline for ([_]type{ f16, f32, f64, f128 }) |ty| {
        // No decimal part
        {
            const x: ty = 1.0;
            expect(x == 1);
            expect(x != 0);
            expect(x > 0);
            expect(x < 2);
            expect(x >= 1);
            expect(x <= 1);
        }
        // Non-zero decimal part
        {
            const x: ty = 1.5;
            expect(x != 1);
            expect(x != 2);
            expect(x > 1);
            expect(x < 2);
            expect(x >= 1);
            expect(x <= 2);
        }
    }
}

test "different sized float comparisons" {
    testDifferentSizedFloatComparisons();
    comptime testDifferentSizedFloatComparisons();
}

fn testDifferentSizedFloatComparisons() void {
    var a: f16 = 1;
    var b: f64 = 2;
    expect(a < b);
}

// TODO This is waiting on library support for the Windows build (not sure why the other's don't need it)
//test "@nearbyint" {
//    comptime testNearbyInt();
//    testNearbyInt();
//}

//fn testNearbyInt() void {
//    // TODO test f16, f128, and c_longdouble
//    // https://github.com/ziglang/zig/issues/4026
//    {
//        var a: f32 = 2.1;
//        expect(@nearbyint(a) == 2);
//    }
//    {
//        var a: f64 = -3.75;
//        expect(@nearbyint(a) == -4);
//    }
//}
