// Translated from monocypher which is licensed under CC-0/BSD-3.
//
// https://monocypher.org/

const std = @import("../std.zig");
const builtin = @import("builtin");
const fmt = std.fmt;

const Endian = builtin.Endian;
const readIntLittle = std.mem.readIntLittle;
const writeIntLittle = std.mem.writeIntLittle;

// Based on Supercop's ref10 implementation.
pub const X25519 = struct {
    pub const secret_length = 32;
    pub const minimum_key_length = 32;

    fn trimScalar(s: []u8) void {
        s[0] &= 248;
        s[31] &= 127;
        s[31] |= 64;
    }

    fn scalarBit(s: []const u8, i: usize) i32 {
        return (s[i >> 3] >> @intCast(u3, i & 7)) & 1;
    }

    pub fn create(out: []u8, private_key: []const u8, public_key: []const u8) bool {
        std.debug.assert(out.len >= secret_length);
        std.debug.assert(private_key.len >= minimum_key_length);
        std.debug.assert(public_key.len >= minimum_key_length);

        var storage: [7]Fe = undefined;
        var x1 = &storage[0];
        var x2 = &storage[1];
        var z2 = &storage[2];
        var x3 = &storage[3];
        var z3 = &storage[4];
        var t0 = &storage[5];
        var t1 = &storage[6];

        // computes the scalar product
        Fe.fromBytes(x1, public_key);

        // restrict the possible scalar values
        var e: [32]u8 = undefined;
        for (e[0..]) |_, i| {
            e[i] = private_key[i];
        }
        trimScalar(e[0..]);

        // computes the actual scalar product (the result is in x2 and z2)

        // Montgomery ladder
        // In projective coordinates, to avoid divisions: x = X / Z
        // We don't care about the y coordinate, it's only 1 bit of information
        Fe.init1(x2);
        Fe.init0(z2); // "zero" point
        Fe.copy(x3, x1);
        Fe.init1(z3);

        var swap: i32 = 0;
        var pos: isize = 254;
        while (pos >= 0) : (pos -= 1) {
            // constant time conditional swap before ladder step
            const b = scalarBit(&e, @intCast(usize, pos));
            swap ^= b; // xor trick avoids swapping at the end of the loop
            Fe.cswap(x2, x3, swap);
            Fe.cswap(z2, z3, swap);
            swap = b; // anticipates one last swap after the loop

            // Montgomery ladder step: replaces (P2, P3) by (P2*2, P2+P3)
            // with differential addition
            Fe.sub(t0, x3, z3);
            Fe.sub(t1, x2, z2);
            Fe.add(x2, x2, z2);
            Fe.add(z2, x3, z3);
            Fe.mul(z3, t0, x2);
            Fe.mul(z2, z2, t1);
            Fe.sq(t0, t1);
            Fe.sq(t1, x2);
            Fe.add(x3, z3, z2);
            Fe.sub(z2, z3, z2);
            Fe.mul(x2, t1, t0);
            Fe.sub(t1, t1, t0);
            Fe.sq(z2, z2);
            Fe.mulSmall(z3, t1, 121666);
            Fe.sq(x3, x3);
            Fe.add(t0, t0, z3);
            Fe.mul(z3, x1, z2);
            Fe.mul(z2, t1, t0);
        }

        // last swap is necessary to compensate for the xor trick
        // Note: after this swap, P3 == P2 + P1.
        Fe.cswap(x2, x3, swap);
        Fe.cswap(z2, z3, swap);

        // normalises the coordinates: x == X / Z
        Fe.invert(z2, z2);
        Fe.mul(x2, x2, z2);
        Fe.toBytes(out, x2);

        x1.secureZero();
        x2.secureZero();
        x3.secureZero();
        t0.secureZero();
        t1.secureZero();
        z2.secureZero();
        z3.secureZero();
        std.mem.secureZero(u8, e[0..]);

        // Returns false if the output is all zero
        // (happens with some malicious public keys)
        return !zerocmp(u8, out);
    }

    pub fn createPublicKey(public_key: []u8, private_key: []const u8) bool {
        var base_point = [_]u8{9} ++ [_]u8{0} ** 31;
        return create(public_key, private_key, &base_point);
    }
};

