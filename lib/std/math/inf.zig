// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const math = std.math;

/// Returns value inf for the type T.
pub fn inf(comptime T: type) T {
    return switch (T) {
        f16 => math.inf_f16,
        f32 => math.inf_f32,
        f64 => math.inf_f64,
        f128 => math.inf_f128,
        else => @compileError("inf not implemented for " ++ @typeName(T)),
    };
}
