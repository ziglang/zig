// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const math = std.math;
const expect = std.testing.expect;
const builtin = @import("builtin");
const TypeId = builtin.TypeId;
const maxInt = std.math.maxInt;

/// Returns the square root of x.
///
/// Special Cases:
///  - sqrt(+inf)  = +inf
///  - sqrt(+-0)   = +-0
///  - sqrt(x)     = nan if x < 0
///  - sqrt(nan)   = nan
/// TODO Decide if all this logic should be implemented directly in the @sqrt bultin function.
pub fn sqrt(x: anytype) Sqrt(@TypeOf(x)) {
    const T = @TypeOf(x);
    switch (@typeInfo(T)) {
        .Float, .ComptimeFloat => return @sqrt(x),
        .ComptimeInt => comptime {
            if (x > maxInt(u128)) {
                @compileError("sqrt not implemented for comptime_int greater than 128 bits");
            }
            if (x < 0) {
                @compileError("sqrt on negative number");
            }
            return @as(T, sqrt_int(u128, x));
        },
        .Int => return sqrt_int(T, x),
        else => @compileError("sqrt not implemented for " ++ @typeName(T)),
    }
}

fn sqrt_int(comptime T: type, value: T) std.meta.Int(false, @typeInfo(T).Int.bits / 2) {
    var op = value;
    var res: T = 0;
    var one: T = 1 << (@typeInfo(T).Int.bits - 2);

    // "one" starts at the highest power of four <= than the argument.
    while (one > op) {
        one >>= 2;
    }

    while (one != 0) {
        if (op >= res + one) {
            op -= res + one;
            res += 2 * one;
        }
        res >>= 1;
        one >>= 2;
    }

    const ResultType = std.meta.Int(false, @typeInfo(T).Int.bits / 2);
    return @intCast(ResultType, res);
}

test "math.sqrt_int" {
    expect(sqrt_int(u32, 3) == 1);
    expect(sqrt_int(u32, 4) == 2);
    expect(sqrt_int(u32, 5) == 2);
    expect(sqrt_int(u32, 8) == 2);
    expect(sqrt_int(u32, 9) == 3);
    expect(sqrt_int(u32, 10) == 3);
}

/// Returns the return type `sqrt` will return given an operand of type `T`.
pub fn Sqrt(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .Int => |int| std.meta.Int(false, int.bits / 2),
        else => T,
    };
}
