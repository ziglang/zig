const std = @import("std");
const expect = std.testing.expect;
const math = std.math;
const pi = std.math.pi;
const e = std.math.e;
const Vector = std.meta.Vector;

const epsilon = 0.000001;

test "floating point comparisons" {
    try testFloatComparisons();
    comptime try testFloatComparisons();
}

fn testFloatComparisons() !void {
    inline for ([_]type{ f16, f32, f64, f128 }) |ty| {
        // No decimal part
        {
            const x: ty = 1.0;
            try expect(x == 1);
            try expect(x != 0);
            try expect(x > 0);
            try expect(x < 2);
            try expect(x >= 1);
            try expect(x <= 1);
        }
        // Non-zero decimal part
        {
            const x: ty = 1.5;
            try expect(x != 1);
            try expect(x != 2);
            try expect(x > 1);
            try expect(x < 2);
            try expect(x >= 1);
            try expect(x <= 2);
        }
    }
}

test "different sized float comparisons" {
    try testDifferentSizedFloatComparisons();
    comptime try testDifferentSizedFloatComparisons();
}

fn testDifferentSizedFloatComparisons() !void {
    var a: f16 = 1;
    var b: f64 = 2;
    try expect(a < b);
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
//    try expect(@nearbyint(a) == 2);
//    }
//    {
//        var a: f64 = -3.75;
//    try expect(@nearbyint(a) == -4);
//    }
//}

test "negative f128 floatToInt at compile-time" {
    const a: f128 = -2;
    var b = @floatToInt(i64, a);
    try expect(@as(i64, -2) == b);
}

test "@sqrt" {
    comptime try testSqrt();
    try testSqrt();
}

fn testSqrt() !void {
    {
        var a: f16 = 4;
        try expect(@sqrt(a) == 2);
    }
    {
        var a: f32 = 9;
        try expect(@sqrt(a) == 3);
        var b: f32 = 1.1;
        try expect(math.approxEqAbs(f32, @sqrt(b), 1.0488088481701516, epsilon));
    }
    {
        var a: f64 = 25;
        try expect(@sqrt(a) == 5);
    }
}

test "more @sqrt f16 tests" {
    // TODO these are not all passing at comptime
    try expect(@sqrt(@as(f16, 0.0)) == 0.0);
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 2.0)), 1.414214, epsilon));
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 3.6)), 1.897367, epsilon));
    try expect(@sqrt(@as(f16, 4.0)) == 2.0);
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 7.539840)), 2.745877, epsilon));
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 19.230934)), 4.385309, epsilon));
    try expect(@sqrt(@as(f16, 64.0)) == 8.0);
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 64.1)), 8.006248, epsilon));
    try expect(math.approxEqAbs(f16, @sqrt(@as(f16, 8942.230469)), 94.563370, epsilon));

    // special cases
    try expect(math.isPositiveInf(@sqrt(@as(f16, math.inf(f16)))));
    try expect(@sqrt(@as(f16, 0.0)) == 0.0);
    try expect(@sqrt(@as(f16, -0.0)) == -0.0);
    try expect(math.isNan(@sqrt(@as(f16, -1.0))));
    try expect(math.isNan(@sqrt(@as(f16, math.nan(f16)))));
}