// Constant time compare to zero.
fn zerocmp(comptime T: type, a: []const T) bool {
    var s: T = 0;
    for (a) |b| {
        s |= b;
    }
    return s == 0;
}

////////////////////////////////////
/// Arithmetic modulo 2^255 - 19 ///
////////////////////////////////////
//  Taken from Supercop's ref10 implementation.
//  A bit bigger than TweetNaCl, over 4 times faster.

// field element
const Fe = struct {
    b: [10]i32,

    fn secureZero(self: *Fe) void {
        std.mem.secureZero(u8, @ptrCast([*]u8, self)[0..@sizeOf(Fe)]);
    }

    fn init0(h: *Fe) void {
        for (h.b) |*e| {
            e.* = 0;
        }
    }

    fn init1(h: *Fe) void {
        for (h.b[1..]) |*e| {
            e.* = 0;
        }
        h.b[0] = 1;
    }

    fn copy(h: *Fe, f: *const Fe) void {
        for (h.b) |_, i| {
            h.b[i] = f.b[i];
        }
    }

    fn neg(h: *Fe, f: *const Fe) void {
        for (h.b) |_, i| {
            h.b[i] = -f.b[i];
        }
    }

    fn add(h: *Fe, f: *const Fe, g: *const Fe) void {
        for (h.b) |_, i| {
            h.b[i] = f.b[i] + g.b[i];
        }
    }

    fn sub(h: *Fe, f: *const Fe, g: *const Fe) void {
        for (h.b) |_, i| {
            h.b[i] = f.b[i] - g.b[i];
        }
    }

    fn cswap(f: *Fe, g: *Fe, b: i32) void {
        for (f.b) |_, i| {
            const x = (f.b[i] ^ g.b[i]) & -b;
            f.b[i] ^= x;
            g.b[i] ^= x;
        }
    }

    fn ccopy(f: *Fe, g: *const Fe, b: i32) void {
        for (f.b) |_, i| {
            const x = (f.b[i] ^ g.b[i]) & -b;
            f.b[i] ^= x;
        }
    }

    inline fn carryRound(c: []i64, t: []i64, comptime i: comptime_int, comptime shift: comptime_int, comptime mult: comptime_int) void {
        const j = (i + 1) % 10;

        c[i] = (t[i] + (@as(i64, 1) << shift)) >> (shift + 1);
        t[j] += c[i] * mult;
        t[i] -= c[i] * (@as(i64, 1) << (shift + 1));
    }

    fn carry1(h: *Fe, t: []i64) void {
        var c: [10]i64 = undefined;

        var sc = c[0..];
        var st = t[0..];

        carryRound(sc, st, 9, 24, 19);
        carryRound(sc, st, 1, 24, 1);
        carryRound(sc, st, 3, 24, 1);
        carryRound(sc, st, 5, 24, 1);
        carryRound(sc, st, 7, 24, 1);
        carryRound(sc, st, 0, 25, 1);
        carryRound(sc, st, 2, 25, 1);
        carryRound(sc, st, 4, 25, 1);
        carryRound(sc, st, 6, 25, 1);
        carryRound(sc, st, 8, 25, 1);

        for (h.b) |_, i| {
            h.b[i] = @intCast(i32, t[i]);
        }
    }

    fn carry2(h: *Fe, t: []i64) void {
        var c: [10]i64 = undefined;

        var sc = c[0..];
        var st = t[0..];

        carryRound(sc, st, 0, 25, 1);
        carryRound(sc, st, 4, 25, 1);
        carryRound(sc, st, 1, 24, 1);
        carryRound(sc, st, 5, 24, 1);
        carryRound(sc, st, 2, 25, 1);
        carryRound(sc, st, 6, 25, 1);
        carryRound(sc, st, 3, 24, 1);
        carryRound(sc, st, 7, 24, 1);
        carryRound(sc, st, 4, 25, 1);
        carryRound(sc, st, 8, 25, 1);
        carryRound(sc, st, 9, 24, 19);
        carryRound(sc, st, 0, 25, 1);

        for (h.b) |_, i| {
            h.b[i] = @intCast(i32, t[i]);
        }
    }

    fn fromBytes(h: *Fe, s: []const u8) void {
        std.debug.assert(s.len >= 32);

        var t: [10]i64 = undefined;

        t[0] = readIntLittle(u32, s[0..4]);
        t[1] = @as(u32, readIntLittle(u24, s[4..7])) << 6;
        t[2] = @as(u32, readIntLittle(u24, s[7..10])) << 5;
        t[3] = @as(u32, readIntLittle(u24, s[10..13])) << 3;
        t[4] = @as(u32, readIntLittle(u24, s[13..16])) << 2;
        t[5] = readIntLittle(u32, s[16..20]);
        t[6] = @as(u32, readIntLittle(u24, s[20..23])) << 7;
        t[7] = @as(u32, readIntLittle(u24, s[23..26])) << 5;
        t[8] = @as(u32, readIntLittle(u24, s[26..29])) << 4;
        t[9] = (@as(u32, readIntLittle(u24, s[29..32])) & 0x7fffff) << 2;

        carry1(h, t[0..]);
    }

    fn mulSmall(h: *Fe, f: *const Fe, comptime g: comptime_int) void {
        var t: [10]i64 = undefined;

        for (t[0..]) |_, i| {
            t[i] = @as(i64, f.b[i]) * g;
        }

        carry1(h, t[0..]);
    }

    fn mul(h: *Fe, f1: *const Fe, g1: *const Fe) void {
        const f = f1.b;
        const g = g1.b;

        var F: [10]i32 = undefined;
        var G: [10]i32 = undefined;

        F[1] = f[1] * 2;
        F[3] = f[3] * 2;
        F[5] = f[5] * 2;
        F[7] = f[7] * 2;
        F[9] = f[9] * 2;

        G[1] = g[1] * 19;
        G[2] = g[2] * 19;
        G[3] = g[3] * 19;
        G[4] = g[4] * 19;
        G[5] = g[5] * 19;
        G[6] = g[6] * 19;
        G[7] = g[7] * 19;
        G[8] = g[8] * 19;
        G[9] = g[9] * 19;

        // t's become h
        var t: [10]i64 = undefined;

        t[0] = f[0] * @as(i64, g[0]) + F[1] * @as(i64, G[9]) + f[2] * @as(i64, G[8]) + F[3] * @as(i64, G[7]) + f[4] * @as(i64, G[6]) + F[5] * @as(i64, G[5]) + f[6] * @as(i64, G[4]) + F[7] * @as(i64, G[3]) + f[8] * @as(i64, G[2]) + F[9] * @as(i64, G[1]);
        t[1] = f[0] * @as(i64, g[1]) + f[1] * @as(i64, g[0]) + f[2] * @as(i64, G[9]) + f[3] * @as(i64, G[8]) + f[4] * @as(i64, G[7]) + f[5] * @as(i64, G[6]) + f[6] * @as(i64, G[5]) + f[7] * @as(i64, G[4]) + f[8] * @as(i64, G[3]) + f[9] * @as(i64, G[2]);
        t[2] = f[0] * @as(i64, g[2]) + F[1] * @as(i64, g[1]) + f[2] * @as(i64, g[0]) + F[3] * @as(i64, G[9]) + f[4] * @as(i64, G[8]) + F[5] * @as(i64, G[7]) + f[6] * @as(i64, G[6]) + F[7] * @as(i64, G[5]) + f[8] * @as(i64, G[4]) + F[9] * @as(i64, G[3]);
        t[3] = f[0] * @as(i64, g[3]) + f[1] * @as(i64, g[2]) + f[2] * @as(i64, g[1]) + f[3] * @as(i64, g[0]) + f[4] * @as(i64, G[9]) + f[5] * @as(i64, G[8]) + f[6] * @as(i64, G[7]) + f[7] * @as(i64, G[6]) + f[8] * @as(i64, G[5]) + f[9] * @as(i64, G[4]);
        t[4] = f[0] * @as(i64, g[4]) + F[1] * @as(i64, g[3]) + f[2] * @as(i64, g[2]) + F[3] * @as(i64, g[1]) + f[4] * @as(i64, g[0]) + F[5] * @as(i64, G[9]) + f[6] * @as(i64, G[8]) + F[7] * @as(i64, G[7]) + f[8] * @as(i64, G[6]) + F[9] * @as(i64, G[5]);
        t[5] = f[0] * @as(i64, g[5]) + f[1] * @as(i64, g[4]) + f[2] * @as(i64, g[3]) + f[3] * @as(i64, g[2]) + f[4] * @as(i64, g[1]) + f[5] * @as(i64, g[0]) + f[6] * @as(i64, G[9]) + f[7] * @as(i64, G[8]) + f[8] * @as(i64, G[7]) + f[9] * @as(i64, G[6]);
        t[6] = f[0] * @as(i64, g[6]) + F[1] * @as(i64, g[5]) + f[2] * @as(i64, g[4]) + F[3] * @as(i64, g[3]) + f[4] * @as(i64, g[2]) + F[5] * @as(i64, g[1]) + f[6] * @as(i64, g[0]) + F[7] * @as(i64, G[9]) + f[8] * @as(i64, G[8]) + F[9] * @as(i64, G[7]);
        t[7] = f[0] * @as(i64, g[7]) + f[1] * @as(i64, g[6]) + f[2] * @as(i64, g[5]) + f[3] * @as(i64, g[4]) + f[4] * @as(i64, g[3]) + f[5] * @as(i64, g[2]) + f[6] * @as(i64, g[1]) + f[7] * @as(i64, g[0]) + f[8] * @as(i64, G[9]) + f[9] * @as(i64, G[8]);
        t[8] = f[0] * @as(i64, g[8]) + F[1] * @as(i64, g[7]) + f[2] * @as(i64, g[6]) + F[3] * @as(i64, g[5]) + f[4] * @as(i64, g[4]) + F[5] * @as(i64, g[3]) + f[6] * @as(i64, g[2]) + F[7] * @as(i64, g[1]) + f[8] * @as(i64, g[0]) + F[9] * @as(i64, G[9]);
        t[9] = f[0] * @as(i64, g[9]) + f[1] * @as(i64, g[8]) + f[2] * @as(i64, g[7]) + f[3] * @as(i64, g[6]) + f[4] * @as(i64, g[5]) + f[5] * @as(i64, g[4]) + f[6] * @as(i64, g[3]) + f[7] * @as(i64, g[2]) + f[8] * @as(i64, g[1]) + f[9] * @as(i64, g[0]);

        carry2(h, t[0..]);
    }

    // we could use Fe.mul() for this, but this is significantly faster
    fn sq(h: *Fe, fz: *const Fe) void {
        const f0 = fz.b[0];
        const f1 = fz.b[1];
        const f2 = fz.b[2];
        const f3 = fz.b[3];
        const f4 = fz.b[4];
        const f5 = fz.b[5];
        const f6 = fz.b[6];
        const f7 = fz.b[7];
        const f8 = fz.b[8];
        const f9 = fz.b[9];

        const f0_2 = f0 * 2;
        const f1_2 = f1 * 2;
        const f2_2 = f2 * 2;
        const f3_2 = f3 * 2;
        const f4_2 = f4 * 2;
        const f5_2 = f5 * 2;
        const f6_2 = f6 * 2;
        const f7_2 = f7 * 2;
        const f5_38 = f5 * 38;
        const f6_19 = f6 * 19;
        const f7_38 = f7 * 38;
        const f8_19 = f8 * 19;
        const f9_38 = f9 * 38;

        var t: [10]i64 = undefined;

        t[0] = f0 * @as(i64, f0) + f1_2 * @as(i64, f9_38) + f2_2 * @as(i64, f8_19) + f3_2 * @as(i64, f7_38) + f4_2 * @as(i64, f6_19) + f5 * @as(i64, f5_38);
        t[1] = f0_2 * @as(i64, f1) + f2 * @as(i64, f9_38) + f3_2 * @as(i64, f8_19) + f4 * @as(i64, f7_38) + f5_2 * @as(i64, f6_19);
        t[2] = f0_2 * @as(i64, f2) + f1_2 * @as(i64, f1) + f3_2 * @as(i64, f9_38) + f4_2 * @as(i64, f8_19) + f5_2 * @as(i64, f7_38) + f6 * @as(i64, f6_19);
        t[3] = f0_2 * @as(i64, f3) + f1_2 * @as(i64, f2) + f4 * @as(i64, f9_38) + f5_2 * @as(i64, f8_19) + f6 * @as(i64, f7_38);
        t[4] = f0_2 * @as(i64, f4) + f1_2 * @as(i64, f3_2) + f2 * @as(i64, f2) + f5_2 * @as(i64, f9_38) + f6_2 * @as(i64, f8_19) + f7 * @as(i64, f7_38);
        t[5] = f0_2 * @as(i64, f5) + f1_2 * @as(i64, f4) + f2_2 * @as(i64, f3) + f6 * @as(i64, f9_38) + f7_2 * @as(i64, f8_19);
        t[6] = f0_2 * @as(i64, f6) + f1_2 * @as(i64, f5_2) + f2_2 * @as(i64, f4) + f3_2 * @as(i64, f3) + f7_2 * @as(i64, f9_38) + f8 * @as(i64, f8_19);
        t[7] = f0_2 * @as(i64, f7) + f1_2 * @as(i64, f6) + f2_2 * @as(i64, f5) + f3_2 * @as(i64, f4) + f8 * @as(i64, f9_38);
        t[8] = f0_2 * @as(i64, f8) + f1_2 * @as(i64, f7_2) + f2_2 * @as(i64, f6) + f3_2 * @as(i64, f5_2) + f4 * @as(i64, f4) + f9 * @as(i64, f9_38);
        t[9] = f0_2 * @as(i64, f9) + f1_2 * @as(i64, f8) + f2_2 * @as(i64, f7) + f3_2 * @as(i64, f6) + f4 * @as(i64, f5_2);

        carry2(h, t[0..]);
    }

    fn sq2(h: *Fe, f: *const Fe) void {
        Fe.sq(h, f);
        Fe.mul_small(h, h, 2);
    }

    // This could be simplified, but it would be slower
    fn invert(out: *Fe, z: *const Fe) void {
        var i: usize = undefined;

        var t: [4]Fe = undefined;
        var t0 = &t[0];
        var t1 = &t[1];
        var t2 = &t[2];
        var t3 = &t[3];

        Fe.sq(t0, z);
        Fe.sq(t1, t0);
        Fe.sq(t1, t1);
        Fe.mul(t1, z, t1);
        Fe.mul(t0, t0, t1);

        Fe.sq(t2, t0);
        Fe.mul(t1, t1, t2);

        Fe.sq(t2, t1);
        i = 1;
        while (i < 5) : (i += 1) Fe.sq(t2, t2);
        Fe.mul(t1, t2, t1);

        Fe.sq(t2, t1);
        i = 1;
        while (i < 10) : (i += 1) Fe.sq(t2, t2);
        Fe.mul(t2, t2, t1);

        Fe.sq(t3, t2);
        i = 1;
        while (i < 20) : (i += 1) Fe.sq(t3, t3);
        Fe.mul(t2, t3, t2);

        Fe.sq(t2, t2);
        i = 1;
        while (i < 10) : (i += 1) Fe.sq(t2, t2);
        Fe.mul(t1, t2, t1);

        Fe.sq(t2, t1);
        i = 1;
        while (i < 50) : (i += 1) Fe.sq(t2, t2);
        Fe.mul(t2, t2, t1);

        Fe.sq(t3, t2);
        i = 1;
        while (i < 100) : (i += 1) Fe.sq(t3, t3);
        Fe.mul(t2, t3, t2);

        Fe.sq(t2, t2);
        i = 1;
        while (i < 50) : (i += 1) Fe.sq(t2, t2);
        Fe.mul(t1, t2, t1);

        Fe.sq(t1, t1);
        i = 1;
        while (i < 5) : (i += 1) Fe.sq(t1, t1);
        Fe.mul(out, t1, t0);

        t0.secureZero();
        t1.secureZero();
        t2.secureZero();
        t3.secureZero();
    }

    // This could be simplified, but it would be slower
    fn pow22523(out: *Fe, z: *const Fe) void {
        var i: usize = undefined;

        var t: [3]Fe = undefined;
        var t0 = &t[0];
        var t1 = &t[1];
        var t2 = &t[2];

        Fe.sq(t0, z);
        Fe.sq(t1, t0);
        Fe.sq(t1, t1);
        Fe.mul(t1, z, t1);
        Fe.mul(t0, t0, t1);

        Fe.sq(t0, t0);
        Fe.mul(t0, t1, t0);

        Fe.sq(t1, t0);
        i = 1;
        while (i < 5) : (i += 1) Fe.sq(t1, t1);
        Fe.mul(t0, t1, t0);

        Fe.sq(t1, t0);
        i = 1;
        while (i < 10) : (i += 1) Fe.sq(t1, t1);
        Fe.mul(t1, t1, t0);

        Fe.sq(t2, t1);
        i = 1;
        while (i < 20) : (i += 1) Fe.sq(t2, t2);
        Fe.mul(t1, t2, t1);

        Fe.sq(t1, t1);
        i = 1;
        while (i < 10) : (i += 1) Fe.sq(t1, t1);
        Fe.mul(t0, t1, t0);

        Fe.sq(t1, t0);
        i = 1;
        while (i < 50) : (i += 1) Fe.sq(t1, t1);
        Fe.mul(t1, t1, t0);

        Fe.sq(t2, t1);
        i = 1;
        while (i < 100) : (i += 1) Fe.sq(t2, t2);
        Fe.mul(t1, t2, t1);

        Fe.sq(t1, t1);
        i = 1;
        while (i < 50) : (i += 1) Fe.sq(t1, t1);
        Fe.mul(t0, t1, t0);

        Fe.sq(t0, t0);
        i = 1;
        while (i < 2) : (i += 1) Fe.sq(t0, t0);
        Fe.mul(out, t0, z);

        t0.secureZero();
        t1.secureZero();
        t2.secureZero();
    }

    inline fn toBytesRound(c: []i64, t: []i64, comptime i: comptime_int, comptime shift: comptime_int) void {
        c[i] = t[i] >> shift;
        if (i + 1 < 10) {
            t[i + 1] += c[i];
        }
        t[i] -= c[i] * (@as(i32, 1) << shift);
    }

    fn toBytes(s: []u8, h: *const Fe) void {
        std.debug.assert(s.len >= 32);

        var t: [10]i64 = undefined;
        for (h.b[0..]) |_, i| {
            t[i] = h.b[i];
        }

        var q = (19 * t[9] + ((@as(i32, 1) << 24))) >> 25;
        {
            var i: usize = 0;
            while (i < 5) : (i += 1) {
                q += t[2 * i];
                q >>= 26;
                q += t[2 * i + 1];
                q >>= 25;
            }
        }
        t[0] += 19 * q;

        var c: [10]i64 = undefined;

        var st = t[0..];
        var sc = c[0..];

        toBytesRound(sc, st, 0, 26);
        toBytesRound(sc, st, 1, 25);
        toBytesRound(sc, st, 2, 26);
        toBytesRound(sc, st, 3, 25);
        toBytesRound(sc, st, 4, 26);
        toBytesRound(sc, st, 5, 25);
        toBytesRound(sc, st, 6, 26);
        toBytesRound(sc, st, 7, 25);
        toBytesRound(sc, st, 8, 26);
        toBytesRound(sc, st, 9, 25);

        var ut: [10]u32 = undefined;
        for (ut[0..]) |_, i| {
            ut[i] = @bitCast(u32, @intCast(i32, t[i]));
        }

        writeIntLittle(u32, s[0..4], (ut[0] >> 0) | (ut[1] << 26));
        writeIntLittle(u32, s[4..8], (ut[1] >> 6) | (ut[2] << 19));
        writeIntLittle(u32, s[8..12], (ut[2] >> 13) | (ut[3] << 13));
        writeIntLittle(u32, s[12..16], (ut[3] >> 19) | (ut[4] << 6));
        writeIntLittle(u32, s[16..20], (ut[5] >> 0) | (ut[6] << 25));
        writeIntLittle(u32, s[20..24], (ut[6] >> 7) | (ut[7] << 19));
        writeIntLittle(u32, s[24..28], (ut[7] >> 13) | (ut[8] << 12));
        writeIntLittle(u32, s[28..32], (ut[8] >> 20) | (ut[9] << 6));

        std.mem.secureZero(i64, t[0..]);
    }

    //  Parity check.  Returns 0 if even, 1 if odd
    fn isNegative(f: *const Fe) bool {
        var s: [32]u8 = undefined;
        Fe.toBytes(s[0..], f);
        const isneg = s[0] & 1;
        s.secureZero();
        return isneg;
    }

    fn isNonZero(f: *const Fe) bool {
        var s: [32]u8 = undefined;
        Fe.toBytes(s[0..], f);
        const isnonzero = zerocmp(u8, s[0..]);
        s.secureZero();
        return isneg;
    }
};

