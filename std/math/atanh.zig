const math = @import("index.zig");
const assert = @import("../debug.zig").assert;

pub fn atanh(x: var) -> @typeOf(x) {
    const T = @typeOf(x);
    switch (T) {
        f32 => @inlineCall(atanhf, x),
        f64 => @inlineCall(atanhd, x),
        else => @compileError("atanh not implemented for " ++ @typeName(T)),
    }
}

// atanh(x) = log((1 + x) / (1 - x)) / 2 = log1p(2x / (1 - x)) / 2 ~= x + x^3 / 3 + o(x^5)
fn atanhf(x: f32) -> f32 {
    const u = @bitCast(u32, x);
    const i = u & 0x7FFFFFFF;
    const s = u >> 31;

    var y = @bitCast(f32, i); // |x|

    if (u < 0x3F800000 - (1 << 23)) {
        if (u < 0x3F800000 - (32 << 23)) {
            // underflow
            if (u < (1 << 23)) {
                math.forceEval(y * y)
            }
        }
        // |x| < 0.5
        else {
            y = 0.5 * math.log1p(2 * y + 2 * y * y / (1 - y));
        }
    } else {
        // avoid overflow
        y = 0.5 * math.log1p(2 * (y / (1 - y)));
    }

    if (s != 0) -y else y
}

fn atanhd(x: f64) -> f64 {
    const u = @bitCast(u64, x);
    const e = (u >> 52) & 0x7FF;
    const s = u >> 63;

    var y = @bitCast(f64, u & (@maxValue(u64) >> 1)); // |x|

    if (e < 0x3FF - 1) {
        if (e < 0x3FF - 32) {
            // underflow
            if (e == 0) {
                math.forceEval(f32(y));
            }
        }
        // |x| < 0.5
        else {
            y = 0.5 * math.log1p(2 * y + 2 * y * y / (1 - y));
        }
    } else {
        // avoid overflow
        y = 0.5 * math.log1p(2 * (y / (1 - y)));
    }

    if (s != 0) -y else y
}

test "atanh" {
    assert(atanh(f32(0.0)) == atanhf(0.0));
    assert(atanh(f64(0.0)) == atanhd(0.0));
}

test "atanhf" {
    const epsilon = 0.000001;

    assert(math.approxEq(f32, atanhf(0.0), 0.0, epsilon));
    assert(math.approxEq(f32, atanhf(0.2), 0.202733, epsilon));
    assert(math.approxEq(f32, atanhf(0.8923), 1.433099, epsilon));
}

test "atanhd" {
    const epsilon = 0.000001;

    assert(math.approxEq(f64, atanhd(0.0), 0.0, epsilon));
    assert(math.approxEq(f64, atanhd(0.2), 0.202733, epsilon));
    assert(math.approxEq(f64, atanhd(0.8923), 1.433099, epsilon));
}
