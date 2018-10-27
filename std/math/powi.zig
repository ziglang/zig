// Special Cases:
//
//  powi(x, +-0)   = 1 for any x
//  powi(0, y)     = 1 for any y
//  powi(1, y)     = 1 for any y
//  powi(-1, y)    = -1 for for y an odd integer
//  powi(-1, y)    = 1 for for y an even integer
//  powi(x, y)     = Overflow for for y >= @sizeOf(x) - 1 y > 0
//  powi(x, y)     = Underflow for for y > @sizeOf(x) - 1 y < 0

const builtin = @import("builtin");
const std = @import("../index.zig");
const math = std.math;
const assert = std.debug.assert;
const assertError = std.debug.assertError;

// This implementation is based on that from the rust stlib
pub fn powi(comptime T: type, x: T, y: T) (error{Overflow, Underflow}!T) {
    const info = @typeInfo(T);

    comptime assert(@typeInfo(T) == builtin.TypeId.Int);

    //  powi(x, +-0)   = 1 for any x
    if (y == 0 or y == -0) {
        return 0;
    }

    switch (x) {
        //  powi(0, y)     = 1 for any y
        0  => return 0,
        
        //  powi(1, y)     = 1 for any y
        1  => return 1,

        else => {
            //  powi(x, y)     = Overflow for for y >= @sizeOf(x) - 1 y > 0
            //  powi(x, y)     = Underflow for for y > @sizeOf(x) - 1 y < 0
            const bit_size = @sizeOf(T) * 8;
            if (info.Int.is_signed) {

                if (x == -1) {
                    //  powi(-1, y)    = -1 for for y an odd integer
                    //  powi(-1, y)    = 1 for for y an even integer
                    if (@mod(y, 2) == 0) {
                        return 1;
                    } else {
                        return -1;
                    }
                }

                if (x > 0 and y >= bit_size - 1) {
                    return error.Overflow;
                } else if (x < 0 and y > bit_size - 1) {
                    return error.Underflow;
                }
            } else {
                if (y >= bit_size) {
                    return error.Overflow;
                }
            }

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
        }
    }
}

test "math.powi" {
    assertError(powi(i8, -66, 6), error.Underflow);
    assertError(powi(i16, -13, 13), error.Underflow);
    assertError(powi(i32, -32, 21), error.Underflow);
    assertError(powi(i64, -24, 61), error.Underflow);
    assertError(powi(i17, -15, 15), error.Underflow);
    assertError(powi(i42, -6, 40), error.Underflow);

    assert((try powi(i8, -5, 3)) == -125);
    assert((try powi(i16, -16, 3)) == -4096);
    assert((try powi(i32, -91, 3)) == -753571);
    assert((try powi(i64, -36, 6)) == 2176782336);
    assert((try powi(i17, -2, 15)) == -32768);
    assert((try powi(i42, -5, 7)) == -78125);

    assert((try powi(u8, 6, 2)) == 36);
    assert((try powi(u16, 5, 4)) == 625);
    assert((try powi(u32, 12, 6)) == 2985984);
    assert((try powi(u64, 34, 2)) == 1156);
    assert((try powi(u17, 16, 3)) == 4096);
    assert((try powi(u42, 34, 6)) == 1544804416);

    assertError(powi(i8, 120, 7), error.Overflow);
    assertError(powi(i16, 73, 15), error.Overflow);
    assertError(powi(i32, 23, 31), error.Overflow);
    assertError(powi(i64, 68, 61), error.Overflow);
    assertError(powi(i17, 15, 15), error.Overflow);
    assertError(powi(i42, 121312, 41), error.Overflow);

    assertError(powi(u8, 123, 7), error.Overflow);
    assertError(powi(u16, 2313, 15), error.Overflow);
    assertError(powi(u32, 8968, 31), error.Overflow);
    assertError(powi(u64, 2342, 63), error.Overflow);
    assertError(powi(u17, 2723, 16), error.Overflow);
    assertError(powi(u42, 8234, 41), error.Overflow);
}

test "math.powi.special" {
    assertError(powi(i8, -2, 8), error.Underflow);
    assertError(powi(i16, -2, 16), error.Underflow);
    assertError(powi(i32, -2, 32), error.Underflow);
    assertError(powi(i64, -2, 64), error.Underflow);
    assertError(powi(i17, -2, 17), error.Underflow);
    assertError(powi(i42, -2, 42), error.Underflow);

    assert((try powi(i8, -1, 3)) == -1);
    assert((try powi(i16, -1, 2)) == 1);
    assert((try powi(i32, -1, 16)) == 1);
    assert((try powi(i64, -1, 6)) == 1);
    assert((try powi(i17, -1, 15)) == -1);
    assert((try powi(i42, -1, 7)) == -1);

    assert((try powi(u8, 1, 2)) == 1);
    assert((try powi(u16, 1, 4)) == 1);
    assert((try powi(u32, 1, 6)) == 1);
    assert((try powi(u64, 1, 2)) == 1);
    assert((try powi(u17, 1, 3)) == 1);
    assert((try powi(u42, 1, 6)) == 1);

    assertError(powi(i8, 2, 7), error.Overflow);
    assertError(powi(i16, 2, 15), error.Overflow);
    assertError(powi(i32, 2, 31), error.Overflow);
    assertError(powi(i64, 2, 63), error.Overflow);
    assertError(powi(i17, 2, 16), error.Overflow);
    assertError(powi(i42, 2, 41), error.Overflow);

    assertError(powi(u8, 2, 8), error.Overflow);
    assertError(powi(u16, 2, 16), error.Overflow);
    assertError(powi(u32, 2, 32), error.Overflow);
    assertError(powi(u64, 2, 64), error.Overflow);
    assertError(powi(u17, 2, 17), error.Overflow);
    assertError(powi(u42, 2, 42), error.Overflow);
}
