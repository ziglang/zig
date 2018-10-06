// Special Cases:
//
//  powi(x, +-0)    = 1 for any x
//  powi(1, y)      = 1 for any y
//  powi(x, 1)      = x for any x
//  powi(nan, y)    = nan
//  powi(x, nan)    = nan
//  powi(+-0, y)    = +-inf for y an odd integer < 0
//  powi(+-0, -inf) = +inf
//  powi(+-0, +inf) = +0
//  powi(+-0, y)    = +inf for finite y < 0 and not an odd integer
//  powi(+-0, y)    = +-0 for y an odd integer > 0
//  powi(+-0, y)    = +0 for finite y > 0 and not an odd integer
//  powi(-1, +-inf) = 1
//  powi(x, +inf)   = +inf for |x| > 1
//  powi(x, -inf)   = +0 for |x| > 1
//  powi(x, +inf)   = +0 for |x| < 1
//  powi(x, -inf)   = +inf for |x| < 1
//  powi(+inf, y)   = +inf for y > 0
//  powi(+inf, y)   = +0 for y < 0
//  powi(-inf, y)   = powi(-0, -y)
//  powi(x, y)      = nan for finite x < 0 and finite non-integer y

const builtin = @import("builtin");
const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;
const assertError = std.debug.assertError;

inline fn checkFlow(comptime T: type, comptime info: builtin.TypeInfo, x: T, y: T) (error{Overflow, Underflow}!void) {
    const bit_size = @sizeOf(T) * 8;

    if (info.Int.is_signed) {
        if (x != 1 and x != -1) {
            if (x > 0 and y >= bit_size - 1) {
                return error.Overflow;
            } else if (x < 0 and y > bit_size - 1) {
                return error.Underflow;
            }
        }
    } else {
        if (x != 1 and y >= bit_size) {
            return error.Overflow;
        }
    }
}

// This implementation is based on that from the rust stlib
pub fn safePowi(comptime T: type, x: T, y: T) !T {
    const info = @typeInfo(T);

    switch (info) {
        builtin.TypeId.Int => {
            try checkFlow(T, info, x, y);

            var base = x;
            var exp = y;
            var acc: T = 1;

            while (exp > 1) {
                if (exp & 1 == 1) {
                    if (@mulWithOverflow(T, acc, base, &acc)) {
                        if (x > 0) {
                            return error.Overflow;
                        } else {
                            return error.Underflow;
                        }
                    }
                }

                exp >>= 1;

                if (@mulWithOverflow(T, base, base, &base)) {
                    if (x > 0) {
                        return error.Overflow;
                    } else {
                        return error.Underflow;
                    }
                }
            }

            if (exp == 1) {
                if (@mulWithOverflow(T, acc, base, &acc)) {
                    if (x > 0) {
                        return error.Overflow;
                    } else {
                        return error.Underflow;
                    }
                }
            }

            return acc;
        },
        else => @compileError("expected integer type got " ++ @typeName(T)),
    }
}

pub fn powi(comptime T: type, x: T, y: T) T {
    return safePowi(T, x, y) catch unreachable;
}

test "math.powi" {
    assertError(safePowi(i8, -66, 6), error.Underflow);
    assertError(safePowi(i16, -13, 13), error.Underflow);
    assertError(safePowi(i32, -32, 21), error.Underflow);
    assertError(safePowi(i64, -24, 61), error.Underflow);
    assertError(safePowi(i17, -15, 15), error.Underflow);
    assertError(safePowi(i42, -6, 40), error.Underflow);

    assert((try safePowi(i8, -5, 3)) == -125);
    assert((try safePowi(i16, -16, 3)) == -4096);
    assert((try safePowi(i32, -91, 3)) == -753571);
    assert((try safePowi(i64, -36, 6)) == 2176782336);
    assert((try safePowi(i17, -2, 15)) == -32768);
    assert((try safePowi(i42, -5, 7)) == -78125);

    assert((try safePowi(u8, 6, 2)) == 36);
    assert((try safePowi(u16, 5, 4)) == 625);
    assert((try safePowi(u32, 12, 6)) == 2985984);
    assert((try safePowi(u64, 34, 2)) == 1156);
    assert((try safePowi(u17, 16, 3)) == 4096);
    assert((try safePowi(u42, 34, 6)) == 1544804416);

    assertError(safePowi(i8, 120, 7), error.Overflow);
    assertError(safePowi(i16, 73, 15), error.Overflow);
    assertError(safePowi(i32, 23, 31), error.Overflow);
    assertError(safePowi(i64, 68, 61), error.Overflow);
    assertError(safePowi(i17, 15, 15), error.Overflow);
    assertError(safePowi(i42, 121312, 41), error.Overflow);

    assertError(safePowi(u8, 123, 7), error.Overflow);
    assertError(safePowi(u16, 2313, 15), error.Overflow);
    assertError(safePowi(u32, 8968, 31), error.Overflow);
    assertError(safePowi(u64, 2342, 63), error.Overflow);
    assertError(safePowi(u17, 2723, 16), error.Overflow);
    assertError(safePowi(u42, 8234, 41), error.Overflow);
}
