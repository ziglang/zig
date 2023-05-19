const std = @import("std");
const parse = @import("parse.zig");
const convertFast = @import("convert_fast.zig").convertFast;
const convertEiselLemire = @import("convert_eisel_lemire.zig").convertEiselLemire;
const convertSlow = @import("convert_slow.zig").convertSlow;
const convertHex = @import("convert_hex.zig").convertHex;

const optimize = true;

pub const ParseFloatError = error{
    InvalidCharacter,
};

pub fn parseFloat(comptime T: type, s: []const u8) ParseFloatError!T {
    if (@typeInfo(T) != .Float) {
        @compileError("Cannot parse a float into a non-floating point type.");
    }

    if (T == f80) {
        @compileError("TODO support parsing float to f80");
    }

    if (s.len == 0) {
        return error.InvalidCharacter;
    }

    var i: usize = 0;
    const negative = s[i] == '-';
    if (s[i] == '-' or s[i] == '+') {
        i += 1;
    }
    if (s.len == i) {
        return error.InvalidCharacter;
    }

    const n = parse.parseNumber(T, s[i..], negative) orelse {
        return parse.parseInfOrNan(T, s[i..], negative) orelse error.InvalidCharacter;
    };

    if (n.hex) {
        return convertHex(T, n);
    }

    if (optimize) {
        if (convertFast(T, n)) |f| {
            return f;
        }

        if (T == f16 or T == f32 or T == f64) {
            // If significant digits were truncated, then we can have rounding error
            // only if `mantissa + 1` produces a different result. We also avoid
            // redundantly using the Eisel-Lemire algorithm if it was unable to
            // correctly round on the first pass.
            if (convertEiselLemire(T, n.exponent, n.mantissa)) |bf| {
                if (!n.many_digits) {
                    return bf.toFloat(T, n.negative);
                }
                if (convertEiselLemire(T, n.exponent, n.mantissa + 1)) |bf2| {
                    if (bf.eql(bf2)) {
                        return bf.toFloat(T, n.negative);
                    }
                }
            }
        }
    }

    // Unable to correctly round the float using the Eisel-Lemire algorithm.
    // Fallback to a slower, but always correct algorithm.
    return convertSlow(T, s[i..]).toFloat(T, negative);
}
