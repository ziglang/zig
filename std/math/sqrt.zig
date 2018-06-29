// Special Cases:
//
// - sqrt(+inf)  = +inf
// - sqrt(+-0)   = +-0
// - sqrt(x)     = nan if x < 0
// - sqrt(nan)   = nan

const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;
const builtin = @import("builtin");
const TypeId = builtin.TypeId;

pub fn sqrt(x: var) (if (@typeId(@typeOf(x)) == TypeId.Int) @IntType(false, @typeOf(x).bit_count / 2) else @typeOf(x)) {
    const T = @typeOf(x);
    switch (@typeId(T)) {
        TypeId.ComptimeFloat => return T(@sqrt(f64, x)), // TODO upgrade to f128
        TypeId.Float => return @sqrt(T, x),
        TypeId.ComptimeInt => comptime {
            if (x > @maxValue(u128)) {
                @compileError("sqrt not implemented for comptime_int greater than 128 bits");
            }
            if (x < 0) {
                @compileError("sqrt on negative number");
            }
            return T(sqrt_int(u128, x));
        },
        TypeId.Int => return sqrt_int(T, x),
        else => @compileError("sqrt not implemented for " ++ @typeName(T)),
    }
}

test "math.sqrt" {
    assert(sqrt(f16(0.0)) == @sqrt(f16, 0.0));
    assert(sqrt(f32(0.0)) == @sqrt(f32, 0.0));
    assert(sqrt(f64(0.0)) == @sqrt(f64, 0.0));
}

test "math.sqrt16" {
    const epsilon = 0.000001;

    assert(@sqrt(f16, 0.0) == 0.0);
    assert(math.approxEq(f16, @sqrt(f16, 2.0), 1.414214, epsilon));
    assert(math.approxEq(f16, @sqrt(f16, 3.6), 1.897367, epsilon));
    assert(@sqrt(f16, 4.0) == 2.0);
    assert(math.approxEq(f16, @sqrt(f16, 7.539840), 2.745877, epsilon));
    assert(math.approxEq(f16, @sqrt(f16, 19.230934), 4.385309, epsilon));
    assert(@sqrt(f16, 64.0) == 8.0);
    assert(math.approxEq(f16, @sqrt(f16, 64.1), 8.006248, epsilon));
    assert(math.approxEq(f16, @sqrt(f16, 8942.230469), 94.563370, epsilon));
}

test "math.sqrt32" {
    const epsilon = 0.000001;

    assert(@sqrt(f32, 0.0) == 0.0);
    assert(math.approxEq(f32, @sqrt(f32, 2.0), 1.414214, epsilon));
    assert(math.approxEq(f32, @sqrt(f32, 3.6), 1.897367, epsilon));
    assert(@sqrt(f32, 4.0) == 2.0);
    assert(math.approxEq(f32, @sqrt(f32, 7.539840), 2.745877, epsilon));
    assert(math.approxEq(f32, @sqrt(f32, 19.230934), 4.385309, epsilon));
    assert(@sqrt(f32, 64.0) == 8.0);
    assert(math.approxEq(f32, @sqrt(f32, 64.1), 8.006248, epsilon));
    assert(math.approxEq(f32, @sqrt(f32, 8942.230469), 94.563370, epsilon));
}

test "math.sqrt64" {
    const epsilon = 0.000001;

    assert(@sqrt(f64, 0.0) == 0.0);
    assert(math.approxEq(f64, @sqrt(f64, 2.0), 1.414214, epsilon));
    assert(math.approxEq(f64, @sqrt(f64, 3.6), 1.897367, epsilon));
    assert(@sqrt(f64, 4.0) == 2.0);
    assert(math.approxEq(f64, @sqrt(f64, 7.539840), 2.745877, epsilon));
    assert(math.approxEq(f64, @sqrt(f64, 19.230934), 4.385309, epsilon));
    assert(@sqrt(f64, 64.0) == 8.0);
    assert(math.approxEq(f64, @sqrt(f64, 64.1), 8.006248, epsilon));
    assert(math.approxEq(f64, @sqrt(f64, 8942.230469), 94.563367, epsilon));
}

test "math.sqrt16.special" {
    assert(math.isPositiveInf(@sqrt(f16, math.inf(f16))));
    assert(@sqrt(f16, 0.0) == 0.0);
    assert(@sqrt(f16, -0.0) == -0.0);
    assert(math.isNan(@sqrt(f16, -1.0)));
    assert(math.isNan(@sqrt(f16, math.nan(f16))));
}

test "math.sqrt32.special" {
    assert(math.isPositiveInf(@sqrt(f32, math.inf(f32))));
    assert(@sqrt(f32, 0.0) == 0.0);
    assert(@sqrt(f32, -0.0) == -0.0);
    assert(math.isNan(@sqrt(f32, -1.0)));
    assert(math.isNan(@sqrt(f32, math.nan(f32))));
}

test "math.sqrt64.special" {
    assert(math.isPositiveInf(@sqrt(f64, math.inf(f64))));
    assert(@sqrt(f64, 0.0) == 0.0);
    assert(@sqrt(f64, -0.0) == -0.0);
    assert(math.isNan(@sqrt(f64, -1.0)));
    assert(math.isNan(@sqrt(f64, math.nan(f64))));
}

fn sqrt_int(comptime T: type, value: T) @IntType(false, T.bit_count / 2) {
    var op = value;
    var res: T = 0;
    var one: T = 1 << (T.bit_count - 2);

    // "one" starts at the highest power of four <= than the argument.
    while (one > op) {
        one >>= 2;
    }

    while (one != 0) {
        if (op >= res + one) {
            op -= res + one;
            res += 2 * one;
        }
        res >>= 1;
        one >>= 2;
    }

    const ResultType = @IntType(false, T.bit_count / 2);
    return @intCast(ResultType, res);
}

test "math.sqrt_int" {
    assert(sqrt_int(u32, 3) == 1);
    assert(sqrt_int(u32, 4) == 2);
    assert(sqrt_int(u32, 5) == 2);
    assert(sqrt_int(u32, 8) == 2);
    assert(sqrt_int(u32, 9) == 3);
    assert(sqrt_int(u32, 10) == 3);
}
