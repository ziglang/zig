// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const readIntLittle = std.mem.readIntLittle;
const writeIntLittle = std.mem.writeIntLittle;

pub const Fe = struct {
    limbs: [5]u64,

    const MASK51: u64 = 0x7ffffffffffff;

    /// 0
    pub const zero = Fe{ .limbs = .{ 0, 0, 0, 0, 0 } };

    /// 1
    pub const one = Fe{ .limbs = .{ 1, 0, 0, 0, 0 } };

    /// sqrt(-1)
    pub const sqrtm1 = Fe{ .limbs = .{ 1718705420411056, 234908883556509, 2233514472574048, 2117202627021982, 765476049583133 } };

    /// The Curve25519 base point
    pub const curve25519BasePoint = Fe{ .limbs = .{ 9, 0, 0, 0, 0 } };

    /// Edwards25519 d = 37095705934669439343138083508754565189542113879843219016388785533085940283555
    pub const edwards25519d = Fe{ .limbs = .{ 929955233495203, 466365720129213, 1662059464998953, 2033849074728123, 1442794654840575 } };

    /// Edwards25519 2d
    pub const edwards25519d2 = Fe{ .limbs = .{ 1859910466990425, 932731440258426, 1072319116312658, 1815898335770999, 633789495995903 } };

    /// Edwards25519 1/sqrt(a-d)
    pub const edwards25519sqrtamd = Fe{ .limbs = .{ 278908739862762, 821645201101625, 8113234426968, 1777959178193151, 2118520810568447 } };

    /// Edwards25519 1-d^2
    pub const edwards25519eonemsqd = Fe{ .limbs = .{ 1136626929484150, 1998550399581263, 496427632559748, 118527312129759, 45110755273534 } };

    /// Edwards25519 (d-1)^2
    pub const edwards25519sqdmone = Fe{ .limbs = .{ 1507062230895904, 1572317787530805, 683053064812840, 317374165784489, 1572899562415810 } };

    /// Edwards25519 sqrt(ad-1) with a = -1 (mod p)
    pub const edwards25519sqrtadm1 = Fe{ .limbs = .{ 2241493124984347, 425987919032274, 2207028919301688, 1220490630685848, 974799131293748 } };

    /// Edwards25519 A, as a single limb
    pub const edwards25519a_32: u32 = 486662;

    /// Edwards25519 A
    pub const edwards25519a = Fe{ .limbs = .{ @as(u64, edwards25519a_32), 0, 0, 0, 0 } };

    /// Edwards25519 sqrt(A-2)
    pub const edwards25519sqrtam2 = Fe{ .limbs = .{ 1693982333959686, 608509411481997, 2235573344831311, 947681270984193, 266558006233600 } };

    /// Return true if the field element is zero
    pub inline fn isZero(fe: Fe) bool {
        var reduced = fe;
        reduced.reduce();
        const limbs = reduced.limbs;
        return (limbs[0] | limbs[1] | limbs[2] | limbs[3] | limbs[4]) == 0;
    }

    /// Return true if both field elements are equivalent
    pub inline fn equivalent(a: Fe, b: Fe) bool {
        return a.sub(b).isZero();
    }

    /// Unpack a field element
    pub fn fromBytes(s: [32]u8) Fe {
        var fe: Fe = undefined;
        fe.limbs[0] = readIntLittle(u64, s[0..8]) & MASK51;
        fe.limbs[1] = (readIntLittle(u64, s[6..14]) >> 3) & MASK51;
        fe.limbs[2] = (readIntLittle(u64, s[12..20]) >> 6) & MASK51;
        fe.limbs[3] = (readIntLittle(u64, s[19..27]) >> 1) & MASK51;
        fe.limbs[4] = (readIntLittle(u64, s[24..32]) >> 12) & MASK51;

        return fe;
    }

    /// Pack a field element
    pub fn toBytes(fe: Fe) [32]u8 {
        var reduced = fe;
        reduced.reduce();
        var s: [32]u8 = undefined;
        writeIntLittle(u64, s[0..8], reduced.limbs[0] | (reduced.limbs[1] << 51));
        writeIntLittle(u64, s[8..16], (reduced.limbs[1] >> 13) | (reduced.limbs[2] << 38));
        writeIntLittle(u64, s[16..24], (reduced.limbs[2] >> 26) | (reduced.limbs[3] << 25));
        writeIntLittle(u64, s[24..32], (reduced.limbs[3] >> 39) | (reduced.limbs[4] << 12));

        return s;
    }

    /// Map a 64-bit big endian string into a field element
    pub fn fromBytes64(s: [64]u8) Fe {
        var fl: [32]u8 = undefined;
        var gl: [32]u8 = undefined;
        var i: usize = 0;
        while (i < 32) : (i += 1) {
            fl[i] = s[63 - i];
            gl[i] = s[31 - i];
        }
        fl[31] &= 0x7f;
        gl[31] &= 0x7f;
        var fe_f = fromBytes(fl);
        const fe_g = fromBytes(gl);
        fe_f.limbs[0] += (s[32] >> 7) * 19;
        i = 0;
        while (i < 5) : (i += 1) {
            fe_f.limbs[i] += 38 * fe_g.limbs[i];
        }
        fe_f.reduce();
        return fe_f;
    }

    /// Reject non-canonical encodings of an element, possibly ignoring the top bit
    pub fn rejectNonCanonical(s: [32]u8, comptime ignore_extra_bit: bool) !void {
        var c: u16 = (s[31] & 0x7f) ^ 0x7f;
        comptime var i = 30;
        inline while (i > 0) : (i -= 1) {
            c |= s[i] ^ 0xff;
        }
        c = (c -% 1) >> 8;
        const d = (@as(u16, 0xed - 1) -% @as(u16, s[0])) >> 8;
        const x = if (ignore_extra_bit) 0 else s[31] >> 7;
        if ((((c & d) | x) & 1) != 0) {
            return error.NonCanonical;
        }
    }

    /// Reduce a field element mod 2^255-19
    fn reduce(fe: *Fe) void {
        comptime var i = 0;
        comptime var j = 0;
        const limbs = &fe.limbs;
        inline while (j < 2) : (j += 1) {
            i = 0;
            inline while (i < 4) : (i += 1) {
                limbs[i + 1] += limbs[i] >> 51;
                limbs[i] &= MASK51;
            }
            limbs[0] += 19 * (limbs[4] >> 51);
            limbs[4] &= MASK51;
        }
        limbs[0] += 19;
        i = 0;
        inline while (i < 4) : (i += 1) {
            limbs[i + 1] += limbs[i] >> 51;
            limbs[i] &= MASK51;
        }
        limbs[0] += 19 * (limbs[4] >> 51);
        limbs[4] &= MASK51;

        limbs[0] += 0x8000000000000 - 19;
        limbs[1] += 0x8000000000000 - 1;
        limbs[2] += 0x8000000000000 - 1;
        limbs[3] += 0x8000000000000 - 1;
        limbs[4] += 0x8000000000000 - 1;

        i = 0;
        inline while (i < 4) : (i += 1) {
            limbs[i + 1] += limbs[i] >> 51;
            limbs[i] &= MASK51;
        }
        limbs[4] &= MASK51;
    }

    /// Add a field element
    pub inline fn add(a: Fe, b: Fe) Fe {
        var fe: Fe = undefined;
        comptime var i = 0;
        inline while (i < 5) : (i += 1) {
            fe.limbs[i] = a.limbs[i] + b.limbs[i];
        }
        return fe;
    }

    /// Substract a field elememnt
    pub inline fn sub(a: Fe, b: Fe) Fe {
        var fe = b;
        comptime var i = 0;
        inline while (i < 4) : (i += 1) {
            fe.limbs[i + 1] += fe.limbs[i] >> 51;
            fe.limbs[i] &= MASK51;
        }
        fe.limbs[0] += 19 * (fe.limbs[4] >> 51);
        fe.limbs[4] &= MASK51;
        fe.limbs[0] = (a.limbs[0] + 0xfffffffffffda) - fe.limbs[0];
        fe.limbs[1] = (a.limbs[1] + 0xffffffffffffe) - fe.limbs[1];
        fe.limbs[2] = (a.limbs[2] + 0xffffffffffffe) - fe.limbs[2];
        fe.limbs[3] = (a.limbs[3] + 0xffffffffffffe) - fe.limbs[3];
        fe.limbs[4] = (a.limbs[4] + 0xffffffffffffe) - fe.limbs[4];

        return fe;
    }

    /// Negate a field element
    pub inline fn neg(a: Fe) Fe {
        return zero.sub(a);
    }

    /// Return true if a field element is negative
    pub inline fn isNegative(a: Fe) bool {
        return (a.toBytes()[0] & 1) != 0;
    }

    /// Conditonally replace a field element with `a` if `c` is positive
    pub inline fn cMov(fe: *Fe, a: Fe, c: u64) void {
        const mask: u64 = 0 -% c;
        var x = fe.*;
        comptime var i = 0;
        inline while (i < 5) : (i += 1) {
            x.limbs[i] ^= a.limbs[i];
        }
        i = 0;
        inline while (i < 5) : (i += 1) {
            x.limbs[i] &= mask;
        }
        i = 0;
        inline while (i < 5) : (i += 1) {
            fe.limbs[i] ^= x.limbs[i];
        }
    }

    /// Conditionally swap two pairs of field elements if `c` is positive
    pub fn cSwap2(a0: *Fe, b0: *Fe, a1: *Fe, b1: *Fe, c: u64) void {
        const mask: u64 = 0 -% c;
        var x0 = a0.*;
        var x1 = a1.*;
        comptime var i = 0;
        inline while (i < 5) : (i += 1) {
            x0.limbs[i] ^= b0.limbs[i];
            x1.limbs[i] ^= b1.limbs[i];
        }
        i = 0;
        inline while (i < 5) : (i += 1) {
            x0.limbs[i] &= mask;
            x1.limbs[i] &= mask;
        }
        i = 0;
        inline while (i < 5) : (i += 1) {
            a0.limbs[i] ^= x0.limbs[i];
            b0.limbs[i] ^= x0.limbs[i];
            a1.limbs[i] ^= x1.limbs[i];
            b1.limbs[i] ^= x1.limbs[i];
        }
    }

    inline fn _carry128(r: *[5]u128) Fe {
        var rs: [5]u64 = undefined;
        comptime var i = 0;
        inline while (i < 4) : (i += 1) {
            rs[i] = @truncate(u64, r[i]) & MASK51;
            r[i + 1] += @intCast(u64, r[i] >> 51);
        }
        rs[4] = @truncate(u64, r[4]) & MASK51;
        var carry = @intCast(u64, r[4] >> 51);
        rs[0] += 19 * carry;
        carry = rs[0] >> 51;
        rs[0] &= MASK51;
        rs[1] += carry;
        carry = rs[1] >> 51;
        rs[1] &= MASK51;
        rs[2] += carry;

        return .{ .limbs = rs };
    }

    /// Multiply two field elements
    pub inline fn mul(a: Fe, b: Fe) Fe {
        var ax: [5]u128 = undefined;
        var bx: [5]u128 = undefined;
        var a19: [5]u128 = undefined;
        var r: [5]u128 = undefined;
        comptime var i = 0;
        inline while (i < 5) : (i += 1) {
            ax[i] = @intCast(u128, a.limbs[i]);
            bx[i] = @intCast(u128, b.limbs[i]);
        }
        i = 1;
        inline while (i < 5) : (i += 1) {
            a19[i] = 19 * ax[i];
        }
        r[0] = ax[0] * bx[0] + a19[1] * bx[4] + a19[2] * bx[3] + a19[3] * bx[2] + a19[4] * bx[1];
        r[1] = ax[0] * bx[1] + ax[1] * bx[0] + a19[2] * bx[4] + a19[3] * bx[3] + a19[4] * bx[2];
        r[2] = ax[0] * bx[2] + ax[1] * bx[1] + ax[2] * bx[0] + a19[3] * bx[4] + a19[4] * bx[3];
        r[3] = ax[0] * bx[3] + ax[1] * bx[2] + ax[2] * bx[1] + ax[3] * bx[0] + a19[4] * bx[4];
        r[4] = ax[0] * bx[4] + ax[1] * bx[3] + ax[2] * bx[2] + ax[3] * bx[1] + ax[4] * bx[0];

        return _carry128(&r);
    }

    inline fn _sq(a: Fe, double: comptime bool) Fe {
        var ax: [5]u128 = undefined;
        var r: [5]u128 = undefined;
        comptime var i = 0;
        inline while (i < 5) : (i += 1) {
            ax[i] = @intCast(u128, a.limbs[i]);
        }
        const a0_2 = 2 * ax[0];
        const a1_2 = 2 * ax[1];
        const a1_38 = 38 * ax[1];
        const a2_38 = 38 * ax[2];
        const a3_38 = 38 * ax[3];
        const a3_19 = 19 * ax[3];
        const a4_19 = 19 * ax[4];
        r[0] = ax[0] * ax[0] + a1_38 * ax[4] + a2_38 * ax[3];
        r[1] = a0_2 * ax[1] + a2_38 * ax[4] + a3_19 * ax[3];
        r[2] = a0_2 * ax[2] + ax[1] * ax[1] + a3_38 * ax[4];
        r[3] = a0_2 * ax[3] + a1_2 * ax[2] + a4_19 * ax[4];
        r[4] = a0_2 * ax[4] + a1_2 * ax[3] + ax[2] * ax[2];
        if (double) {
            i = 0;
            inline while (i < 5) : (i += 1) {
                r[i] *= 2;
            }
        }
        return _carry128(&r);
    }

    /// Square a field element
    pub inline fn sq(a: Fe) Fe {
        return _sq(a, false);
    }

    /// Square and double a field element
    pub inline fn sq2(a: Fe) Fe {
        return _sq(a, true);
    }

    /// Multiply a field element with a small (32-bit) integer
    pub inline fn mul32(a: Fe, comptime n: u32) Fe {
        const sn = @intCast(u128, n);
        var fe: Fe = undefined;
        var x: u128 = 0;
        comptime var i = 0;
        inline while (i < 5) : (i += 1) {
            x = a.limbs[i] * sn + (x >> 51);
            fe.limbs[i] = @truncate(u64, x) & MASK51;
        }
        fe.limbs[0] += @intCast(u64, x >> 51) * 19;

        return fe;
    }

    /// Square a field element `n` times
    inline fn sqn(a: Fe, comptime n: comptime_int) Fe {
        var i: usize = 0;
        var fe = a;
        while (i < n) : (i += 1) {
            fe = fe.sq();
        }
        return fe;
    }

    /// Compute the inverse of a field element
    pub fn invert(a: Fe) Fe {
        var t0 = a.sq();
        var t1 = t0.sqn(2).mul(a);
        t0 = t0.mul(t1);
        t1 = t1.mul(t0.sq());
        t1 = t1.mul(t1.sqn(5));
        var t2 = t1.sqn(10).mul(t1);
        t2 = t2.mul(t2.sqn(20)).sqn(10);
        t1 = t1.mul(t2);
        t2 = t1.sqn(50).mul(t1);
        return t1.mul(t2.mul(t2.sqn(100)).sqn(50)).sqn(5).mul(t0);
    }

    /// Return a^((p-5)/8) = a^(2^252-3)
    /// Used to compute square roots since we have p=5 (mod 8); see Cohen and Frey.
    pub fn pow2523(a: Fe) Fe {
        var t0 = a.mul(a.sq());
        var t1 = t0.mul(t0.sqn(2)).sq().mul(a);
        t0 = t1.sqn(5).mul(t1);
        var t2 = t0.sqn(5).mul(t1);
        t1 = t2.sqn(15).mul(t2);
        t2 = t1.sqn(30).mul(t1);
        t1 = t2.sqn(60).mul(t2);
        return t1.sqn(120).mul(t1).sqn(10).mul(t0).sqn(2).mul(a);
    }

    /// Return the absolute value of a field element
    pub fn abs(a: Fe) Fe {
        var r = a;
        r.cMov(a.neg(), @boolToInt(a.isNegative()));
        return r;
    }

    /// Return true if the field element is a square
    pub fn isSquare(a: Fe) bool {
        // Compute the Jacobi symbol x^((p-1)/2)
        const _11 = a.mul(a.sq());
        const _1111 = _11.mul(_11.sq().sq());
        const _11111111 = _1111.mul(_1111.sq().sq().sq().sq());
        var t = _11111111.sqn(2).mul(_11);
        const u = t;
        t = t.sqn(10).mul(u).sqn(10).mul(u);
        t = t.sqn(30).mul(t);
        t = t.sqn(60).mul(t);
        t = t.sqn(120).mul(t).sqn(10).mul(u).sqn(3).mul(_11).sq();
        return @bitCast(bool, @truncate(u1, ~(t.toBytes()[1] & 1)));
    }

    fn uncheckedSqrt(x2: Fe) Fe {
        var e = x2.pow2523();
        const p_root = e.mul(x2); // positive root
        const m_root = p_root.mul(Fe.sqrtm1); // negative root
        const m_root2 = m_root.sq();
        e = x2.sub(m_root2);
        var x = p_root;
        x.cMov(m_root, @boolToInt(e.isZero()));
        return x;
    }

    /// Compute the square root of `x2`, returning `error.NotSquare` if `x2` was not a square
    pub fn sqrt(x2: Fe) !Fe {
        var x2_copy = x2;
        const x = x2.uncheckedSqrt();
        const check = x.sq().sub(x2_copy);
        if (check.isZero()) {
            return x;
        }
        return error.NotSquare;
    }
};
