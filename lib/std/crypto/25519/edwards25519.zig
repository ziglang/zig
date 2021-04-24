// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const crypto = std.crypto;
const debug = std.debug;
const fmt = std.fmt;
const mem = std.mem;

const EncodingError = crypto.errors.EncodingError;
const IdentityElementError = crypto.errors.IdentityElementError;
const NonCanonicalError = crypto.errors.NonCanonicalError;
const NotSquareError = crypto.errors.NotSquareError;
const WeakPublicKeyError = crypto.errors.WeakPublicKeyError;

/// Group operations over Edwards25519.
pub const Edwards25519 = struct {
    /// The underlying prime field.
    pub const Fe = @import("field.zig").Fe;
    /// Field arithmetic mod the order of the main subgroup.
    pub const scalar = @import("scalar.zig");
    /// Length in bytes of a compressed representation of a point.
    pub const encoded_length: usize = 32;

    x: Fe,
    y: Fe,
    z: Fe,
    t: Fe,

    is_base: bool = false,

    /// Decode an Edwards25519 point from its compressed (Y+sign) coordinates.
    pub fn fromBytes(s: [encoded_length]u8) EncodingError!Edwards25519 {
        const z = Fe.one;
        const y = Fe.fromBytes(s);
        var u = y.sq();
        var v = u.mul(Fe.edwards25519d);
        u = u.sub(z);
        v = v.add(z);
        const v3 = v.sq().mul(v);
        var x = v3.sq().mul(v).mul(u).pow2523().mul(v3).mul(u);
        const vxx = x.sq().mul(v);
        const has_m_root = vxx.sub(u).isZero();
        const has_p_root = vxx.add(u).isZero();
        if ((@boolToInt(has_m_root) | @boolToInt(has_p_root)) == 0) { // best-effort to avoid two conditional branches
            return error.InvalidEncoding;
        }
        x.cMov(x.mul(Fe.sqrtm1), 1 - @boolToInt(has_m_root));
        x.cMov(x.neg(), @boolToInt(x.isNegative()) ^ (s[31] >> 7));
        const t = x.mul(y);
        return Edwards25519{ .x = x, .y = y, .z = z, .t = t };
    }

    /// Encode an Edwards25519 point.
    pub fn toBytes(p: Edwards25519) [encoded_length]u8 {
        const zi = p.z.invert();
        var s = p.y.mul(zi).toBytes();
        s[31] ^= @as(u8, @boolToInt(p.x.mul(zi).isNegative())) << 7;
        return s;
    }

    /// Check that the encoding of a point is canonical.
    pub fn rejectNonCanonical(s: [32]u8) NonCanonicalError!void {
        return Fe.rejectNonCanonical(s, true);
    }

    /// The edwards25519 base point.
    pub const basePoint = Edwards25519{
        .x = Fe{ .limbs = .{ 3990542415680775, 3398198340507945, 4322667446711068, 2814063955482877, 2839572215813860 } },
        .y = Fe{ .limbs = .{ 1801439850948184, 1351079888211148, 450359962737049, 900719925474099, 1801439850948198 } },
        .z = Fe.one,
        .t = Fe{ .limbs = .{ 1841354044333475, 16398895984059, 755974180946558, 900171276175154, 1821297809914039 } },
        .is_base = true,
    };

    /// The edwards25519 neutral element.
    pub const neutralElement = Edwards25519{
        .x = Fe{ .limbs = .{ 2251799813685229, 2251799813685247, 2251799813685247, 2251799813685247, 2251799813685247 } },
        .y = Fe{ .limbs = .{ 1507481815385608, 2223447444246085, 1083941587175919, 2059929906842505, 1581435440146976 } },
        .z = Fe{ .limbs = .{ 1507481815385608, 2223447444246085, 1083941587175919, 2059929906842505, 1581435440146976 } },
        .t = Fe{ .limbs = .{ 2251799813685229, 2251799813685247, 2251799813685247, 2251799813685247, 2251799813685247 } },
        .is_base = false,
    };

    const identityElement = Edwards25519{ .x = Fe.zero, .y = Fe.one, .z = Fe.one, .t = Fe.zero };

    /// Reject the neutral element.
    pub fn rejectIdentity(p: Edwards25519) IdentityElementError!void {
        if (p.x.isZero()) {
            return error.IdentityElement;
        }
    }

    /// Multiply a point by the cofactor
    pub fn clearCofactor(p: Edwards25519) Edwards25519 {
        return p.dbl().dbl().dbl();
    }

    /// Flip the sign of the X coordinate.
    pub fn neg(p: Edwards25519) callconv(.Inline) Edwards25519 {
        return .{ .x = p.x.neg(), .y = p.y, .z = p.z, .t = p.t.neg() };
    }

    /// Double an Edwards25519 point.
    pub fn dbl(p: Edwards25519) Edwards25519 {
        const t0 = p.x.add(p.y).sq();
        var x = p.x.sq();
        var z = p.y.sq();
        const y = z.add(x);
        z = z.sub(x);
        x = t0.sub(y);
        const t = p.z.sq2().sub(z);
        return .{
            .x = x.mul(t),
            .y = y.mul(z),
            .z = z.mul(t),
            .t = x.mul(y),
        };
    }

    /// Add two Edwards25519 points.
    pub fn add(p: Edwards25519, q: Edwards25519) Edwards25519 {
        const a = p.y.sub(p.x).mul(q.y.sub(q.x));
        const b = p.x.add(p.y).mul(q.x.add(q.y));
        const c = p.t.mul(q.t).mul(Fe.edwards25519d2);
        var d = p.z.mul(q.z);
        d = d.add(d);
        const x = b.sub(a);
        const y = b.add(a);
        const z = d.add(c);
        const t = d.sub(c);
        return .{
            .x = x.mul(t),
            .y = y.mul(z),
            .z = z.mul(t),
            .t = x.mul(y),
        };
    }

    /// Substract two Edwards25519 points.
    pub fn sub(p: Edwards25519, q: Edwards25519) Edwards25519 {
        return p.add(q.neg());
    }

    fn cMov(p: *Edwards25519, a: Edwards25519, c: u64) callconv(.Inline) void {
        p.x.cMov(a.x, c);
        p.y.cMov(a.y, c);
        p.z.cMov(a.z, c);
        p.t.cMov(a.t, c);
    }

    fn pcSelect(comptime n: usize, pc: [n]Edwards25519, b: u8) callconv(.Inline) Edwards25519 {
        var t = Edwards25519.identityElement;
        comptime var i: u8 = 1;
        inline while (i < pc.len) : (i += 1) {
            t.cMov(pc[i], ((@as(usize, b ^ i) -% 1) >> 8) & 1);
        }
        return t;
    }

    fn nonAdjacentForm(s: [32]u8) [2 * 32]i8 {
        var e: [2 * 32]i8 = undefined;
        for (s) |x, i| {
            e[i * 2 + 0] = @as(i8, @truncate(u4, x));
            e[i * 2 + 1] = @as(i8, @truncate(u4, x >> 4));
        }
        // Now, e[0..63] is between 0 and 15, e[63] is between 0 and 7
        var carry: i8 = 0;
        for (e[0..63]) |*x| {
            x.* += carry;
            carry = (x.* + 8) >> 4;
            x.* -= carry * 16;
        }
        e[63] += carry;
        // Now, e[*] is between -8 and 8, including e[63]
        return e;
    }

    // Scalar multiplication with a 4-bit window and the first 8 multiples.
    // This requires the scalar to be converted to non-adjacent form.
    // Based on real-world benchmarks, we only use this for multi-scalar multiplication.
    // NAF could be useful to half the size of precomputation tables, but we intentionally
    // avoid these to keep the standard library lightweight.
    fn pcMul(pc: [9]Edwards25519, s: [32]u8, comptime vartime: bool) IdentityElementError!Edwards25519 {
        std.debug.assert(vartime);
        const e = nonAdjacentForm(s);
        var q = Edwards25519.identityElement;
        var pos: usize = 2 * 32 - 1;
        while (true) : (pos -= 1) {
            const slot = e[pos];
            if (slot > 0) {
                q = q.add(pc[@intCast(usize, slot)]);
            } else if (slot < 0) {
                q = q.sub(pc[@intCast(usize, -slot)]);
            }
            if (pos == 0) break;
            q = q.dbl().dbl().dbl().dbl();
        }
        try q.rejectIdentity();
        return q;
    }

    // Scalar multiplication with a 4-bit window and the first 15 multiples.
    fn pcMul16(pc: [16]Edwards25519, s: [32]u8, comptime vartime: bool) IdentityElementError!Edwards25519 {
        var q = Edwards25519.identityElement;
        var pos: usize = 252;
        while (true) : (pos -= 4) {
            const slot = @truncate(u4, (s[pos >> 3] >> @truncate(u3, pos)));
            if (vartime) {
                if (slot != 0) {
                    q = q.add(pc[slot]);
                }
            } else {
                q = q.add(pcSelect(16, pc, slot));
            }
            if (pos == 0) break;
            q = q.dbl().dbl().dbl().dbl();
        }
        try q.rejectIdentity();
        return q;
    }

    fn precompute(p: Edwards25519, comptime count: usize) [1 + count]Edwards25519 {
        var pc: [1 + count]Edwards25519 = undefined;
        pc[0] = Edwards25519.identityElement;
        pc[1] = p;
        var i: usize = 2;
        while (i <= count) : (i += 1) {
            pc[i] = if (i % 2 == 0) pc[i / 2].dbl() else pc[i - 1].add(p);
        }
        return pc;
    }

    const basePointPc = comptime pc: {
        @setEvalBranchQuota(10000);
        break :pc precompute(Edwards25519.basePoint, 15);
    };

    const basePointPc8 = comptime pc: {
        @setEvalBranchQuota(10000);
        break :pc precompute(Edwards25519.basePoint, 8);
    };

    /// Multiply an Edwards25519 point by a scalar without clamping it.
    /// Return error.WeakPublicKey if the base generates a small-order group,
    /// and error.IdentityElement if the result is the identity element.
    pub fn mul(p: Edwards25519, s: [32]u8) (IdentityElementError || WeakPublicKeyError)!Edwards25519 {
        const pc = if (p.is_base) basePointPc else pc: {
            const xpc = precompute(p, 15);
            xpc[4].rejectIdentity() catch return error.WeakPublicKey;
            break :pc xpc;
        };
        return pcMul16(pc, s, false);
    }

    /// Multiply an Edwards25519 point by a *PUBLIC* scalar *IN VARIABLE TIME*
    /// This can be used for signature verification.
    pub fn mulPublic(p: Edwards25519, s: [32]u8) (IdentityElementError || WeakPublicKeyError)!Edwards25519 {
        if (p.is_base) {
            return pcMul16(basePointPc, s, true);
        } else {
            const pc = precompute(p, 8);
            pc[4].rejectIdentity() catch |_| return error.WeakPublicKey;
            return pcMul(pc, s, true);
        }
    }

    /// Double-base multiplication of public parameters - Compute (p1*s1)+(p2*s2) *IN VARIABLE TIME*
    /// This can be used for signature verification.
    pub fn mulDoubleBasePublic(p1: Edwards25519, s1: [32]u8, p2: Edwards25519, s2: [32]u8) (IdentityElementError || WeakPublicKeyError)!Edwards25519 {
        const pc1 = if (p1.is_base) basePointPc8 else pc: {
            const xpc = precompute(p1, 8);
            xpc[4].rejectIdentity() catch return error.WeakPublicKey;
            break :pc xpc;
        };
        const pc2 = if (p2.is_base) basePointPc8 else pc: {
            const xpc = precompute(p2, 8);
            xpc[4].rejectIdentity() catch return error.WeakPublicKey;
            break :pc xpc;
        };
        const e1 = nonAdjacentForm(s1);
        const e2 = nonAdjacentForm(s2);
        var q = Edwards25519.identityElement;
        var pos: usize = 2 * 32 - 1;
        while (true) : (pos -= 1) {
            const slot1 = e1[pos];
            if (slot1 > 0) {
                q = q.add(pc1[@intCast(usize, slot1)]);
            } else if (slot1 < 0) {
                q = q.sub(pc1[@intCast(usize, -slot1)]);
            }
            const slot2 = e2[pos];
            if (slot2 > 0) {
                q = q.add(pc2[@intCast(usize, slot2)]);
            } else if (slot2 < 0) {
                q = q.sub(pc2[@intCast(usize, -slot2)]);
            }
            if (pos == 0) break;
            q = q.dbl().dbl().dbl().dbl();
        }
        try q.rejectIdentity();
        return q;
    }

    /// Multiscalar multiplication *IN VARIABLE TIME* for public data
    /// Computes ps0*ss0 + ps1*ss1 + ps2*ss2... faster than doing many of these operations individually
    pub fn mulMulti(comptime count: usize, ps: [count]Edwards25519, ss: [count][32]u8) (IdentityElementError || WeakPublicKeyError)!Edwards25519 {
        var pcs: [count][9]Edwards25519 = undefined;
        for (ps) |p, i| {
            if (p.is_base) {
                pcs[i] = basePointPc8;
            } else {
                pcs[i] = precompute(p, 8);
                pcs[i][4].rejectIdentity() catch |_| return error.WeakPublicKey;
            }
        }
        var es: [count][2 * 32]i8 = undefined;
        for (ss) |s, i| {
            es[i] = nonAdjacentForm(s);
        }
        var q = Edwards25519.identityElement;
        var pos: usize = 2 * 32 - 1;
        while (true) : (pos -= 1) {
            for (es) |e, i| {
                const slot = e[pos];
                if (slot > 0) {
                    q = q.add(pcs[i][@intCast(usize, slot)]);
                } else if (slot < 0) {
                    q = q.sub(pcs[i][@intCast(usize, -slot)]);
                }
            }
            if (pos == 0) break;
            q = q.dbl().dbl().dbl().dbl();
        }
        try q.rejectIdentity();
        return q;
    }

    /// Multiply an Edwards25519 point by a scalar after "clamping" it.
    /// Clamping forces the scalar to be a multiple of the cofactor in
    /// order to prevent small subgroups attacks.
    /// This is strongly recommended for DH operations.
    /// Return error.WeakPublicKey if the resulting point is
    /// the identity element.
    pub fn clampedMul(p: Edwards25519, s: [32]u8) (IdentityElementError || WeakPublicKeyError)!Edwards25519 {
        var t: [32]u8 = s;
        scalar.clamp(&t);
        return mul(p, t);
    }

    // montgomery -- recover y = sqrt(x^3 + A*x^2 + x)
    fn xmontToYmont(x: Fe) NotSquareError!Fe {
        var x2 = x.sq();
        const x3 = x.mul(x2);
        x2 = x2.mul32(Fe.edwards25519a_32);
        return x.add(x2).add(x3).sqrt();
    }

    // montgomery affine coordinates to edwards extended coordinates
    fn montToEd(x: Fe, y: Fe) Edwards25519 {
        const x_plus_one = x.add(Fe.one);
        const x_minus_one = x.sub(Fe.one);
        const x_plus_one_y_inv = x_plus_one.mul(y).invert(); // 1/((x+1)*y)

        // xed = sqrt(-A-2)*x/y
        const xed = x.mul(Fe.edwards25519sqrtam2).mul(x_plus_one_y_inv).mul(x_plus_one);

        // yed = (x-1)/(x+1) or 1 if the denominator is 0
        var yed = x_plus_one_y_inv.mul(y).mul(x_minus_one);
        yed.cMov(Fe.one, @boolToInt(x_plus_one_y_inv.isZero()));

        return Edwards25519{
            .x = xed,
            .y = yed,
            .z = Fe.one,
            .t = xed.mul(yed),
        };
    }

    /// Elligator2 map - Returns Montgomery affine coordinates
    pub fn elligator2(r: Fe) struct { x: Fe, y: Fe, not_square: bool } {
        const rr2 = r.sq2().add(Fe.one).invert();
        var x = rr2.mul32(Fe.edwards25519a_32).neg(); // x=x1
        var x2 = x.sq();
        const x3 = x2.mul(x);
        x2 = x2.mul32(Fe.edwards25519a_32); // x2 = A*x1^2
        const gx1 = x3.add(x).add(x2); // gx1 = x1^3 + A*x1^2 + x1
        const not_square = !gx1.isSquare();

        // gx1 not a square => x = -x1-A
        x.cMov(x.neg(), @boolToInt(not_square));
        x2 = Fe.zero;
        x2.cMov(Fe.edwards25519a, @boolToInt(not_square));
        x = x.sub(x2);

        // We have y = sqrt(gx1) or sqrt(gx2) with gx2 = gx1*(A+x1)/(-x1)
        // but it is about as fast to just recompute y from the curve equation.
        const y = xmontToYmont(x) catch unreachable;
        return .{ .x = x, .y = y, .not_square = not_square };
    }

    /// Map a 64-bit hash into an Edwards25519 point
    pub fn fromHash(h: [64]u8) Edwards25519 {
        const fe_f = Fe.fromBytes64(h);
        var elr = elligator2(fe_f);

        const y_sign = elr.not_square;
        const y_neg = elr.y.neg();
        elr.y.cMov(y_neg, @boolToInt(elr.y.isNegative()) ^ @boolToInt(y_sign));
        return montToEd(elr.x, elr.y).clearCofactor();
    }

    fn stringToPoints(comptime n: usize, ctx: []const u8, s: []const u8) [n]Edwards25519 {
        debug.assert(n <= 2);
        const H = crypto.hash.sha2.Sha512;
        const h_l: usize = 48;
        var xctx = ctx;
        var hctx: [H.digest_length]u8 = undefined;
        if (ctx.len > 0xff) {
            var st = H.init(.{});
            st.update("H2C-OVERSIZE-DST-");
            st.update(ctx);
            st.final(&hctx);
            xctx = hctx[0..];
        }
        const empty_block = [_]u8{0} ** H.block_length;
        var t = [3]u8{ 0, n * h_l, 0 };
        var xctx_len_u8 = [1]u8{@intCast(u8, xctx.len)};
        var st = H.init(.{});
        st.update(empty_block[0..]);
        st.update(s);
        st.update(t[0..]);
        st.update(xctx);
        st.update(xctx_len_u8[0..]);
        var u_0: [H.digest_length]u8 = undefined;
        st.final(&u_0);
        var u: [n * H.digest_length]u8 = undefined;
        var i: usize = 0;
        while (i < n * H.digest_length) : (i += H.digest_length) {
            mem.copy(u8, u[i..][0..H.digest_length], u_0[0..]);
            var j: usize = 0;
            while (i > 0 and j < H.digest_length) : (j += 1) {
                u[i + j] ^= u[i + j - H.digest_length];
            }
            t[2] += 1;
            st = H.init(.{});
            st.update(u[i..][0..H.digest_length]);
            st.update(t[2..3]);
            st.update(xctx);
            st.update(xctx_len_u8[0..]);
            st.final(u[i..][0..H.digest_length]);
        }
        var px: [n]Edwards25519 = undefined;
        i = 0;
        while (i < n) : (i += 1) {
            mem.set(u8, u_0[0 .. H.digest_length - h_l], 0);
            mem.copy(u8, u_0[H.digest_length - h_l ..][0..h_l], u[i * h_l ..][0..h_l]);
            px[i] = fromHash(u_0);
        }
        return px;
    }

    /// Hash a context `ctx` and a string `s` into an Edwards25519 point
    ///
    /// This function implements the edwards25519_XMD:SHA-512_ELL2_RO_ and edwards25519_XMD:SHA-512_ELL2_NU_
    /// methods from the "Hashing to Elliptic Curves" standard document.
    ///
    /// Although not strictly required by the standard, it is recommended to avoid NUL characters in
    /// the context in order to be compatible with other implementations.
    pub fn fromString(comptime random_oracle: bool, ctx: []const u8, s: []const u8) Edwards25519 {
        if (random_oracle) {
            const px = stringToPoints(2, ctx, s);
            return px[0].add(px[1]);
        } else {
            return stringToPoints(1, ctx, s)[0];
        }
    }

    /// Map a 32 bit uniform bit string into an edwards25519 point
    pub fn fromUniform(r: [32]u8) Edwards25519 {
        var s = r;
        const x_sign = s[31] >> 7;
        s[31] &= 0x7f;
        const elr = elligator2(Fe.fromBytes(s));
        var p = montToEd(elr.x, elr.y);
        const p_neg = p.neg();
        p.cMov(p_neg, @boolToInt(p.x.isNegative()) ^ x_sign);
        return p.clearCofactor();
    }
};

