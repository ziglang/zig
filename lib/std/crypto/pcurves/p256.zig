// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std");
const builtin = std.builtin;
const crypto = std.crypto;
const mem = std.mem;
const meta = std.meta;

const EncodingError = crypto.errors.EncodingError;
const IdentityElementError = crypto.errors.IdentityElementError;
const NonCanonicalError = crypto.errors.NonCanonicalError;
const NotSquareError = crypto.errors.NotSquareError;

/// Group operations over P256.
pub const P256 = struct {
    /// The underlying prime field.
    pub const Fe = @import("p256/field.zig").Fe;
    /// Field arithmetic mod the order of the main subgroup.
    pub const scalar = @import("p256/scalar.zig");

    x: Fe,
    y: Fe,
    z: Fe = Fe.one,

    is_base: bool = false,

    /// The P256 base point.
    pub const basePoint = P256{
        .x = try Fe.fromInt(48439561293906451759052585252797914202762949526041747995844080717082404635286),
        .y = try Fe.fromInt(36134250956749795798585127919587881956611106672985015071877198253568414405109),
        .z = Fe.one,
        .is_base = true,
    };

    /// The P256 neutral element.
    pub const identityElement = P256{ .x = Fe.zero, .y = Fe.one, .z = Fe.zero };

    pub const B = try Fe.fromInt(41058363725152142129326129780047268409114441015993725554835256314039467401291);

    /// Reject the neutral element.
    pub fn rejectIdentity(p: P256) IdentityElementError!void {
        if (p.x.isZero()) {
            return error.IdentityElement;
        }
    }

    /// Create a point from affine coordinates after checking that they match the curve equation.
    pub fn fromAffineCoordinates(x: Fe, y: Fe) EncodingError!P256 {
        const x3AxB = x.sq().mul(x).sub(x).sub(x).sub(x).add(B);
        const yy = y.sq();
        if (!x3AxB.equivalent(yy)) {
            return error.InvalidEncoding;
        }
        const p: P256 = .{ .x = x, .y = y, .z = Fe.one };
        return p;
    }

    /// Create a point from serialized affine coordinates.
    pub fn fromSerializedAffineCoordinates(xs: [32]u8, ys: [32]u8, endian: builtin.Endian) (NonCanonicalError || EncodingError)!P256 {
        const x = try Fe.fromBytes(xs, endian);
        const y = try Fe.fromBytes(ys, endian);
        return fromAffineCoordinates(x, y);
    }

    /// Recover the Y coordinate from the X coordinate.
    pub fn recoverY(x: Fe, is_odd: bool) NotSquareError!Fe {
        const x3AxB = x.sq().mul(x).sub(x).sub(x).sub(x).add(B);
        var y = try x3AxB.sqrt();
        const yn = y.neg();
        y.cMov(yn, @boolToInt(is_odd) ^ @boolToInt(y.isOdd()));
        return y;
    }

    /// Deserialize a SEC1-encoded point.
    pub fn fromSec1(s: []const u8) (EncodingError || NotSquareError || NonCanonicalError)!P256 {
        if (s.len < 1) return error.InvalidEncoding;
        const encoding_type = s[0];
        const encoded = s[1..];
        switch (encoding_type) {
            0 => {
                if (encoded.len != 0) return error.InvalidEncoding;
                return P256.identityElement;
            },
            2, 3 => {
                if (encoded.len != 32) return error.InvalidEncoding;
                const x = try Fe.fromBytes(encoded[0..32].*, .Big);
                const y_is_odd = (encoding_type == 3);
                const y = try recoverY(x, y_is_odd);
                return P256{ .x = x, .y = y };
            },
            4 => {
                if (encoded.len != 64) return error.InvalidEncoding;
                const x = try Fe.fromBytes(encoded[0..32].*, .Big);
                const y = try Fe.fromBytes(encoded[32..64].*, .Big);
                return P256.fromAffineCoordinates(x, y);
            },
            else => return error.InvalidEncoding,
        }
    }

    /// Serialize a point using the compressed SEC-1 format.
    pub fn toCompressedSec1(p: P256) [33]u8 {
        var out: [33]u8 = undefined;
        const xy = p.affineCoordinates();
        out[0] = if (xy.y.isOdd()) 3 else 2;
        mem.copy(u8, out[1..], &xy.x.toBytes(.Big));
        return out;
    }

    /// Serialize a point using the uncompressed SEC-1 format.
    pub fn toUncompressedSec1(p: P256) [65]u8 {
        var out: [65]u8 = undefined;
        out[0] = 4;
        const xy = p.affineCoordinates();
        mem.copy(u8, out[1..33], &xy.x.toBytes(.Big));
        mem.copy(u8, out[33..65], &xy.y.toBytes(.Big));
        return out;
    }

    /// Return a random point.
    pub fn random() P256 {
        const n = scalar.random(.Little);
        return basePoint.mul(n, .Little) catch unreachable;
    }

    /// Flip the sign of the X coordinate.
    pub fn neg(p: P256) P256 {
        return .{ .x = p.x, .y = p.y.neg(), .z = p.z };
    }

    /// Double a P256 point.
    // Algorithm 6 from https://eprint.iacr.org/2015/1060.pdf
    pub fn dbl(p: P256) P256 {
        var t0 = p.x.sq();
        var t1 = p.y.sq();
        var t2 = p.z.sq();
        var t3 = p.x.mul(p.y);
        t3 = t3.dbl();
        var Z3 = p.x.mul(p.z);
        Z3 = Z3.add(Z3);
        var Y3 = B.mul(t2);
        Y3 = Y3.sub(Z3);
        var X3 = Y3.dbl();
        Y3 = X3.add(Y3);
        X3 = t1.sub(Y3);
        Y3 = t1.add(Y3);
        Y3 = X3.mul(Y3);
        X3 = X3.mul(t3);
        t3 = t2.dbl();
        t2 = t2.add(t3);
        Z3 = B.mul(Z3);
        Z3 = Z3.sub(t2);
        Z3 = Z3.sub(t0);
        t3 = Z3.dbl();
        Z3 = Z3.add(t3);
        t3 = t0.dbl();
        t0 = t3.add(t0);
        t0 = t0.sub(t2);
        t0 = t0.mul(Z3);
        Y3 = Y3.add(t0);
        t0 = p.y.mul(p.z);
        t0 = t0.dbl();
        Z3 = t0.mul(Z3);
        X3 = X3.sub(Z3);
        Z3 = t0.mul(t1);
        Z3 = Z3.dbl().dbl();
        return .{
            .x = X3,
            .y = Y3,
            .z = Z3,
        };
    }

    /// Add P256 points, the second being specified using affine coordinates.
    // Algorithm 5 from https://eprint.iacr.org/2015/1060.pdf
    pub fn addMixed(p: P256, q: struct { x: Fe, y: Fe }) P256 {
        var t0 = p.x.mul(q.x);
        var t1 = p.y.mul(q.y);
        var t3 = q.x.add(q.y);
        var t4 = p.x.add(p.y);
        t3 = t3.mul(t4);
        t4 = t0.add(t1);
        t3 = t3.sub(t4);
        t4 = q.y.mul(p.z);
        t4 = t4.add(p.y);
        var Y3 = q.x.mul(p.z);
        Y3 = Y3.add(p.x);
        var Z3 = B.mul(p.z);
        var X3 = Y3.sub(Z3);
        Z3 = X3.dbl();
        X3 = X3.add(Z3);
        Z3 = t1.sub(X3);
        X3 = t1.dbl();
        Y3 = B.mul(Y3);
        t1 = p.z.add(p.z);
        var t2 = t1.add(p.z);
        Y3 = Y3.sub(t2);
        Y3 = Y3.sub(t0);
        t1 = Y3.dbl();
        Y3 = t1.add(Y3);
        t1 = t0.dbl();
        t0 = t1.add(t0);
        t0 = t0.sub(t2);
        t1 = t4.mul(Y3);
        t2 = t0.mul(Y3);
        Y3 = X3.mul(Z3);
        Y3 = Y3.add(t2);
        X3 = t3.mul(X3);
        X3 = X3.sub(t1);
        Z3 = t4.mul(Z3);
        t1 = t3.mul(t0);
        Z3 = Z3.add(t1);
        return .{
            .x = X3,
            .y = Y3,
            .z = Z3,
        };
    }

    // Add P256 points.
    // Algorithm 4 from https://eprint.iacr.org/2015/1060.pdf
    pub fn add(p: P256, q: P256) P256 {
        var t0 = p.x.mul(q.x);
        var t1 = p.y.mul(q.y);
        var t2 = p.z.mul(q.z);
        var t3 = p.x.add(p.y);
        var t4 = q.x.add(q.y);
        t3 = t3.mul(t4);
        t4 = t0.add(t1);
        t3 = t3.sub(t4);
        t4 = p.y.add(p.z);
        var X3 = q.y.add(q.z);
        t4 = t4.mul(X3);
        X3 = t1.add(t2);
        t4 = t4.sub(X3);
        X3 = p.x.add(p.z);
        var Y3 = q.x.add(q.z);
        X3 = X3.mul(Y3);
        Y3 = t0.add(t2);
        Y3 = X3.sub(Y3);
        var Z3 = B.mul(t2);
        X3 = Y3.sub(Z3);
        Z3 = X3.dbl();
        X3 = X3.add(Z3);
        Z3 = t1.sub(X3);
        X3 = t1.add(X3);
        Y3 = B.mul(Y3);
        t1 = t2.dbl();
        t2 = t1.add(t2);
        Y3 = Y3.sub(t2);
        Y3 = Y3.sub(t0);
        t1 = Y3.dbl();
        Y3 = t1.add(Y3);
        t1 = t0.dbl();
        t0 = t1.add(t0);
        t0 = t0.sub(t2);
        t1 = t4.mul(Y3);
        t2 = t0.mul(Y3);
        Y3 = X3.mul(Z3);
        Y3 = Y3.add(t2);
        X3 = t3.mul(X3);
        X3 = X3.sub(t1);
        Z3 = t4.mul(Z3);
        t1 = t3.mul(t0);
        Z3 = Z3.add(t1);
        return .{
            .x = X3,
            .y = Y3,
            .z = Z3,
        };
    }

    // Subtract P256 points.
    pub fn sub(p: P256, q: P256) P256 {
        return p.add(q.neg());
    }

    /// Return affine coordinates.
    pub fn affineCoordinates(p: P256) struct { x: Fe, y: Fe } {
        const zinv = p.z.invert();
        const ret = .{
            .x = p.x.mul(zinv),
            .y = p.y.mul(zinv),
        };
        return ret;
    }

    /// Return true if both coordinate sets represent the same point.
    pub fn equivalent(a: P256, b: P256) bool {
        if (a.sub(b).rejectIdentity()) {
            return false;
        } else |_| {
            return true;
        }
    }

    fn cMov(p: *P256, a: P256, c: u1) void {
        p.x.cMov(a.x, c);
        p.y.cMov(a.y, c);
        p.z.cMov(a.z, c);
    }

    fn pcSelect(comptime n: usize, pc: [n]P256, b: u8) P256 {
        var t = P256.identityElement;
        comptime var i: u8 = 1;
        inline while (i < pc.len) : (i += 1) {
            t.cMov(pc[i], @truncate(u1, (@as(usize, b ^ i) -% 1) >> 8));
        }
        return t;
    }

    fn slide(s: [32]u8) [2 * 32 + 1]i8 {
        var e: [2 * 32 + 1]i8 = undefined;
        for (s) |x, i| {
            e[i * 2 + 0] = @as(i8, @truncate(u4, x));
            e[i * 2 + 1] = @as(i8, @truncate(u4, x >> 4));
        }
        // Now, e[0..63] is between 0 and 15, e[63] is between 0 and 7
        var carry: i8 = 0;
        for (e[0..64]) |*x| {
            x.* += carry;
            carry = (x.* + 8) >> 4;
            x.* -= carry * 16;
            std.debug.assert(x.* >= -8 and x.* <= 8);
        }
        e[64] = carry;
        // Now, e[*] is between -8 and 8, including e[64]
        std.debug.assert(carry >= -8 and carry <= 8);
        return e;
    }

    fn pcMul(pc: [9]P256, s: [32]u8, comptime vartime: bool) IdentityElementError!P256 {
        std.debug.assert(vartime);
        const e = slide(s);
        var q = P256.identityElement;
        var pos = e.len - 1;
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

    fn pcMul16(pc: [16]P256, s: [32]u8, comptime vartime: bool) IdentityElementError!P256 {
        var q = P256.identityElement;
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

    fn precompute(p: P256, comptime count: usize) [1 + count]P256 {
        var pc: [1 + count]P256 = undefined;
        pc[0] = P256.identityElement;
        pc[1] = p;
        var i: usize = 2;
        while (i <= count) : (i += 1) {
            pc[i] = if (i % 2 == 0) pc[i / 2].dbl() else pc[i - 1].add(p);
        }
        return pc;
    }

    /// Multiply an elliptic curve point by a scalar.
    /// Return error.IdentityElement if the result is the identity element.
    pub fn mul(p: P256, s_: [32]u8, endian: builtin.Endian) IdentityElementError!P256 {
        const s = if (endian == .Little) s_ else Fe.orderSwap(s_);
        const pc = if (p.is_base) precompute(P256.basePoint, 15) else pc: {
            try p.rejectIdentity();
            const xpc = precompute(p, 15);
            break :pc xpc;
        };
        return pcMul16(pc, s, false);
    }

    /// Multiply an elliptic curve point by a *PUBLIC* scalar *IN VARIABLE TIME*
    /// This can be used for signature verification.
    pub fn mulPublic(p: P256, s_: [32]u8, endian: builtin.Endian) IdentityElementError!P256 {
        const s = if (endian == .Little) s_ else Fe.orderSwap(s_);
        const pc = if (p.is_base) precompute(P256.basePoint, 8) else pc: {
            try p.rejectIdentity();
            const xpc = precompute(p, 8);
            break :pc xpc;
        };
        return pcMul(pc, s, true);
    }
};

test "p256" {
    _ = @import("tests.zig");
}
