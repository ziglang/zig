// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/divdf3.c

const std = @import("std");
const builtin = @import("builtin");

pub fn __divdf3(a: f64, b: f64) callconv(.C) f64 {
    @setRuntimeSafety(builtin.is_test);
    const Z = std.meta.Int(false, 64);
    const SignedZ = std.meta.Int(true, 64);

    const significandBits = std.math.floatMantissaBits(f64);
    const exponentBits = std.math.floatExponentBits(f64);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);
    const exponentBias = (maxExponent >> 1);

    const implicitBit = (@as(Z, 1) << significandBits);
    const quietBit = implicitBit >> 1;
    const significandMask = implicitBit - 1;

    const absMask = signBit - 1;
    const exponentMask = absMask ^ significandMask;
    const qnanRep = exponentMask | quietBit;
    const infRep = @bitCast(Z, std.math.inf(f64));

    const aExponent = @truncate(u32, (@bitCast(Z, a) >> significandBits) & maxExponent);
    const bExponent = @truncate(u32, (@bitCast(Z, b) >> significandBits) & maxExponent);
    const quotientSign: Z = (@bitCast(Z, a) ^ @bitCast(Z, b)) & signBit;

    var aSignificand: Z = @bitCast(Z, a) & significandMask;
    var bSignificand: Z = @bitCast(Z, b) & significandMask;
    var scale: i32 = 0;

    // Detect if a or b is zero, denormal, infinity, or NaN.
    if (aExponent -% 1 >= maxExponent -% 1 or bExponent -% 1 >= maxExponent -% 1) {
        const aAbs: Z = @bitCast(Z, a) & absMask;
        const bAbs: Z = @bitCast(Z, b) & absMask;

        // NaN / anything = qNaN
        if (aAbs > infRep) return @bitCast(f64, @bitCast(Z, a) | quietBit);
        // anything / NaN = qNaN
        if (bAbs > infRep) return @bitCast(f64, @bitCast(Z, b) | quietBit);

        if (aAbs == infRep) {
            // infinity / infinity = NaN
            if (bAbs == infRep) {
                return @bitCast(f64, qnanRep);
            }
            // infinity / anything else = +/- infinity
            else {
                return @bitCast(f64, aAbs | quotientSign);
            }
        }

        // anything else / infinity = +/- 0
        if (bAbs == infRep) return @bitCast(f64, quotientSign);

        if (aAbs == 0) {
            // zero / zero = NaN
            if (bAbs == 0) {
                return @bitCast(f64, qnanRep);
            }
            // zero / anything else = +/- zero
            else {
                return @bitCast(f64, quotientSign);
            }
        }
        // anything else / zero = +/- infinity
        if (bAbs == 0) return @bitCast(f64, infRep | quotientSign);

        // one or both of a or b is denormal, the other (if applicable) is a
        // normal number.  Renormalize one or both of a and b, and set scale to
        // include the necessary exponent adjustment.
        if (aAbs < implicitBit) scale +%= normalize(f64, &aSignificand);
        if (bAbs < implicitBit) scale -%= normalize(f64, &bSignificand);
    }

    // Or in the implicit significand bit.  (If we fell through from the
    // denormal path it was already set by normalize( ), but setting it twice
    // won't hurt anything.)
    aSignificand |= implicitBit;
    bSignificand |= implicitBit;
    var quotientExponent: i32 = @bitCast(i32, aExponent -% bExponent) +% scale;

    // Align the significand of b as a Q31 fixed-point number in the range
    // [1, 2.0) and get a Q32 approximate reciprocal using a small minimax
    // polynomial approximation: reciprocal = 3/4 + 1/sqrt(2) - b/2.  This
    // is accurate to about 3.5 binary digits.
    const q31b: u32 = @truncate(u32, bSignificand >> 21);
    var recip32 = @as(u32, 0x7504f333) -% q31b;

    // Now refine the reciprocal estimate using a Newton-Raphson iteration:
    //
    //     x1 = x0 * (2 - x0 * b)
    //
    // This doubles the number of correct binary digits in the approximation
    // with each iteration, so after three iterations, we have about 28 binary
    // digits of accuracy.
    var correction32: u32 = undefined;
    correction32 = @truncate(u32, ~(@as(u64, recip32) *% q31b >> 32) +% 1);
    recip32 = @truncate(u32, @as(u64, recip32) *% correction32 >> 31);
    correction32 = @truncate(u32, ~(@as(u64, recip32) *% q31b >> 32) +% 1);
    recip32 = @truncate(u32, @as(u64, recip32) *% correction32 >> 31);
    correction32 = @truncate(u32, ~(@as(u64, recip32) *% q31b >> 32) +% 1);
    recip32 = @truncate(u32, @as(u64, recip32) *% correction32 >> 31);

    // recip32 might have overflowed to exactly zero in the preceding
    // computation if the high word of b is exactly 1.0.  This would sabotage
    // the full-width final stage of the computation that follows, so we adjust
    // recip32 downward by one bit.
    recip32 -%= 1;

    // We need to perform one more iteration to get us to 56 binary digits;
    // The last iteration needs to happen with extra precision.
    const q63blo: u32 = @truncate(u32, bSignificand << 11);
    var correction: u64 = undefined;
    var reciprocal: u64 = undefined;
    correction = ~(@as(u64, recip32) *% q31b +% (@as(u64, recip32) *% q63blo >> 32)) +% 1;
    const cHi = @truncate(u32, correction >> 32);
    const cLo = @truncate(u32, correction);
    reciprocal = @as(u64, recip32) *% cHi +% (@as(u64, recip32) *% cLo >> 32);

    // We already adjusted the 32-bit estimate, now we need to adjust the final
    // 64-bit reciprocal estimate downward to ensure that it is strictly smaller
    // than the infinitely precise exact reciprocal.  Because the computation
    // of the Newton-Raphson step is truncating at every step, this adjustment
    // is small; most of the work is already done.
    reciprocal -%= 2;

    // The numerical reciprocal is accurate to within 2^-56, lies in the
    // interval [0.5, 1.0), and is strictly smaller than the true reciprocal
    // of b.  Multiplying a by this reciprocal thus gives a numerical q = a/b
    // in Q53 with the following properties:
    //
    //    1. q < a/b
    //    2. q is in the interval [0.5, 2.0)
    //    3. the error in q is bounded away from 2^-53 (actually, we have a
    //       couple of bits to spare, but this is all we need).

    // We need a 64 x 64 multiply high to compute q, which isn't a basic
    // operation in C, so we need to be a little bit fussy.
    var quotient: Z = undefined;
    var quotientLo: Z = undefined;
    wideMultiply(Z, aSignificand << 2, reciprocal, &quotient, &quotientLo);

    // Two cases: quotient is in [0.5, 1.0) or quotient is in [1.0, 2.0).
    // In either case, we are going to compute a residual of the form
    //
    //     r = a - q*b
    //
    // We know from the construction of q that r satisfies:
    //
    //     0 <= r < ulp(q)*b
    //
    // if r is greater than 1/2 ulp(q)*b, then q rounds up.  Otherwise, we
    // already have the correct result.  The exact halfway case cannot occur.
    // We also take this time to right shift quotient if it falls in the [1,2)
    // range and adjust the exponent accordingly.
    var residual: Z = undefined;
    if (quotient < (implicitBit << 1)) {
        residual = (aSignificand << 53) -% quotient *% bSignificand;
        quotientExponent -%= 1;
    } else {
        quotient >>= 1;
        residual = (aSignificand << 52) -% quotient *% bSignificand;
    }

    const writtenExponent = quotientExponent +% exponentBias;

    if (writtenExponent >= maxExponent) {
        // If we have overflowed the exponent, return infinity.
        return @bitCast(f64, infRep | quotientSign);
    } else if (writtenExponent < 1) {
        if (writtenExponent == 0) {
            // Check whether the rounded result is normal.
            const round = @boolToInt((residual << 1) > bSignificand);
            // Clear the implicit bit.
            var absResult = quotient & significandMask;
            // Round.
            absResult += round;
            if ((absResult & ~significandMask) != 0) {
                // The rounded result is normal; return it.
                return @bitCast(f64, absResult | quotientSign);
            }
        }
        // Flush denormals to zero.  In the future, it would be nice to add
        // code to round them correctly.
        return @bitCast(f64, quotientSign);
    } else {
        const round = @boolToInt((residual << 1) > bSignificand);
        // Clear the implicit bit
        var absResult = quotient & significandMask;
        // Insert the exponent
        absResult |= @bitCast(Z, @as(SignedZ, writtenExponent)) << significandBits;
        // Round
        absResult +%= round;
        // Insert the sign and return
        return @bitCast(f64, absResult | quotientSign);
    }
}

