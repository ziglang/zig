const math = @import("index.zig");
const assert = @import("../debug.zig").assert;

pub fn fmod(comptime T: type, x: T, y: T) -> T {
    switch (T) {
        f32 => @inlineCall(fmod32, x, y),
        f64 => @inlineCall(fmod64, x, y),
        else => @compileError("fmod not implemented for " ++ @typeName(T)),
    }
}

fn fmod32(x: f32, y: f32) -> f32 {
    var ux = @bitCast(u32, x);
    var uy = @bitCast(u32, y);
    var ex = i32(ux >> 23) & 0xFF;
    var ey = i32(ux >> 23) & 0xFF;
    const sx = ux & 0x80000000;

    if (uy << 1 == 0 or math.isNan(y) or ex == 0xFF) {
        return (x * y) / (x * y);
    }
    if (ux << 1 <= uy << 1) {
        if (ux << 1 == uy << 1) {
            return 0 * x;
        } else {
            return x;
        }
    }

    // normalize x and y
    if (ex == 0) {
        var i = ux << 9;
        while (i >> 31 == 0) : (i <<= 1) {
            ex -= 1;
        }
        ux <<= u32(-ex + 1);
    } else {
        ux &= @maxValue(u32) >> 9;
        ux |= 1 << 23;
    }

    if (ey == 0) {
        var i = uy << 9;
        while (i >> 31 == 0) : (i <<= 1) {
            ey -= 1;
        }
        uy <<= u32(-ey + 1);
    } else {
        uy &= @maxValue(u32) >> 9;
        uy |= 1 << 23;
    }

    // x mod y
    while (ex > ey) : (ex -= 1) {
        const i = ux - uy;
        if (i >> 31 == 0) {
            if (i == 0) {
                return 0 * x;
            }
            ux = i;
        }
        ux <<= 1;
    }
    {
        const i = ux - uy;
        if (i >> 31 == 0) {
            if (i == 0) {
                return 0 * x;
            }
            ux = i;
        }
    }

    while (ux >> 23 == 0) : (ux <<= 1) {
        ex -= 1;
    }

    // scale result up
    if (ex > 0) {
        ux -= 1 << 23;
        ux |= u32(ex) << 23;
    } else {
        ux >>= u32(-ex + 1);
    }

    ux |= sx;
    @bitCast(f32, ux)
}

fn fmod64(x: f64, y: f64) -> f64 {
    var ux = @bitCast(u64, x);
    var uy = @bitCast(u64, y);
    var ex = i32(ux >> 52) & 0x7FF;
    var ey = i32(ux >> 52) & 0x7FF;
    const sx = ux >> 63;

    if (uy << 1 == 0 or math.isNan(y) or ex == 0x7FF) {
        return (x * y) / (x * y);
    }
    if (ux << 1 <= uy << 1) {
        if (ux << 1 == uy << 1) {
            return 0 * x;
        } else {
            return x;
        }
    }

    // normalize x and y
    if (ex == 0) {
        var i = ux << 12;
        while (i >> 63 == 0) : (i <<= 1) {
            ex -= 1;
        }
        ux <<= u64(-ex + 1);
    } else {
        ux &= @maxValue(u64) >> 12;
        ux |= 1 << 52;
    }

    if (ey == 0) {
        var i = uy << 12;
        while (i >> 63 == 0) : (i <<= 1) {
            ey -= 1;
        }
        uy <<= u64(-ey + 1);
    } else {
        uy &= @maxValue(u64) >> 12;
        uy |= 1 << 52;
    }

    // x mod y
    while (ex > ey) : (ex -= 1) {
        const i = ux - uy;
        if (i >> 63 == 0) {
            if (i == 0) {
                return 0 * x;
            }
            ux = i;
        }
        ux <<= 1;
    }
    {
        const i = ux - uy;
        if (i >> 63 == 0) {
            if (i == 0) {
                return 0 * x;
            }
            ux = i;
        }
    }

    while (ux >> 52 == 0) : (ux <<= 1) {
        ex -= 1;
    }

    // scale result up
    if (ex > 0) {
        ux -= 1 << 52;
        ux |= u64(ex) << 52;
    } else {
        ux >>= u64(-ex + 1);
    }

    ux |= sx << 63;
    @bitCast(f64, ux)
}

// duplicate symbol clash with `fmod` test name
test "fmod_" {
    assert(fmod(f32, 1.3, 2.5) == fmod32(1.3, 2.5));
    assert(fmod(f64, 1.3, 2.5) == fmod64(1.3, 2.5));
}

test "fmod32" {
    const epsilon = 0.000001;

    assert(math.approxEq(f32, fmod32(5.2, 2.0), 1.2, epsilon));
    assert(math.approxEq(f32, fmod32(18.5, 4.2), 1.7, epsilon));
    assert(math.approxEq(f32, fmod32(23, 48.34), 23.0, epsilon));
    assert(math.approxEq(f32, fmod32(123.340890, 2398.2314), 123.340889, epsilon));
}

test "fmod64" {
    const epsilon = 0.000001;

    assert(math.approxEq(f64, fmod64(5.2, 2.0), 1.2, epsilon));
    assert(math.approxEq(f64, fmod64(18.5, 4.2), 1.7, epsilon));
    assert(math.approxEq(f64, fmod64(23, 48.34), 23.0, epsilon));
    assert(math.approxEq(f64, fmod64(123.340890, 2398.2314), 123.340889, epsilon));
}
