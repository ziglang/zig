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
