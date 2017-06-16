const math = @import("index.zig");
const builtin = @import("builtin");
const assert = @import("../debug.zig").assert;

pub fn log(comptime base: usize, x: var) -> @typeOf(x) {
    const T = @typeOf(x);
    switch (@typeId(T)) {
        builtin.TypeId.Int => {
            if (base == 2) {
                return T.bit_count - 1 - @clz(x);
            } else {
                @compileError("TODO implement log for non base 2 integers");
            }
        },

        builtin.TypeId.Float => {
            return logf(base, x);
        },

        else => {
            @compileError("log expects integer or float, found '" ++ @typeName(T) ++ "'");
        },
    }
}

fn logf(comptime base: usize, x: var) -> @typeOf(x) {
    const T = @typeOf(x);
    switch (T) {
        f32 => {
            switch (base) {
                2 => return math.log2(x),
                10 => return math.log10(x),
                else => return f32(math.ln(f64(x)) / math.ln(f64(base))),
            }
        },

        f64 => {
            switch (base) {
                2 => return math.log2(x),
                10 => return math.log10(x),
                // NOTE: This likely is computed with reduced accuracy.
                else => return math.ln(x) / math.ln(f64(base)),
            }
        },

        else => @compileError("log not implemented for " ++ @typeName(T)),
    }
}

test "log_integer" {
    assert(log(2, u8(0x1)) == 0);
    assert(log(2, u8(0x2)) == 1);
    assert(log(2, i16(0x72)) == 6);
    assert(log(2, u32(0xFFFFFF)) == 23);
    assert(log(2, u64(0x7FF0123456789ABC)) == 62);
}

test "log_float" {
    const epsilon = 0.000001;

    assert(math.approxEq(f32, log(6, f32(0.23947)), -0.797723, epsilon));
    assert(math.approxEq(f32, log(89, f32(0.23947)), -0.318432, epsilon));
    assert(math.approxEq(f64, log(123897, f64(12389216414)), 1.981724596, epsilon));
}

test "log_float_special" {
    assert(log(2, f32(0.2301974)) == math.log2(f32(0.2301974)));
    assert(log(10, f32(0.2301974)) == math.log10(f32(0.2301974)));

    assert(log(2, f64(213.23019799993)) == math.log2(f64(213.23019799993)));
    assert(log(10, f64(213.23019799993)) == math.log10(f64(213.23019799993)));
}
