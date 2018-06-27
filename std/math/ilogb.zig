// Special Cases:
//
// - ilogb(+-inf) = @maxValue(i32)
// - ilogb(0)     = @maxValue(i32)
// - ilogb(nan)   = @maxValue(i32)

const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;

pub fn ilogb(x: var) i32 {
    const T = @typeOf(x);
    return switch (T) {
        f32 => ilogb32(x),
        f64 => ilogb64(x),
        else => @compileError("ilogb not implemented for " ++ @typeName(T)),
    };
}

// NOTE: Should these be exposed publically?
const fp_ilogbnan = -1 - i32(@maxValue(u32) >> 1);
const fp_ilogb0 = fp_ilogbnan;

fn ilogb32(x: f32) i32 {
    var u = @bitCast(u32, x);
    var e = @intCast(i32, (u >> 23) & 0xFF);

    // TODO: We should be able to merge this with the lower check.
    if (math.isNan(x)) {
        return @maxValue(i32);
    }

    if (e == 0) {
        u <<= 9;
        if (u == 0) {
            math.raiseInvalid();
            return fp_ilogb0;
        }

        // subnormal
        e = -0x7F;
        while (u >> 31 == 0) : (u <<= 1) {
            e -= 1;
        }
        return e;
    }

    if (e == 0xFF) {
        math.raiseInvalid();
        if (u << 9 != 0) {
            return fp_ilogbnan;
        } else {
            return @maxValue(i32);
        }
    }

    return e - 0x7F;
}

fn ilogb64(x: f64) i32 {
    var u = @bitCast(u64, x);
    var e = @intCast(i32, (u >> 52) & 0x7FF);

    if (math.isNan(x)) {
        return @maxValue(i32);
    }

    if (e == 0) {
        u <<= 12;
        if (u == 0) {
            math.raiseInvalid();
            return fp_ilogb0;
        }

        // subnormal
        e = -0x3FF;
        while (u >> 63 == 0) : (u <<= 1) {
            e -= 1;
        }
        return e;
    }

    if (e == 0x7FF) {
        math.raiseInvalid();
        if (u << 12 != 0) {
            return fp_ilogbnan;
        } else {
            return @maxValue(i32);
        }
    }

    return e - 0x3FF;
}

test "math.ilogb" {
    assert(ilogb(f32(0.2)) == ilogb32(0.2));
    assert(ilogb(f64(0.2)) == ilogb64(0.2));
}

test "math.ilogb32" {
    assert(ilogb32(0.0) == fp_ilogb0);
    assert(ilogb32(0.5) == -1);
    assert(ilogb32(0.8923) == -1);
    assert(ilogb32(10.0) == 3);
    assert(ilogb32(-123984) == 16);
    assert(ilogb32(2398.23) == 11);
}

test "math.ilogb64" {
    assert(ilogb64(0.0) == fp_ilogb0);
    assert(ilogb64(0.5) == -1);
    assert(ilogb64(0.8923) == -1);
    assert(ilogb64(10.0) == 3);
    assert(ilogb64(-123984) == 16);
    assert(ilogb64(2398.23) == 11);
}

test "math.ilogb32.special" {
    assert(ilogb32(math.inf(f32)) == @maxValue(i32));
    assert(ilogb32(-math.inf(f32)) == @maxValue(i32));
    assert(ilogb32(0.0) == @minValue(i32));
    assert(ilogb32(math.nan(f32)) == @maxValue(i32));
}

test "math.ilogb64.special" {
    assert(ilogb64(math.inf(f64)) == @maxValue(i32));
    assert(ilogb64(-math.inf(f64)) == @maxValue(i32));
    assert(ilogb64(0.0) == @minValue(i32));
    assert(ilogb64(math.nan(f64)) == @maxValue(i32));
}