test "x25519 public key calculation from secret key" {
    var sk: [32]u8 = undefined;
    var pk_expected: [32]u8 = undefined;
    var pk_calculated: [32]u8 = undefined;
    try fmt.hexToBytes(sk[0..], "8052030376d47112be7f73ed7a019293dd12ad910b654455798b4667d73de166");
    try fmt.hexToBytes(pk_expected[0..], "f1814f0e8ff1043d8a44d25babff3cedcae6c22c3edaa48f857ae70de2baae50");
    std.testing.expect(X25519.createPublicKey(pk_calculated[0..], &sk));
    std.testing.expect(std.mem.eql(u8, &pk_calculated, &pk_expected));
}

test "x25519 rfc7748 vector1" {
    const secret_key = "\xa5\x46\xe3\x6b\xf0\x52\x7c\x9d\x3b\x16\x15\x4b\x82\x46\x5e\xdd\x62\x14\x4c\x0a\xc1\xfc\x5a\x18\x50\x6a\x22\x44\xba\x44\x9a\xc4";
    const public_key = "\xe6\xdb\x68\x67\x58\x30\x30\xdb\x35\x94\xc1\xa4\x24\xb1\x5f\x7c\x72\x66\x24\xec\x26\xb3\x35\x3b\x10\xa9\x03\xa6\xd0\xab\x1c\x4c";

    const expected_output = "\xc3\xda\x55\x37\x9d\xe9\xc6\x90\x8e\x94\xea\x4d\xf2\x8d\x08\x4f\x32\xec\xcf\x03\x49\x1c\x71\xf7\x54\xb4\x07\x55\x77\xa2\x85\x52";

    var output: [32]u8 = undefined;

    std.testing.expect(X25519.create(output[0..], secret_key, public_key));
    std.testing.expect(std.mem.eql(u8, &output, expected_output));
}