const htest = @import("../test.zig");

test "edwards25519 packing/unpacking" {
    const s = [_]u8{170} ++ [_]u8{0} ** 31;
    var b = Edwards25519.basePoint;
    const pk = try b.mul(s);
    var buf: [128]u8 = undefined;
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{s}", .{std.fmt.fmtSliceHexUpper(&pk.toBytes())}), "074BC7E0FCBD587FDBC0969444245FADC562809C8F6E97E949AF62484B5B81A6");

    const small_order_ss: [7][32]u8 = .{
        .{
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 0 (order 4)
        },
        .{
            0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 1 (order 1)
        },
        .{
            0x26, 0xe8, 0x95, 0x8f, 0xc2, 0xb2, 0x27, 0xb0, 0x45, 0xc3, 0xf4, 0x89, 0xf2, 0xef, 0x98, 0xf0, 0xd5, 0xdf, 0xac, 0x05, 0xd3, 0xc6, 0x33, 0x39, 0xb1, 0x38, 0x02, 0x88, 0x6d, 0x53, 0xfc, 0x05, // 270738550114484064931822528722565878893680426757531351946374360975030340202(order 8)
        },
        .{
            0xc7, 0x17, 0x6a, 0x70, 0x3d, 0x4d, 0xd8, 0x4f, 0xba, 0x3c, 0x0b, 0x76, 0x0d, 0x10, 0x67, 0x0f, 0x2a, 0x20, 0x53, 0xfa, 0x2c, 0x39, 0xcc, 0xc6, 0x4e, 0xc7, 0xfd, 0x77, 0x92, 0xac, 0x03, 0x7a, // 55188659117513257062467267217118295137698188065244968500265048394206261417927 (order 8)
        },
        .{
            0xec, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, // p-1 (order 2)
        },
        .{
            0xed, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, // p (=0, order 4)
        },
        .{
            0xee, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0x7f, // p+1 (=1, order 1)
        },
    };
    for (small_order_ss) |small_order_s| {
        const small_p = try Edwards25519.fromBytes(small_order_s);
        std.testing.expectError(error.WeakPublicKey, small_p.mul(s));
    }
}

