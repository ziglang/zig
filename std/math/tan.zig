// Special Cases:
//
// - tan(+-0)   = +-0
// - tan(+-inf) = nan
// - tan(nan)   = nan

const builtin = @import("builtin");
const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;

pub fn tan(x: var) @typeOf(x) {
    const T = @typeOf(x);
    return switch (T) {
        f32 => tan32(x),
        f64 => tan64(x),
        else => @compileError("tan not implemented for " ++ @typeName(T)),
    };
}

const Tp0 = -1.30936939181383777646E4;
const Tp1 = 1.15351664838587416140E6;
const Tp2 = -1.79565251976484877988E7;

const Tq1 = 1.36812963470692954678E4;
const Tq2 = -1.32089234440210967447E6;
const Tq3 = 2.50083801823357915839E7;
const Tq4 = -5.38695755929454629881E7;

// NOTE: This is taken from the go stdlib. The musl implementation is much more complex.
//
// This may have slight differences on some edge cases and may need to replaced if so.
fn tan32(x_: f32) f32 {
    @setFloatMode(this, @import("builtin").FloatMode.Strict);

    const pi4a = 7.85398125648498535156e-1;
    const pi4b = 3.77489470793079817668E-8;
    const pi4c = 2.69515142907905952645E-15;
    const m4pi = 1.273239544735162542821171882678754627704620361328125;

    var x = x_;
    if (x == 0 or math.isNan(x)) {
        return x;
    }
    if (math.isInf(x)) {
        return math.nan(f32);
    }

    var sign = false;
    if (x < 0) {
        x = -x;
        sign = true;
    }

    var y = math.floor(x * m4pi);
    var j = @floatToInt(i64, y);

    if (j & 1 == 1) {
        j += 1;
        y += 1;
    }

    const z = ((x - y * pi4a) - y * pi4b) - y * pi4c;
    const w = z * z;

    var r = r: {
        if (w > 1e-14) {
            break :r z + z * (w * ((Tp0 * w + Tp1) * w + Tp2) / ((((w + Tq1) * w + Tq2) * w + Tq3) * w + Tq4));
        } else {
            break :r z;
        }
    };

    if (j & 2 == 2) {
        r = -1 / r;
    }
    if (sign) {
        r = -r;
    }

    return r;
}

fn tan64(x_: f64) f64 {
    const pi4a = 7.85398125648498535156e-1;
    const pi4b = 3.77489470793079817668E-8;
    const pi4c = 2.69515142907905952645E-15;
    const m4pi = 1.273239544735162542821171882678754627704620361328125;

    var x = x_;
    if (x == 0 or math.isNan(x)) {
        return x;
    }
    if (math.isInf(x)) {
        return math.nan(f64);
    }

    var sign = false;
    if (x < 0) {
        x = -x;
        sign = true;
    }

    var y = math.floor(x * m4pi);
    var j = @floatToInt(i64, y);

    if (j & 1 == 1) {
        j += 1;
        y += 1;
    }

    const z = ((x - y * pi4a) - y * pi4b) - y * pi4c;
    const w = z * z;

    var r = r: {
        if (w > 1e-14) {
            break :r z + z * (w * ((Tp0 * w + Tp1) * w + Tp2) / ((((w + Tq1) * w + Tq2) * w + Tq3) * w + Tq4));
        } else {
            break :r z;
        }
    };

    if (j & 2 == 2) {
        r = -1 / r;
    }
    if (sign) {
        r = -r;
    }

    return r;
}

test "math.tan" {
    assert(tan(f32(0.0)) == tan32(0.0));
    assert(tan(f64(0.0)) == tan64(0.0));
}

test "math.tan32" {
    const epsilon = 0.000001;

    assert(math.approxEq(f32, tan32(0.0), 0.0, epsilon));
    assert(math.approxEq(f32, tan32(0.2), 0.202710, epsilon));
    assert(math.approxEq(f32, tan32(0.8923), 1.240422, epsilon));
    assert(math.approxEq(f32, tan32(1.5), 14.101420, epsilon));
    assert(math.approxEq(f32, tan32(37.45), -0.254397, epsilon));
    assert(math.approxEq(f32, tan32(89.123), 2.285852, epsilon));
}

test "math.tan64" {
    const epsilon = 0.000001;

    assert(math.approxEq(f64, tan64(0.0), 0.0, epsilon));
    assert(math.approxEq(f64, tan64(0.2), 0.202710, epsilon));
    assert(math.approxEq(f64, tan64(0.8923), 1.240422, epsilon));
    assert(math.approxEq(f64, tan64(1.5), 14.101420, epsilon));
    assert(math.approxEq(f64, tan64(37.45), -0.254397, epsilon));
    assert(math.approxEq(f64, tan64(89.123), 2.2858376, epsilon));
}

test "math.tan32.special" {
    assert(tan32(0.0) == 0.0);
    assert(tan32(-0.0) == -0.0);
    assert(math.isNan(tan32(math.inf(f32))));
    assert(math.isNan(tan32(-math.inf(f32))));
    assert(math.isNan(tan32(math.nan(f32))));
}

test "math.tan64.special" {
    assert(tan64(0.0) == 0.0);
    assert(tan64(-0.0) == -0.0);
    assert(math.isNan(tan64(math.inf(f64))));
    assert(math.isNan(tan64(-math.inf(f64))));
    assert(math.isNan(tan64(math.nan(f64))));
}