test "x25519 rfc7748 vector2" {
    const secret_key = "\x4b\x66\xe9\xd4\xd1\xb4\x67\x3c\x5a\xd2\x26\x91\x95\x7d\x6a\xf5\xc1\x1b\x64\x21\xe0\xea\x01\xd4\x2c\xa4\x16\x9e\x79\x18\xba\x0d";
    const public_key = "\xe5\x21\x0f\x12\x78\x68\x11\xd3\xf4\xb7\x95\x9d\x05\x38\xae\x2c\x31\xdb\xe7\x10\x6f\xc0\x3c\x3e\xfc\x4c\xd5\x49\xc7\x15\xa4\x93";

    const expected_output = "\x95\xcb\xde\x94\x76\xe8\x90\x7d\x7a\xad\xe4\x5c\xb4\xb8\x73\xf8\x8b\x59\x5a\x68\x79\x9f\xa1\x52\xe6\xf8\xf7\x64\x7a\xac\x79\x57";

    var output: [32]u8 = undefined;

    std.testing.expect(X25519.create(output[0..], secret_key, public_key));
    std.testing.expect(std.mem.eql(u8, &output, expected_output));
}

test "x25519 rfc7748 one iteration" {
    const initial_value = "\x09\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*;
    const expected_output = "\x42\x2c\x8e\x7a\x62\x27\xd7\xbc\xa1\x35\x0b\x3e\x2b\xb7\x27\x9f\x78\x97\xb8\x7b\xb6\x85\x4b\x78\x3c\x60\xe8\x03\x11\xae\x30\x79";

    var k: [32]u8 = initial_value;
    var u: [32]u8 = initial_value;

    var i: usize = 0;
    while (i < 1) : (i += 1) {
        var output: [32]u8 = undefined;
        std.testing.expect(X25519.create(output[0..], &k, &u));

        std.mem.copy(u8, u[0..], k[0..]);
        std.mem.copy(u8, k[0..], output[0..]);
    }

    std.testing.expect(std.mem.eql(u8, k[0..], expected_output));
}

