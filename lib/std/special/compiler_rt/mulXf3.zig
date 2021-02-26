// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// Ported from:
//
// https://github.com/llvm/llvm-project/blob/2ffb1b0413efa9a24eb3c49e710e36f92e2cb50b/compiler-rt/lib/builtins/fp_mul_impl.inc

const std = @import("std");
const builtin = @import("builtin");
const compiler_rt = @import("../compiler_rt.zig");

pub fn __multf3(a: f128, b: f128) callconv(.C) f128 {
    return mulXf3(f128, a, b);
}
pub fn __muldf3(a: f64, b: f64) callconv(.C) f64 {
    return mulXf3(f64, a, b);
}
pub fn __mulsf3(a: f32, b: f32) callconv(.C) f32 {
    return mulXf3(f32, a, b);
}

pub fn __aeabi_fmul(a: f32, b: f32) callconv(.C) f32 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __mulsf3, .{ a, b });
}

pub fn __aeabi_dmul(a: f64, b: f64) callconv(.C) f64 {
    @setRuntimeSafety(false);
    return @call(.{ .modifier = .always_inline }, __muldf3, .{ a, b });
}

fn mulXf3(comptime T: type, a: T, b: T) T {
    @setRuntimeSafety(builtin.is_test);
    const typeWidth = @typeInfo(T).Float.bits;
    const Z = std.meta.Int(.unsigned, typeWidth);

    const significandBits = std.math.floatMantissaBits(T);
    const exponentBits = std.math.floatExponentBits(T);

    const signBit = (@as(Z, 1) << (significandBits + exponentBits));
    const maxExponent = ((1 << exponentBits) - 1);
    const exponentBias = (maxExponent >> 1);

    const implicitBit = (@as(Z, 1) << significandBits);
    const quietBit = implicitBit >> 1;
    const significandMask = implicitBit - 1;

    const absMask = signBit - 1;
    const exponentMask = absMask ^ significandMask;
    const qnanRep = exponentMask | quietBit;
    const infRep = @bitCast(Z, std.math.inf(T));

    const aExponent = @truncate(u32, (@bitCast(Z, a) >> significandBits) & maxExponent);
    const bExponent = @truncate(u32, (@bitCast(Z, b) >> significandBits) & maxExponent);
    const productSign: Z = (@bitCast(Z, a) ^ @bitCast(Z, b)) & signBit;

    var aSignificand: Z = @bitCast(Z, a) & significandMask;
    var bSignificand: Z = @bitCast(Z, b) & significandMask;
    var scale: i32 = 0;

    // Detect if a or b is zero, denormal, infinity, or NaN.
    if (aExponent -% 1 >= maxExponent -% 1 or bExponent -% 1 >= maxExponent -% 1) {
        const aAbs: Z = @bitCast(Z, a) & absMask;
        const bAbs: Z = @bitCast(Z, b) & absMask;

        // NaN * anything = qNaN
        if (aAbs > infRep) return @bitCast(T, @bitCast(Z, a) | quietBit);
        // anything * NaN = qNaN
        if (bAbs > infRep) return @bitCast(T, @bitCast(Z, b) | quietBit);

        if (aAbs == infRep) {
            // infinity * non-zero = +/- infinity
            if (bAbs != 0) {
                return @bitCast(T, aAbs | productSign);
            } else {
                // infinity * zero = NaN
                return @bitCast(T, qnanRep);
            }
        }

        if (bAbs == infRep) {
            //? non-zero * infinity = +/- infinity
            if (aAbs != 0) {
                return @bitCast(T, bAbs | productSign);
            } else {
                // zero * infinity = NaN
                return @bitCast(T, qnanRep);
            }
        }

        // zero * anything = +/- zero
        if (aAbs == 0) return @bitCast(T, productSign);
        // anything * zero = +/- zero
        if (bAbs == 0) return @bitCast(T, productSign);

        // one or both of a or b is denormal, the other (if applicable) is a
        // normal number.  Renormalize one or both of a and b, and set scale to
        // include the necessary exponent adjustment.
        if (aAbs < implicitBit) scale +%= normalize(T, &aSignificand);
        if (bAbs < implicitBit) scale +%= normalize(T, &bSignificand);
    }

    // Or in the implicit significand bit.  (If we fell through from the
    // denormal path it was already set by normalize( ), but setting it twice
    // won't hurt anything.)
    aSignificand |= implicitBit;
    bSignificand |= implicitBit;

    // Get the significand of a*b.  Before multiplying the significands, shift
    // one of them left to left-align it in the field.  Thus, the product will
    // have (exponentBits + 2) integral digits, all but two of which must be
    // zero.  Normalizing this result is just a conditional left-shift by one
    // and bumping the exponent accordingly.
    var productHi: Z = undefined;
    var productLo: Z = undefined;
    wideMultiply(Z, aSignificand, bSignificand << exponentBits, &productHi, &productLo);

    var productExponent: i32 = @bitCast(i32, aExponent +% bExponent) -% exponentBias +% scale;

    // Normalize the significand, adjust exponent if needed.
    if ((productHi & implicitBit) != 0) {
        productExponent +%= 1;
    } else {
        productHi = (productHi << 1) | (productLo >> (typeWidth - 1));
        productLo = productLo << 1;
    }

    // If we have overflowed the type, return +/- infinity.
    if (productExponent >= maxExponent) return @bitCast(T, infRep | productSign);

    if (productExponent <= 0) {
        // Result is denormal before rounding
        //
        // If the result is so small that it just underflows to zero, return
        // a zero of the appropriate sign.  Mathematically there is no need to
        // handle this case separately, but we make it a special case to
        // simplify the shift logic.
        const shift: u32 = @truncate(u32, @as(Z, 1) -% @bitCast(u32, productExponent));
        if (shift >= typeWidth) return @bitCast(T, productSign);

        // Otherwise, shift the significand of the result so that the round
        // bit is the high bit of productLo.
        wideRightShiftWithSticky(Z, &productHi, &productLo, shift);
    } else {
        // Result is normal before rounding; insert the exponent.
        productHi &= significandMask;
        productHi |= @as(Z, @bitCast(u32, productExponent)) << significandBits;
    }

    // Insert the sign of the result:
    productHi |= productSign;

    // Final rounding.  The final result may overflow to infinity, or underflow
    // to zero, but those are the correct results in those cases.  We use the
    // default IEEE-754 round-to-nearest, ties-to-even rounding mode.
    if (productLo > signBit) productHi +%= 1;
    if (productLo == signBit) productHi +%= productHi & 1;
    return @bitCast(T, productHi);
}