pub fn wideMultiply(comptime Z: type, a: Z, b: Z, hi: *Z, lo: *Z) void {
    @setRuntimeSafety(builtin.is_test);
    switch (Z) {
        u32 => {
            // 32x32 --> 64 bit multiply
            const product = @as(u64, a) * @as(u64, b);
            hi.* = @truncate(u32, product >> 32);
            lo.* = @truncate(u32, product);
        },
        u64 => {
            const S = struct {
                fn loWord(x: u64) u64 {
                    return @truncate(u32, x);
                }
                fn hiWord(x: u64) u64 {
                    return @truncate(u32, x >> 32);
                }
            };
            // 64x64 -> 128 wide multiply for platforms that don't have such an operation;
            // many 64-bit platforms have this operation, but they tend to have hardware
            // floating-point, so we don't bother with a special case for them here.
            // Each of the component 32x32 -> 64 products
            const plolo: u64 = S.loWord(a) * S.loWord(b);
            const plohi: u64 = S.loWord(a) * S.hiWord(b);
            const philo: u64 = S.hiWord(a) * S.loWord(b);
            const phihi: u64 = S.hiWord(a) * S.hiWord(b);
            // Sum terms that contribute to lo in a way that allows us to get the carry
            const r0: u64 = S.loWord(plolo);
            const r1: u64 = S.hiWord(plolo) +% S.loWord(plohi) +% S.loWord(philo);
            lo.* = r0 +% (r1 << 32);
            // Sum terms contributing to hi with the carry from lo
            hi.* = S.hiWord(plohi) +% S.hiWord(philo) +% S.hiWord(r1) +% phihi;
        },
        u128 => {
            const Word_LoMask = @as(u64, 0x00000000ffffffff);
            const Word_HiMask = @as(u64, 0xffffffff00000000);
            const Word_FullMask = @as(u64, 0xffffffffffffffff);
            const S = struct {
                fn Word_1(x: u128) u64 {
                    return @truncate(u32, x >> 96);
                }
                fn Word_2(x: u128) u64 {
                    return @truncate(u32, x >> 64);
                }
                fn Word_3(x: u128) u64 {
                    return @truncate(u32, x >> 32);
                }
                fn Word_4(x: u128) u64 {
                    return @truncate(u32, x);
                }
            };
            // 128x128 -> 256 wide multiply for platforms that don't have such an operation;
            // many 64-bit platforms have this operation, but they tend to have hardware
            // floating-point, so we don't bother with a special case for them here.

            const product11: u64 = S.Word_1(a) * S.Word_1(b);
            const product12: u64 = S.Word_1(a) * S.Word_2(b);
            const product13: u64 = S.Word_1(a) * S.Word_3(b);
            const product14: u64 = S.Word_1(a) * S.Word_4(b);
            const product21: u64 = S.Word_2(a) * S.Word_1(b);
            const product22: u64 = S.Word_2(a) * S.Word_2(b);
            const product23: u64 = S.Word_2(a) * S.Word_3(b);
            const product24: u64 = S.Word_2(a) * S.Word_4(b);
            const product31: u64 = S.Word_3(a) * S.Word_1(b);
            const product32: u64 = S.Word_3(a) * S.Word_2(b);
            const product33: u64 = S.Word_3(a) * S.Word_3(b);
            const product34: u64 = S.Word_3(a) * S.Word_4(b);
            const product41: u64 = S.Word_4(a) * S.Word_1(b);
            const product42: u64 = S.Word_4(a) * S.Word_2(b);
            const product43: u64 = S.Word_4(a) * S.Word_3(b);
            const product44: u64 = S.Word_4(a) * S.Word_4(b);

            const sum0: u128 = @as(u128, product44);
            const sum1: u128 = @as(u128, product34) +%
                @as(u128, product43);
            const sum2: u128 = @as(u128, product24) +%
                @as(u128, product33) +%
                @as(u128, product42);
            const sum3: u128 = @as(u128, product14) +%
                @as(u128, product23) +%
                @as(u128, product32) +%
                @as(u128, product41);
            const sum4: u128 = @as(u128, product13) +%
                @as(u128, product22) +%
                @as(u128, product31);
            const sum5: u128 = @as(u128, product12) +%
                @as(u128, product21);
            const sum6: u128 = @as(u128, product11);

            const r0: u128 = (sum0 & Word_FullMask) +%
                ((sum1 & Word_LoMask) << 32);
            const r1: u128 = (sum0 >> 64) +%
                ((sum1 >> 32) & Word_FullMask) +%
                (sum2 & Word_FullMask) +%
                ((sum3 << 32) & Word_HiMask);

            lo.* = r0 +% (r1 << 64);
            hi.* = (r1 >> 64) +%
                (sum1 >> 96) +%
                (sum2 >> 64) +%
                (sum3 >> 32) +%
                sum4 +%
                (sum5 << 32) +%
                (sum6 << 64);
        },
        else => @compileError("unsupported"),
    }
}

pub fn normalize(comptime T: type, significand: *std.meta.Int(false, @typeInfo(T).Float.bits)) i32 {
    @setRuntimeSafety(builtin.is_test);
    const Z = std.meta.Int(false, @typeInfo(T).Float.bits);
    const significandBits = std.math.floatMantissaBits(T);
    const implicitBit = @as(Z, 1) << significandBits;

    const shift = @clz(Z, significand.*) - @clz(Z, implicitBit);
    significand.* <<= @intCast(std.math.Log2Int(Z), shift);
    return 1 - shift;
}

pub fn __aeabi_ddiv(a: f64, b: f64) callconv(.AAPCS) f64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __divdf3, .{ a, b });
}

test "import divdf3" {
    _ = @import("divdf3_test.zig");
}
