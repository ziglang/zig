// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std");
const builtin = std.builtin;
const crypto = std.crypto;
const debug = std.debug;
const mem = std.mem;
const meta = std.meta;

const fiat = @import("p256_64.zig");

const NonCanonicalError = crypto.errors.NonCanonicalError;
const NotSquareError = crypto.errors.NotSquareError;

const Limbs = fiat.Limbs;

/// A field element, internally stored in Montgomery domain.
pub const Fe = struct {
    limbs: Limbs,

    /// Field size.
    pub const field_order = 115792089210356248762697446949407573530086143415290314195533631308867097853951;

    /// Numer of bits that can be saturated without overflowing.
    pub const saturated_bits = 255;

    /// Zero.
    pub const zero: Fe = Fe{ .limbs = mem.zeroes(Limbs) };

    /// One.
    pub const one = comptime one: {
        var fe: Fe = undefined;
        fiat.p256SetOne(&fe.limbs);
        break :one fe;
    };

    /// Reject non-canonical encodings of an element.
    pub fn rejectNonCanonical(s_: [32]u8, endian: builtin.Endian) NonCanonicalError!void {
        var s = if (endian == .Little) s_ else orderSwap(s_);
        const field_order_s = comptime fos: {
            var fos: [32]u8 = undefined;
            mem.writeIntLittle(u256, &fos, field_order);
            break :fos fos;
        };
        if (crypto.utils.timingSafeCompare(u8, &s, &field_order_s, .Little) != .lt) {
            return error.NonCanonical;
        }
    }

    /// Swap the endianness of an encoded element.
    pub fn orderSwap(s: [32]u8) [32]u8 {
        var t = s;
        for (s) |x, i| t[t.len - 1 - i] = x;
        return t;
    }

    /// Unpack a field element.
    pub fn fromBytes(s_: [32]u8, endian: builtin.Endian) NonCanonicalError!Fe {
        var s = if (endian == .Little) s_ else orderSwap(s_);
        try rejectNonCanonical(s, .Little);
        var limbs_z: Limbs = undefined;
        fiat.p256FromBytes(&limbs_z, s);
        var limbs: Limbs = undefined;
        fiat.p256ToMontgomery(&limbs, limbs_z);
        return Fe{ .limbs = limbs };
    }

    /// Pack a field element.
    pub fn toBytes(fe: Fe, endian: builtin.Endian) [32]u8 {
        var limbs_z: Limbs = undefined;
        fiat.p256FromMontgomery(&limbs_z, fe.limbs);
        var s: [32]u8 = undefined;
        fiat.p256ToBytes(&s, limbs_z);
        return if (endian == .Little) s else orderSwap(s);
    }

    /// Create a field element from an integer.
    pub fn fromInt(comptime x: u256) NonCanonicalError!Fe {
        var s: [32]u8 = undefined;
        mem.writeIntLittle(u256, &s, x);
        return fromBytes(s, .Little);
    }

    /// Return the field element as an integer.
    pub fn toInt(fe: Fe) u256 {
        const s = fe.toBytes(.Little);
        return mem.readIntLittle(u256, &s);
    }

    /// Return true if the field element is zero.
    pub fn isZero(fe: Fe) bool {
        var z: @TypeOf(fe.limbs[0]) = undefined;
        fiat.p256Nonzero(&z, fe.limbs);
        return z == 0;
    }

    /// Return true if both field elements are equivalent.
    pub fn equivalent(a: Fe, b: Fe) bool {
        return a.sub(b).isZero();
    }

    /// Return true if the element is odd.
    pub fn isOdd(fe: Fe) bool {
        const s = fe.toBytes(.Little);
        return @truncate(u1, s[0]) != 0;
    }

    /// Conditonally replace a field element with `a` if `c` is positive.
    pub fn cMov(fe: *Fe, a: Fe, c: u1) void {
        fiat.p256Selectznz(&fe.limbs, c, fe.limbs, a.limbs);
    }

    /// Add field elements.
    pub fn add(a: Fe, b: Fe) Fe {
        var fe: Fe = undefined;
        fiat.p256Add(&fe.limbs, a.limbs, b.limbs);
        return fe;
    }

    /// Subtract field elements.
    pub fn sub(a: Fe, b: Fe) Fe {
        var fe: Fe = undefined;
        fiat.p256Sub(&fe.limbs, a.limbs, b.limbs);
        return fe;
    }

    /// Double a field element.
    pub fn dbl(a: Fe) Fe {
        var fe: Fe = undefined;
        fiat.p256Add(&fe.limbs, a.limbs, a.limbs);
        return fe;
    }

    /// Multiply field elements.
    pub fn mul(a: Fe, b: Fe) Fe {
        var fe: Fe = undefined;
        fiat.p256Mul(&fe.limbs, a.limbs, b.limbs);
        return fe;
    }

    /// Square a field element.
    pub fn sq(a: Fe) Fe {
        var fe: Fe = undefined;
        fiat.p256Square(&fe.limbs, a.limbs);
        return fe;
    }

    /// Square a field element n times.
    fn sqn(a: Fe, comptime n: comptime_int) Fe {
        var i: usize = 0;
        var fe = a;
        while (i < n) : (i += 1) {
            fe = fe.sq();
        }
        return fe;
    }

    /// Compute a^n.
    pub fn pow(a: Fe, comptime T: type, comptime n: T) Fe {
        var fe = one;
        var x: T = n;
        var t = a;
        while (true) {
            if (@truncate(u1, x) != 0) fe = fe.mul(t);
            x >>= 1;
            if (x == 0) break;
            t = t.sq();
        }
        return fe;
    }

    /// Negate a field element.
    pub fn neg(a: Fe) Fe {
        var fe: Fe = undefined;
        fiat.p256Opp(&fe.limbs, a.limbs);
        return fe;
    }

    /// Return the inverse of a field element, or 0 if a=0.
    // Field inversion from https://eprint.iacr.org/2021/549.pdf
    pub fn invert(a: Fe) Fe {
        const len_prime = 256;
        const iterations = (49 * len_prime + 57) / 17;
        const Word = @TypeOf(a.limbs[0]);
        const XLimbs = [a.limbs.len + 1]Word;

        var d: Word = 1;
        var f: XLimbs = undefined;
        fiat.p256Msat(&f);

        var g: XLimbs = undefined;
        fiat.p256FromMontgomery(g[0..a.limbs.len], a.limbs);
        g[g.len - 1] = 0;

        var r: Limbs = undefined;
        fiat.p256SetOne(&r);
        var v = mem.zeroes(Limbs);

        var precomp: Limbs = undefined;
        fiat.p256DivstepPrecomp(&precomp);

        var out1: Word = undefined;
        var out2: XLimbs = undefined;
        var out3: XLimbs = undefined;
        var out4: Limbs = undefined;
        var out5: Limbs = undefined;

        var i: usize = 0;
        while (i < iterations - iterations % 2) : (i += 2) {
            fiat.p256Divstep(&out1, &out2, &out3, &out4, &out5, d, f, g, v, r);
            fiat.p256Divstep(&d, &f, &g, &v, &r, out1, out2, out3, out4, out5);
        }
        if (iterations % 2 != 0) {
            fiat.p256Divstep(&out1, &out2, &out3, &out4, &out5, d, f, g, v, r);
            mem.copy(Word, &v, &out4);
            mem.copy(Word, &f, &out2);
        }
        var v_opp: Limbs = undefined;
        fiat.p256Opp(&v_opp, v);
        fiat.p256Selectznz(&v, @truncate(u1, f[f.len - 1] >> (meta.bitCount(Word) - 1)), v, v_opp);
        var fe: Fe = undefined;
        fiat.p256Mul(&fe.limbs, v, precomp);
        return fe;
    }

    /// Return true if the field element is a square.
    pub fn isSquare(x2: Fe) bool {
        const t110 = x2.mul(x2.sq()).sq();
        const t111 = x2.mul(t110);
        const t111111 = t111.mul(x2.mul(t110).sqn(3));
        const x15 = t111111.sqn(6).mul(t111111).sqn(3).mul(t111);
        const x16 = x15.sq().mul(x2);
        const x53 = x16.sqn(16).mul(x16).sqn(15);
        const x47 = x15.mul(x53);
        const ls = x47.mul(((x53.sqn(17).mul(x2)).sqn(143).mul(x47)).sqn(47)).sq().mul(x2); // Legendre symbol, (p-1)/2
        return ls.equivalent(Fe.one);
    }

    // x=x2^((field_order+1)/4) w/ field order=3 (mod 4).
    fn uncheckedSqrt(x2: Fe) Fe {
        comptime debug.assert(field_order % 4 == 3);
        const t11 = x2.mul(x2.sq());
        const t1111 = t11.mul(t11.sqn(2));
        const t11111111 = t1111.mul(t1111.sqn(4));
        const x16 = t11111111.sqn(8).mul(t11111111);
        return x16.sqn(16).mul(x16).sqn(32).mul(x2).sqn(96).mul(x2).sqn(94);
    }

    /// Compute the square root of `x2`, returning `error.NotSquare` if `x2` was not a square.
    pub fn sqrt(x2: Fe) NotSquareError!Fe {
        const x = x2.uncheckedSqrt();
        if (x.sq().equivalent(x2)) {
            return x;
        }
        return error.NotSquare;
    }
};
