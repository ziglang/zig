// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

// Returns whether x has a normalized representation (i.e. integer part of mantissa is 1).
pub fn isNormal(x: anytype) bool {
    const T = @TypeOf(x);
    switch (T) {
        f16 => {
            const bits = @bitCast(u16, x);
            return (bits + 1024) & 0x7FFF >= 2048;
        },
        f32 => {
            const bits = @bitCast(u32, x);
            return (bits + 0x00800000) & 0x7FFFFFFF >= 0x01000000;
        },
        f64 => {
            const bits = @bitCast(u64, x);
            return (bits + (1 << 52)) & (maxInt(u64) >> 1) >= (1 << 53);
        },
        else => {
            @compileError("isNormal not implemented for " ++ @typeName(T));
        },
    }
}

test "math.isNormal" {
    expect(!isNormal(math.nan(f16)));
    expect(!isNormal(math.nan(f32)));
    expect(!isNormal(math.nan(f64)));
    expect(!isNormal(@as(f16, 0)));
    expect(!isNormal(@as(f32, 0)));
    expect(!isNormal(@as(f64, 0)));
    expect(isNormal(@as(f16, 1.0)));
    expect(isNormal(@as(f32, 1.0)));
    expect(isNormal(@as(f64, 1.0)));
}
