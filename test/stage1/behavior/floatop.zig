const std = @import("std");
const expect = std.testing.expect;
const math = std.math;
const pi = std.math.pi;
const e = std.math.e;

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
}

test "more @sqrt f16 tests" {
    // TODO these are not all passing at comptime
    const epsilon = 0.000001;

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
    // TODO test f16, f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f32 = 0;
        expect(@sin(a) == 0);
    }
    {
        var a: f64 = 0;
        expect(@sin(a) == 0);
    }
}

test "@cos" {
    comptime testCos();
    testCos();
}

fn testCos() void {
    // TODO test f16, f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f32 = 0;
        expect(@cos(a) == 1);
    }
    {
        var a: f64 = 0;
        expect(@cos(a) == 1);
    }
}

test "@exp" {
    comptime testExp();
    testExp();
}

fn testExp() void {
    // TODO test f16, f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f32 = 0;
        expect(@exp(a) == 1);
    }
    {
        var a: f64 = 0;
        expect(@exp(a) == 1);
    }
}

test "@exp2" {
    comptime testExp2();
    testExp2();
}

fn testExp2() void {
    // TODO test f16, f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f32 = 2;
        expect(@exp2(a) == 4);
    }
    {
        var a: f64 = 2;
        expect(@exp2(a) == 4);
    }
}

test "@ln" {
    // Old musl (and glibc?), and our current math.ln implementation do not return 1
    // so also accept those values.
    comptime testLn();
    testLn();
}

fn testLn() void {
    // TODO test f16, f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f32 = e;
        expect(@ln(a) == 1 or @ln(a) == @bitCast(f32, @as(u32, 0x3f7fffff)));
    }
    {
        var a: f64 = e;
        expect(@ln(a) == 1 or @ln(a) == @bitCast(f64, @as(u64, 0x3ff0000000000000)));
    }
}

test "@log2" {
    comptime testLog2();
    testLog2();
}

fn testLog2() void {
    // TODO test f16, f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f32 = 4;
        expect(@log2(a) == 2);
    }
    {
        var a: f64 = 4;
        expect(@log2(a) == 2);
    }
}

test "@log10" {
    comptime testLog10();
    testLog10();
}

fn testLog10() void {
    // TODO test f16, f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f32 = 100;
        expect(@log10(a) == 2);
    }
    {
        var a: f64 = 1000;
        expect(@log10(a) == 3);
    }
}

test "@fabs" {
    comptime testFabs();
    testFabs();
}

fn testFabs() void {
    // TODO test f16, f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
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
}

test "@floor" {
    comptime testFloor();
    testFloor();
}

fn testFloor() void {
    // TODO test f16, f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f32 = 2.1;
        expect(@floor(a) == 2);
    }
    {
        var a: f64 = 3.5;
        expect(@floor(a) == 3);
    }
}

test "@ceil" {
    comptime testCeil();
    testCeil();
}

fn testCeil() void {
    // TODO test f16, f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f32 = 2.1;
        expect(@ceil(a) == 3);
    }
    {
        var a: f64 = 3.5;
        expect(@ceil(a) == 4);
    }
}

test "@trunc" {
    comptime testTrunc();
    testTrunc();
}

fn testTrunc() void {
    // TODO test f16, f128, and c_longdouble
    // https://github.com/ziglang/zig/issues/4026
    {
        var a: f32 = 2.1;
        expect(@trunc(a) == 2);
    }
    {
        var a: f64 = -3.5;
        expect(@trunc(a) == -3);
    }
}

// TODO This is waiting on library support for the Windows build (not sure why the other's don't need it)
//test "@nearbyInt" {
//    comptime testNearbyInt();
//    testNearbyInt();
//}

//fn testNearbyInt() void {
//    // TODO test f16, f128, and c_longdouble
//    // https://github.com/ziglang/zig/issues/4026
//    {
//        var a: f32 = 2.1;
//        expect(@nearbyInt(a) == 2);
//    }
//    {
//        var a: f64 = -3.75;
//        expect(@nearbyInt(a) == -4);
//    }
//}
