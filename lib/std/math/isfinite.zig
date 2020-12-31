// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const maxInt = std.math.maxInt;

/// Returns whether x is a finite value.
pub fn isFinite(x: anytype) bool {
    const T = @TypeOf(x);
    switch (T) {
        f16 => {
            const bits = @bitCast(u16, x);
            return bits & 0x7FFF < 0x7C00;
        },
        f32 => {
            const bits = @bitCast(u32, x);
            return bits & 0x7FFFFFFF < 0x7F800000;
        },
        f64 => {
            const bits = @bitCast(u64, x);
            return bits & (maxInt(u64) >> 1) < (0x7FF << 52);
        },
        else => {
            @compileError("isFinite not implemented for " ++ @typeName(T));
        },
    }
}

test "math.isFinite" {
    expect(isFinite(@as(f16, 0.0)));
    expect(isFinite(@as(f16, -0.0)));
    expect(isFinite(@as(f32, 0.0)));
    expect(isFinite(@as(f32, -0.0)));
    expect(isFinite(@as(f64, 0.0)));
    expect(isFinite(@as(f64, -0.0)));
    expect(!isFinite(math.inf(f16)));
    expect(!isFinite(-math.inf(f16)));
    expect(!isFinite(math.inf(f32)));
    expect(!isFinite(-math.inf(f32)));
    expect(!isFinite(math.inf(f64)));
    expect(!isFinite(-math.inf(f64)));
}
