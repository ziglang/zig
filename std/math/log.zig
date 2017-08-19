const math = @import("index.zig");
const builtin = @import("builtin");
const TypeId = builtin.TypeId;
const assert = @import("../debug.zig").assert;

// TODO issue #393
pub const log = log_workaround;

fn log_workaround(comptime T: type, base: T, x: T) -> T {
    if (base == 2) {
        return math.log2(x);
    } else if (base == 10) {
        return math.log10(x);
    } else if ((@typeId(T) == TypeId.Float or @typeId(T) == TypeId.FloatLiteral) and base == math.e) {
        return math.ln(x);
    }

    switch (@typeId(T)) {
        TypeId.FloatLiteral => {
            return @typeOf(1.0)(math.ln(f64(x)) / math.ln(f64(base)));
        },
        TypeId.IntLiteral => {
            return @typeOf(1)(math.floor(math.ln(f64(x)) / math.ln(f64(base))));
        },
        builtin.TypeId.Int => {
            // TODO implement integer log without using float math
            return T(math.floor(math.ln(f64(x)) / math.ln(f64(base))));
        },

        builtin.TypeId.Float => {
            switch (T) {
                f32 => return f32(math.ln(f64(x)) / math.ln(f64(base))),
                f64 => return math.ln(x) / math.ln(f64(base)),
                else => @compileError("log not implemented for " ++ @typeName(T)),
            };
        },

        else => {
            @compileError("log expects integer or float, found '" ++ @typeName(T) ++ "'");
        },
    }
}

test "math.log integer" {
    assert(log(u8, 2, 0x1) == 0);
    assert(log(u8, 2, 0x2) == 1);
    assert(log(i16, 2, 0x72) == 6);
    assert(log(u32, 2, 0xFFFFFF) == 23);
    assert(log(u64, 2, 0x7FF0123456789ABC) == 62);
}

test "math.log float" {
    const epsilon = 0.000001;

    assert(math.approxEq(f32, log(f32, 6, 0.23947), -0.797723, epsilon));
    assert(math.approxEq(f32, log(f32, 89, 0.23947), -0.318432, epsilon));
    assert(math.approxEq(f64, log(f64, 123897, 12389216414), 1.981724596, epsilon));
}

test "math.log float_special" {
    assert(log(f32, 2, 0.2301974) == math.log2(f32(0.2301974)));
    assert(log(f32, 10, 0.2301974) == math.log10(f32(0.2301974)));

    assert(log(f64, 2, 213.23019799993) == math.log2(f64(213.23019799993)));
    assert(log(f64, 10, 213.23019799993) == math.log10(f64(213.23019799993)));
}
