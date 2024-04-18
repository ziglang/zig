const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;

pub fn Modf(comptime T: type) type {
    return struct {
        fpart: T,
        ipart: T,
    };
}

/// Returns the integer and fractional floating-point numbers that sum to x. The sign of each
/// result is the same as the sign of x.
/// In comptime, may be used with comptime_float
///
/// Special Cases:
///  - modf(+-inf) = +-inf, nan
///  - modf(nan)   = nan, nan
pub fn modf(x: anytype) Modf(@TypeOf(x)) {
    const ipart = @trunc(x);
    return .{
        .ipart = ipart,
        .fpart = x - ipart,
    };
}

test modf {
    inline for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        const epsilon: comptime_float = @max(1e-6, math.floatEps(T));

        var r: Modf(T) = undefined;

        r = modf(@as(T, 1.0));
        try expectEqual(1.0, r.ipart);
        try expectEqual(0.0, r.fpart);

        r = modf(@as(T, 0.34682));
        try expectEqual(0.0, r.ipart);
        try expectApproxEqAbs(@as(T, 0.34682), r.fpart, epsilon);

        r = modf(@as(T, 2.54576));
        try expectEqual(2.0, r.ipart);
        try expectApproxEqAbs(0.54576, r.fpart, epsilon);

        r = modf(@as(T, 3.9782));
        try expectEqual(3.0, r.ipart);
        try expectApproxEqAbs(0.9782, r.fpart, epsilon);
    }
}

/// Generate a namespace of tests for modf on values of the given type
fn ModfTests(comptime T: type) type {
    return struct {
        test "normal" {
            const epsilon: comptime_float = @max(1e-6, math.floatEps(T));
            var r: Modf(T) = undefined;

            r = modf(@as(T, 1.0));
            try expectEqual(1.0, r.ipart);
            try expectEqual(0.0, r.fpart);

            r = modf(@as(T, 0.34682));
            try expectEqual(0.0, r.ipart);
            try expectApproxEqAbs(0.34682, r.fpart, epsilon);

            r = modf(@as(T, 3.97812));
            try expectEqual(3.0, r.ipart);
            // account for precision error
            const expected_a: T = 3.97812 - @as(T, 3);
            try expectApproxEqAbs(expected_a, r.fpart, epsilon);

            r = modf(@as(T, 43874.3));
            try expectEqual(43874.0, r.ipart);
            // account for precision error
            const expected_b: T = 43874.3 - @as(T, 43874);
            try expectApproxEqAbs(expected_b, r.fpart, epsilon);

            r = modf(@as(T, 1234.340780));
            try expectEqual(1234.0, r.ipart);
            // account for precision error
            const expected_c: T = 1234.340780 - @as(T, 1234);
            try expectApproxEqAbs(expected_c, r.fpart, epsilon);
        }
        test "vector" {
            // Currently, a compiler bug is breaking the usage
            // of @trunc on @Vector types

            // TODO: Repopulate the below array and
            // remove the skip statement once this
            // bug is fixed

            // const widths = [_]comptime_int{ 1, 2, 3, 4, 8, 16 };
            const widths = [_]comptime_int{};

            if (widths.len == 0)
                return error.SkipZigTest;

            inline for (widths) |len| {
                const V: type = @Vector(len, T);
                var r: Modf(V) = undefined;

                r = modf(@as(V, @splat(1.0)));
                try expectEqual(@as(V, @splat(1.0)), r.ipart);
                try expectEqual(@as(V, @splat(0.0)), r.fpart);

                r = modf(@as(V, @splat(2.75)));
                try expectEqual(@as(V, @splat(2.0)), r.ipart);
                try expectEqual(@as(V, @splat(0.75)), r.fpart);

                r = modf(@as(V, @splat(0.2)));
                try expectEqual(@as(V, @splat(0.0)), r.ipart);
                try expectEqual(@as(V, @splat(0.2)), r.fpart);

                r = modf(std.simd.iota(T, len) + @as(V, @splat(0.5)));
                try expectEqual(std.simd.iota(T, len), r.ipart);
                try expectEqual(@as(V, @splat(0.5)), r.fpart);
            }
        }
        test "inf" {
            var r: Modf(T) = undefined;

            r = modf(math.inf(T));
            try expect(math.isPositiveInf(r.ipart) and math.isNan(r.fpart));

            r = modf(-math.inf(T));
            try expect(math.isNegativeInf(r.ipart) and math.isNan(r.fpart));
        }
        test "nan" {
            const r: Modf(T) = modf(math.nan(T));
            try expect(math.isNan(r.ipart) and math.isNan(r.fpart));
        }
    };
}

comptime {
    for ([_]type{ f16, f32, f64, f80, f128 }) |T| {
        _ = ModfTests(T);
    }
}
