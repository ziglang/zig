const assert = @import("../debug.zig").assert;
const math = @import("index.zig");

pub fn frexp(x: var, e: &i32) -> @typeOf(x) {
    const T = @typeOf(x);
    switch (T) {
        f32 => frexp32(x, e),
        f64 => frexp64(x, e),
        else => @compileError("frexp not implemented for " ++ @typeName(T)),
    }
}

fn frexp32(x_: f32, e: &i32) -> f32 {
    var x = x_;
    var y = @bitCast(u32, x);
    const ee = i32(y >> 23) & 0xFF;

    if (ee == 0) {
        if (x != 0) {
            x = frexp32(x * 0x1.0p64, e);
            *e -= 64;
        } else {
            *e = 0;
        }
        return x;
    } else if (ee == 0xFF) {
        return x;
    }

    *e = ee - 0x7E;
    y &= 0x807FFFFF;
    y |= 0x3F000000;
    @bitCast(f32, y)
}

fn frexp64(x_: f64, e: &i32) -> f64 {
    var x = x_;
    var y = @bitCast(u64, x);
    const ee = i32(y >> 52) & 0x7FF;

    if (ee == 0) {
        if (x != 0) {
            x = frexp64(x * 0x1.0p64, e);
            *e -= 64;
        } else {
            *e = 0;
        }
        return x;
    } else if (ee == 0x7FF) {
        return x;
    }

    *e = ee - 0x3FE;
    y &= 0x800FFFFFFFFFFFFF;
    y |= 0x3FE0000000000000;
    @bitCast(f64, y)
}

test "frexp" {
    var i0: i32 = undefined;
    var i1: i32 = undefined;

    assert(frexp(f32(1.3), &i0) == frexp32(1.3, &i1));
    assert(frexp(f64(1.3), &i0) == frexp64(1.3, &i1));
}

test "frexp32" {
    const epsilon = 0.000001;
    var i: i32 = undefined;
    var d: f32 = undefined;

    d = frexp32(1.3, &i);
    assert(math.approxEq(f32, d, 0.65, epsilon) and i == 1);

    d = frexp32(78.0234, &i);
    assert(math.approxEq(f32, d, 0.609558, epsilon) and i == 7);
}

test "frexp64" {
    const epsilon = 0.000001;
    var i: i32 = undefined;
    var d: f64 = undefined;

    d = frexp64(1.3, &i);
    assert(math.approxEq(f64, d, 0.65, epsilon) and i == 1);

    d = frexp64(78.0234, &i);
    assert(math.approxEq(f64, d, 0.609558, epsilon) and i == 7);
}