test "edwards25519 point addition/substraction" {
    var s1: [32]u8 = undefined;
    var s2: [32]u8 = undefined;
    crypto.random.bytes(&s1);
    crypto.random.bytes(&s2);
    const p = try Edwards25519.basePoint.clampedMul(s1);
    const q = try Edwards25519.basePoint.clampedMul(s2);
    const r = p.add(q).add(q).sub(q).sub(q);
    try r.rejectIdentity();
    std.testing.expectError(error.IdentityElement, r.sub(p).rejectIdentity());
    std.testing.expectError(error.IdentityElement, p.sub(p).rejectIdentity());
    std.testing.expectError(error.IdentityElement, p.sub(q).add(q).sub(p).rejectIdentity());
}

test "edwards25519 uniform-to-point" {
    var r = [32]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31 };
    var p = Edwards25519.fromUniform(r);
    htest.assertEqual("0691eee3cf70a0056df6bfa03120635636581b5c4ea571dfc680f78c7e0b4137", p.toBytes()[0..]);

    r[31] = 0xff;
    p = Edwards25519.fromUniform(r);
    htest.assertEqual("f70718e68ef42d90ca1d936bb2d7e159be6c01d8095d39bd70487c82fe5c973a", p.toBytes()[0..]);
}

// Test vectors from draft-irtf-cfrg-hash-to-curve-10
test "edwards25519 hash-to-curve operation" {
    var p = Edwards25519.fromString(true, "QUUX-V01-CS02-with-edwards25519_XMD:SHA-512_ELL2_RO_", "abc");
    htest.assertEqual("31558a26887f23fb8218f143e69d5f0af2e7831130bd5b432ef23883b895831a", p.toBytes()[0..]);

    p = Edwards25519.fromString(false, "QUUX-V01-CS02-with-edwards25519_XMD:SHA-512_ELL2_NU_", "abc");
    htest.assertEqual("42fa27c8f5a1ae0aa38bb59d5938e5145622ba5dedd11d11736fa2f9502d73e7", p.toBytes()[0..]);
}
