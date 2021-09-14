// Based on Rust, which is licensed under the MIT license.
// https://github.com/rust-lang/rust/blob/360432f1e8794de58cd94f34c9c17ad65871e5b5/LICENSE-MIT
//
// https://github.com/rust-lang/rust/blob/360432f1e8794de58cd94f34c9c17ad65871e5b5/src/libcore/num/mod.rs#L3423

const std = @import("../std.zig");
const math = std.math;
const assert = std.debug.assert;
const testing = std.testing;

/// Returns the power of x raised by the integer y (x^y).
///
/// Special Cases:
///  - powi(x, +-0)   = 1 for any x
///  - powi(0, y)     = 0 for any y
///  - powi(1, y)     = 1 for any y
///  - powi(-1, y)    = -1 for y an odd integer
///  - powi(-1, y)    = 1 for y an even integer
///  - powi(x, y)     = Overflow for y >= @sizeOf(x) - 1 or y > 0
///  - powi(x, y)     = Underflow for y > @sizeOf(x) - 1 or y < 0
pub fn powi(comptime T: type, x: T, y: T) (error{
    Overflow,
    Underflow,
}!T) {
    const info = @typeInfo(T);

    comptime assert(@typeInfo(T) == .Int);

    //  powi(x, +-0)   = 1 for any x
    if (y == 0 or y == -0) {
        return 1;
    }

    switch (x) {
        //  powi(0, y)     = 0 for any y
        0 => return 0,

        //  powi(1, y)     = 1 for any y
        1 => return 1,

        else => {
            //  powi(x, y)     = Overflow for for y >= @sizeOf(x) - 1 y > 0
            //  powi(x, y)     = Underflow for for y > @sizeOf(x) - 1 y < 0
            const bit_size = @sizeOf(T) * 8;
            if (info.Int.signedness == .signed) {
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
        },
    }
}

test "math.powi" {
    try testing.expectError(error.Underflow, powi(i8, -66, 6));
    try testing.expectError(error.Underflow, powi(i16, -13, 13));
    try testing.expectError(error.Underflow, powi(i32, -32, 21));
    try testing.expectError(error.Underflow, powi(i64, -24, 61));
    try testing.expectError(error.Underflow, powi(i17, -15, 15));
    try testing.expectError(error.Underflow, powi(i42, -6, 40));

    try testing.expect((try powi(i8, -5, 3)) == -125);
    try testing.expect((try powi(i16, -16, 3)) == -4096);
    try testing.expect((try powi(i32, -91, 3)) == -753571);
    try testing.expect((try powi(i64, -36, 6)) == 2176782336);
    try testing.expect((try powi(i17, -2, 15)) == -32768);
    try testing.expect((try powi(i42, -5, 7)) == -78125);

    try testing.expect((try powi(u8, 6, 2)) == 36);
    try testing.expect((try powi(u16, 5, 4)) == 625);
    try testing.expect((try powi(u32, 12, 6)) == 2985984);
    try testing.expect((try powi(u64, 34, 2)) == 1156);
    try testing.expect((try powi(u17, 16, 3)) == 4096);
    try testing.expect((try powi(u42, 34, 6)) == 1544804416);

    try testing.expectError(error.Overflow, powi(i8, 120, 7));
    try testing.expectError(error.Overflow, powi(i16, 73, 15));
    try testing.expectError(error.Overflow, powi(i32, 23, 31));
    try testing.expectError(error.Overflow, powi(i64, 68, 61));
    try testing.expectError(error.Overflow, powi(i17, 15, 15));
    try testing.expectError(error.Overflow, powi(i42, 121312, 41));

    try testing.expectError(error.Overflow, powi(u8, 123, 7));
    try testing.expectError(error.Overflow, powi(u16, 2313, 15));
    try testing.expectError(error.Overflow, powi(u32, 8968, 31));
    try testing.expectError(error.Overflow, powi(u64, 2342, 63));
    try testing.expectError(error.Overflow, powi(u17, 2723, 16));
    try testing.expectError(error.Overflow, powi(u42, 8234, 41));
}

test "math.powi.special" {
    try testing.expectError(error.Underflow, powi(i8, -2, 8));
    try testing.expectError(error.Underflow, powi(i16, -2, 16));
    try testing.expectError(error.Underflow, powi(i32, -2, 32));
    try testing.expectError(error.Underflow, powi(i64, -2, 64));
    try testing.expectError(error.Underflow, powi(i17, -2, 17));
    try testing.expectError(error.Underflow, powi(i42, -2, 42));

    try testing.expect((try powi(i8, -1, 3)) == -1);
    try testing.expect((try powi(i16, -1, 2)) == 1);
    try testing.expect((try powi(i32, -1, 16)) == 1);
    try testing.expect((try powi(i64, -1, 6)) == 1);
    try testing.expect((try powi(i17, -1, 15)) == -1);
    try testing.expect((try powi(i42, -1, 7)) == -1);

    try testing.expect((try powi(u8, 1, 2)) == 1);
    try testing.expect((try powi(u16, 1, 4)) == 1);
    try testing.expect((try powi(u32, 1, 6)) == 1);
    try testing.expect((try powi(u64, 1, 2)) == 1);
    try testing.expect((try powi(u17, 1, 3)) == 1);
    try testing.expect((try powi(u42, 1, 6)) == 1);

    try testing.expectError(error.Overflow, powi(i8, 2, 7));
    try testing.expectError(error.Overflow, powi(i16, 2, 15));
    try testing.expectError(error.Overflow, powi(i32, 2, 31));
    try testing.expectError(error.Overflow, powi(i64, 2, 63));
    try testing.expectError(error.Overflow, powi(i17, 2, 16));
    try testing.expectError(error.Overflow, powi(i42, 2, 41));

    try testing.expectError(error.Overflow, powi(u8, 2, 8));
    try testing.expectError(error.Overflow, powi(u16, 2, 16));
    try testing.expectError(error.Overflow, powi(u32, 2, 32));
    try testing.expectError(error.Overflow, powi(u64, 2, 64));
    try testing.expectError(error.Overflow, powi(u17, 2, 17));
    try testing.expectError(error.Overflow, powi(u42, 2, 42));

    try testing.expect((try powi(u8, 6, 0)) == 1);
    try testing.expect((try powi(u16, 5, 0)) == 1);
    try testing.expect((try powi(u32, 12, 0)) == 1);
    try testing.expect((try powi(u64, 34, 0)) == 1);
    try testing.expect((try powi(u17, 16, 0)) == 1);
    try testing.expect((try powi(u42, 34, 0)) == 1);
}