fn wideMultiply(comptime Z: type, a: Z, b: Z, hi: *Z, lo: *Z) void {
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

fn normalize(comptime T: type, significand: *std.meta.Int(.unsigned, @typeInfo(T).Float.bits)) i32 {
    @setRuntimeSafety(builtin.is_test);
    const Z = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);
    const significandBits = std.math.floatMantissaBits(T);
    const implicitBit = @as(Z, 1) << significandBits;

    const shift = @clz(Z, significand.*) - @clz(Z, implicitBit);
    significand.* <<= @intCast(std.math.Log2Int(Z), shift);
    return 1 - shift;
}

fn wideRightShiftWithSticky(comptime Z: type, hi: *Z, lo: *Z, count: u32) void {
    @setRuntimeSafety(builtin.is_test);
    const typeWidth = @typeInfo(Z).Int.bits;
    const S = std.math.Log2Int(Z);
    if (count < typeWidth) {
        const sticky = @truncate(u8, lo.* << @intCast(S, typeWidth -% count));
        lo.* = (hi.* << @intCast(S, typeWidth -% count)) | (lo.* >> @intCast(S, count)) | sticky;
        hi.* = hi.* >> @intCast(S, count);
    } else if (count < 2 * typeWidth) {
        const sticky = @truncate(u8, hi.* << @intCast(S, 2 * typeWidth -% count) | lo.*);
        lo.* = hi.* >> @intCast(S, count -% typeWidth) | sticky;
        hi.* = 0;
    } else {
        const sticky = @truncate(u8, hi.* | lo.*);
        lo.* = sticky;
        hi.* = 0;
    }
}

test "import mulXf3" {
    _ = @import("mulXf3_test.zig");
}