test "x25519 rfc7748 1,000 iterations" {
    // These iteration tests are slow so we always skip them. Results have been verified.
    if (true) {
        return error.SkipZigTest;
    }

    const initial_value = "\x09\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    const expected_output = "\x68\x4c\xf5\x9b\xa8\x33\x09\x55\x28\x00\xef\x56\x6f\x2f\x4d\x3c\x1c\x38\x87\xc4\x93\x60\xe3\x87\x5f\x2e\xb9\x4d\x99\x53\x2c\x51";

    var k: [32]u8 = initial_value.*;
    var u: [32]u8 = initial_value.*;

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        var output: [32]u8 = undefined;
        std.testing.expect(X25519.create(output[0..], &k, &u));

        std.mem.copy(u8, u[0..], k[0..]);
        std.mem.copy(u8, k[0..], output[0..]);
    }

    std.testing.expect(std.mem.eql(u8, k[0..], expected_output));
}

test "x25519 rfc7748 1,000,000 iterations" {
    if (true) {
        return error.SkipZigTest;
    }

    const initial_value = "\x09\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    const expected_output = "\x7c\x39\x11\xe0\xab\x25\x86\xfd\x86\x44\x97\x29\x7e\x57\x5e\x6f\x3b\xc6\x01\xc0\x88\x3c\x30\xdf\x5f\x4d\xd2\xd2\x4f\x66\x54\x24";

    var k: [32]u8 = initial_value.*;
    var u: [32]u8 = initial_value.*;

    var i: usize = 0;
    while (i < 1000000) : (i += 1) {
        var output: [32]u8 = undefined;
        std.testing.expect(X25519.create(output[0..], &k, &u));

        std.mem.copy(u8, u[0..], k[0..]);
        std.mem.copy(u8, k[0..], output[0..]);
    }

    std.testing.expect(std.mem.eql(u8, k[0..], expected_output));
}
