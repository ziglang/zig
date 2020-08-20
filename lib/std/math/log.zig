// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from musl, which is licensed under the MIT license:
// https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
//
// https://git.musl-libc.org/cgit/musl/tree/src/math/logf.c
// https://git.musl-libc.org/cgit/musl/tree/src/math/log.c

const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;

/// Returns the logarithm of x for the provided base.
pub fn log(comptime T: type, base: T, x: T) T {
    if (base == 2) {
        return math.log2(x);
    } else if (base == 10) {
        return math.log10(x);
    } else if ((@typeInfo(T) == .Float or @typeInfo(T) == .ComptimeFloat) and base == math.e) {
        return math.ln(x);
    }

    const float_base = math.lossyCast(f64, base);
    switch (@typeInfo(T)) {
        .ComptimeFloat => {
            return @as(comptime_float, math.ln(@as(f64, x)) / math.ln(float_base));
        },
        .ComptimeInt => {
            return @as(comptime_int, math.floor(math.ln(@as(f64, x)) / math.ln(float_base)));
        },
        .Int => {
            // TODO implement integer log without using float math
            return @floatToInt(T, math.floor(math.ln(@intToFloat(f64, x)) / math.ln(float_base)));
        },

        .Float => {
            switch (T) {
                f32 => return @floatCast(f32, math.ln(@as(f64, x)) / math.ln(float_base)),
                f64 => return math.ln(x) / math.ln(float_base),
                else => @compileError("log not implemented for " ++ @typeName(T)),
            }
        },

        else => {
            @compileError("log expects integer or float, found '" ++ @typeName(T) ++ "'");
        },
    }
}

test "math.log integer" {
    expect(log(u8, 2, 0x1) == 0);
    expect(log(u8, 2, 0x2) == 1);
    expect(log(i16, 2, 0x72) == 6);
    expect(log(u32, 2, 0xFFFFFF) == 23);
    expect(log(u64, 2, 0x7FF0123456789ABC) == 62);
}

test "math.log float" {
    const epsilon = 0.000001;

    expect(math.approxEq(f32, log(f32, 6, 0.23947), -0.797723, epsilon));
    expect(math.approxEq(f32, log(f32, 89, 0.23947), -0.318432, epsilon));
    expect(math.approxEq(f64, log(f64, 123897, 12389216414), 1.981724596, epsilon));
}

test "math.log float_special" {
    expect(log(f32, 2, 0.2301974) == math.log2(@as(f32, 0.2301974)));
    expect(log(f32, 10, 0.2301974) == math.log10(@as(f32, 0.2301974)));

    expect(log(f64, 2, 213.23019799993) == math.log2(@as(f64, 213.23019799993)));
    expect(log(f64, 10, 213.23019799993) == math.log10(@as(f64, 213.23019799993)));
}
