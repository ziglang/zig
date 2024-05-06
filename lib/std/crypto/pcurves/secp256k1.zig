const std = @import("std");
const crypto = std.crypto;
const math = std.math;
const mem = std.mem;
const meta = std.meta;

const EncodingError = crypto.errors.EncodingError;
const IdentityElementError = crypto.errors.IdentityElementError;
const NonCanonicalError = crypto.errors.NonCanonicalError;
const NotSquareError = crypto.errors.NotSquareError;

/// Group operations over secp256k1.
pub const Secp256k1 = struct {
    /// The underlying prime field.
    pub const Fe = @import("secp256k1/field.zig").Fe;
    /// Field arithmetic mod the order of the main subgroup.
    pub const scalar = @import("secp256k1/scalar.zig");

    x: Fe,
    y: Fe,
    z: Fe = Fe.one,

    is_base: bool = false,

    /// The secp256k1 base point.
    pub const basePoint = Secp256k1{
        .x = Fe.fromInt(55066263022277343669578718895168534326250603453777594175500187360389116729240) catch unreachable,
        .y = Fe.fromInt(32670510020758816978083085130507043184471273380659243275938904335757337482424) catch unreachable,
        .z = Fe.one,
        .is_base = true,
    };

    /// The secp256k1 neutral element.
    pub const identityElement = Secp256k1{ .x = Fe.zero, .y = Fe.one, .z = Fe.zero };

    pub const B = Fe.fromInt(7) catch unreachable;

    pub const Endormorphism = struct {
        const lambda: u256 = 37718080363155996902926221483475020450927657555482586988616620542887997980018;
        const beta: u256 = 55594575648329892869085402983802832744385952214688224221778511981742606582254;

        const lambda_s = s: {
            var buf: [32]u8 = undefined;
            mem.writeInt(u256, &buf, Endormorphism.lambda, .little);
            break :s buf;
        };

        pub const SplitScalar = struct {
            r1: [32]u8,
            r2: [32]u8,
        };

        /// Compute r1 and r2 so that k = r1 + r2*lambda (mod L).
        pub fn splitScalar(s: [32]u8, endian: std.builtin.Endian) NonCanonicalError!SplitScalar {
            const b1_neg_s = comptime s: {
                var buf: [32]u8 = undefined;
                mem.writeInt(u256, &buf, 303414439467246543595250775667605759171, .little);
                break :s buf;
            };
            const b2_neg_s = comptime s: {
                var buf: [32]u8 = undefined;
                mem.writeInt(u256, &buf, scalar.field_order - 64502973549206556628585045361533709077, .little);
                break :s buf;
            };
            const k = mem.readInt(u256, &s, endian);

            const t1 = math.mulWide(u256, k, 21949224512762693861512883645436906316123769664773102907882521278123970637873);
            const t2 = math.mulWide(u256, k, 103246583619904461035481197785446227098457807945486720222659797044629401272177);

            const c1 = @as(u128, @truncate(t1 >> 384)) + @as(u1, @truncate(t1 >> 383));
            const c2 = @as(u128, @truncate(t2 >> 384)) + @as(u1, @truncate(t2 >> 383));

            var buf: [32]u8 = undefined;

            mem.writeInt(u256, &buf, c1, .little);
            const c1x = try scalar.mul(buf, b1_neg_s, .little);

            mem.writeInt(u256, &buf, c2, .little);
            const c2x = try scalar.mul(buf, b2_neg_s, .little);

            const r2 = try scalar.add(c1x, c2x, .little);

            var r1 = try scalar.mul(r2, lambda_s, .little);
            r1 = try scalar.sub(s, r1, .little);

            return SplitScalar{ .r1 = r1, .r2 = r2 };
        }
    };

    /// Reject the neutral element.
    pub fn rejectIdentity(p: Secp256k1) IdentityElementError!void {
        const affine_0 = @intFromBool(p.x.equivalent(AffineCoordinates.identityElement.x)) & (@intFromBool(p.y.isZero()) | @intFromBool(p.y.equivalent(AffineCoordinates.identityElement.y)));
        const is_identity = @intFromBool(p.z.isZero()) | affine_0;
        if (is_identity != 0) {
            return error.IdentityElement;
        }
    }

    /// Create a point from affine coordinates after checking that they match the curve equation.
    pub fn fromAffineCoordinates(p: AffineCoordinates) EncodingError!Secp256k1 {
        const x = p.x;
        const y = p.y;
        const x3B = x.sq().mul(x).add(B);
        const yy = y.sq();
        const on_curve = @intFromBool(x3B.equivalent(yy));
        const is_identity = @intFromBool(x.equivalent(AffineCoordinates.identityElement.x)) & @intFromBool(y.equivalent(AffineCoordinates.identityElement.y));
        if ((on_curve | is_identity) == 0) {
            return error.InvalidEncoding;
        }
        var ret = Secp256k1{ .x = x, .y = y, .z = Fe.one };
        ret.z.cMov(Secp256k1.identityElement.z, is_identity);
        return ret;
    }

    /// Create a point from serialized affine coordinates.
    pub fn fromSerializedAffineCoordinates(xs: [32]u8, ys: [32]u8, endian: std.builtin.Endian) (NonCanonicalError || EncodingError)!Secp256k1 {
        const x = try Fe.fromBytes(xs, endian);
        const y = try Fe.fromBytes(ys, endian);
        return fromAffineCoordinates(.{ .x = x, .y = y });
    }

    /// Recover the Y coordinate from the X coordinate.
    pub fn recoverY(x: Fe, is_odd: bool) NotSquareError!Fe {
        const x3B = x.sq().mul(x).add(B);
        var y = try x3B.sqrt();
        const yn = y.neg();
        y.cMov(yn, @intFromBool(is_odd) ^ @intFromBool(y.isOdd()));
        return y;
    }

    /// Deserialize a SEC1-encoded point.
    pub fn fromSec1(s: []const u8) (EncodingError || NotSquareError || NonCanonicalError)!Secp256k1 {
        if (s.len < 1) return error.InvalidEncoding;
        const encoding_type = s[0];
        const encoded = s[1..];
        switch (encoding_type) {
            0 => {
                if (encoded.len != 0) return error.InvalidEncoding;
                return Secp256k1.identityElement;
            },
            2, 3 => {
                if (encoded.len != 32) return error.InvalidEncoding;
                const x = try Fe.fromBytes(encoded[0..32].*, .big);
                const y_is_odd = (encoding_type == 3);
                const y = try recoverY(x, y_is_odd);
                return Secp256k1{ .x = x, .y = y };
            },
            4 => {
                if (encoded.len != 64) return error.InvalidEncoding;
                const x = try Fe.fromBytes(encoded[0..32].*, .big);
                const y = try Fe.fromBytes(encoded[32..64].*, .big);
                return Secp256k1.fromAffineCoordinates(.{ .x = x, .y = y });
            },
            else => return error.InvalidEncoding,
        }
    }

    /// Serialize a point using the compressed SEC-1 format.
    pub fn toCompressedSec1(p: Secp256k1) [33]u8 {
        var out: [33]u8 = undefined;
        const xy = p.affineCoordinates();
        out[0] = if (xy.y.isOdd()) 3 else 2;
        out[1..].* = xy.x.toBytes(.big);
        return out;
    }

    /// Serialize a point using the uncompressed SEC-1 format.
    pub fn toUncompressedSec1(p: Secp256k1) [65]u8 {
        var out: [65]u8 = undefined;
        out[0] = 4;
        const xy = p.affineCoordinates();
        out[1..33].* = xy.x.toBytes(.big);
        out[33..65].* = xy.y.toBytes(.big);
        return out;
    }

    /// Return a random point.
    pub fn random() Secp256k1 {
        const n = scalar.random(.little);
        return basePoint.mul(n, .little) catch unreachable;
    }

    /// Flip the sign of the X coordinate.
    pub fn neg(p: Secp256k1) Secp256k1 {
        return .{ .x = p.x, .y = p.y.neg(), .z = p.z };
    }

    /// Double a secp256k1 point.
    // Algorithm 9 from https://eprint.iacr.org/2015/1060.pdf
    pub fn dbl(p: Secp256k1) Secp256k1 {
        var t0 = p.y.sq();
        var Z3 = t0.dbl();
        Z3 = Z3.dbl();
        Z3 = Z3.dbl();
        var t1 = p.y.mul(p.z);
        var t2 = p.z.sq();
        // b3 = (2^2)^2 + 2^2 + 1
        const t2_4 = t2.dbl().dbl();
        t2 = t2_4.dbl().dbl().add(t2_4).add(t2);
        var X3 = t2.mul(Z3);
        var Y3 = t0.add(t2);
        Z3 = t1.mul(Z3);
        t1 = t2.dbl();
        t2 = t1.add(t2);
        t0 = t0.sub(t2);
        Y3 = t0.mul(Y3);
        Y3 = X3.add(Y3);
        t1 = p.x.mul(p.y);
        X3 = t0.mul(t1);
        X3 = X3.dbl();
        return .{
            .x = X3,
            .y = Y3,
            .z = Z3,
        };
    }

    /// Add secp256k1 points, the second being specified using affine coordinates.
    // Algorithm 8 from https://eprint.iacr.org/2015/1060.pdf
    pub fn addMixed(p: Secp256k1, q: AffineCoordinates) Secp256k1 {
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
        var X3 = t0.dbl();
        t0 = X3.add(t0);
        // b3 = (2^2)^2 + 2^2 + 1
        const t2_4 = p.z.dbl().dbl();
        var t2 = t2_4.dbl().dbl().add(t2_4).add(p.z);
        var Z3 = t1.add(t2);
        t1 = t1.sub(t2);
        const Y3_4 = Y3.dbl().dbl();
        Y3 = Y3_4.dbl().dbl().add(Y3_4).add(Y3);
        X3 = t4.mul(Y3);
        t2 = t3.mul(t1);
        X3 = t2.sub(X3);
        Y3 = Y3.mul(t0);
        t1 = t1.mul(Z3);
        Y3 = t1.add(Y3);
        t0 = t0.mul(t3);
        Z3 = Z3.mul(t4);
        Z3 = Z3.add(t0);

        var ret = Secp256k1{
            .x = X3,
            .y = Y3,
            .z = Z3,
        };
        ret.cMov(p, @intFromBool(q.x.isZero()));
        return ret;
    }

    /// Add secp256k1 points.
    // Algorithm 7 from https://eprint.iacr.org/2015/1060.pdf
    pub fn add(p: Secp256k1, q: Secp256k1) Secp256k1 {
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
        X3 = t0.dbl();
        t0 = X3.add(t0);
        // b3 = (2^2)^2 + 2^2 + 1
        const t2_4 = t2.dbl().dbl();
        t2 = t2_4.dbl().dbl().add(t2_4).add(t2);
        var Z3 = t1.add(t2);
        t1 = t1.sub(t2);
        const Y3_4 = Y3.dbl().dbl();
        Y3 = Y3_4.dbl().dbl().add(Y3_4).add(Y3);
        X3 = t4.mul(Y3);
        t2 = t3.mul(t1);
        X3 = t2.sub(X3);
        Y3 = Y3.mul(t0);
        t1 = t1.mul(Z3);
        Y3 = t1.add(Y3);
        t0 = t0.mul(t3);
        Z3 = Z3.mul(t4);
        Z3 = Z3.add(t0);

        return .{
            .x = X3,
            .y = Y3,
            .z = Z3,
        };
    }

    /// Subtract secp256k1 points.
    pub fn sub(p: Secp256k1, q: Secp256k1) Secp256k1 {
        return p.add(q.neg());
    }

    /// Subtract secp256k1 points, the second being specified using affine coordinates.
    pub fn subMixed(p: Secp256k1, q: AffineCoordinates) Secp256k1 {
        return p.addMixed(q.neg());
    }

    /// Return affine coordinates.
    pub fn affineCoordinates(p: Secp256k1) AffineCoordinates {
        const affine_0 = @intFromBool(p.x.equivalent(AffineCoordinates.identityElement.x)) & (@intFromBool(p.y.isZero()) | @intFromBool(p.y.equivalent(AffineCoordinates.identityElement.y)));
        const is_identity = @intFromBool(p.z.isZero()) | affine_0;
        const zinv = p.z.invert();
        var ret = AffineCoordinates{
            .x = p.x.mul(zinv),
            .y = p.y.mul(zinv),
        };
        ret.cMov(AffineCoordinates.identityElement, is_identity);
        return ret;
    }

    /// Return true if both coordinate sets represent the same point.
    pub fn equivalent(a: Secp256k1, b: Secp256k1) bool {
        if (a.sub(b).rejectIdentity()) {
            return false;
        } else |_| {
            return true;
        }
    }

    fn cMov(p: *Secp256k1, a: Secp256k1, c: u1) void {
        p.x.cMov(a.x, c);
        p.y.cMov(a.y, c);
        p.z.cMov(a.z, c);
    }

    fn pcSelect(comptime n: usize, pc: *const [n]Secp256k1, b: u8) Secp256k1 {
        var t = Secp256k1.identityElement;
        comptime var i: u8 = 1;
        inline while (i < pc.len) : (i += 1) {
            t.cMov(pc[i], @as(u1, @truncate((@as(usize, b ^ i) -% 1) >> 8)));
        }
        return t;
    }

    fn slide(s: [32]u8) [2 * 32 + 1]i8 {
        var e: [2 * 32 + 1]i8 = undefined;
        for (s, 0..) |x, i| {
            e[i * 2 + 0] = @as(i8, @as(u4, @truncate(x)));
            e[i * 2 + 1] = @as(i8, @as(u4, @truncate(x >> 4)));
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

    fn pcMul(pc: *const [9]Secp256k1, s: [32]u8, comptime vartime: bool) IdentityElementError!Secp256k1 {
        std.debug.assert(vartime);
        const e = slide(s);
        var q = Secp256k1.identityElement;
        var pos = e.len - 1;
        while (true) : (pos -= 1) {
            const slot = e[pos];
            if (slot > 0) {
                q = q.add(pc[@as(usize, @intCast(slot))]);
            } else if (slot < 0) {
                q = q.sub(pc[@as(usize, @intCast(-slot))]);
            }
            if (pos == 0) break;
            q = q.dbl().dbl().dbl().dbl();
        }
        try q.rejectIdentity();
        return q;
    }

    fn pcMul16(pc: *const [16]Secp256k1, s: [32]u8, comptime vartime: bool) IdentityElementError!Secp256k1 {
        var q = Secp256k1.identityElement;
        var pos: usize = 252;
        while (true) : (pos -= 4) {
            const slot = @as(u4, @truncate((s[pos >> 3] >> @as(u3, @truncate(pos)))));
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

    fn precompute(p: Secp256k1, comptime count: usize) [1 + count]Secp256k1 {
        var pc: [1 + count]Secp256k1 = undefined;
        pc[0] = Secp256k1.identityElement;
        pc[1] = p;
        var i: usize = 2;
        while (i <= count) : (i += 1) {
            pc[i] = if (i % 2 == 0) pc[i / 2].dbl() else pc[i - 1].add(p);
        }
        return pc;
    }

    const basePointPc = pc: {
        @setEvalBranchQuota(50000);
        break :pc precompute(Secp256k1.basePoint, 15);
    };

    /// Multiply an elliptic curve point by a scalar.
    /// Return error.IdentityElement if the result is the identity element.
    pub fn mul(p: Secp256k1, s_: [32]u8, endian: std.builtin.Endian) IdentityElementError!Secp256k1 {
        const s = if (endian == .little) s_ else Fe.orderSwap(s_);
        if (p.is_base) {
            return pcMul16(&basePointPc, s, false);
        }
        try p.rejectIdentity();
        const pc = precompute(p, 15);
        return pcMul16(&pc, s, false);
    }

    /// Multiply an elliptic curve point by a *PUBLIC* scalar *IN VARIABLE TIME*
    /// This can be used for signature verification.
    pub fn mulPublic(p: Secp256k1, s_: [32]u8, endian: std.builtin.Endian) (IdentityElementError || NonCanonicalError)!Secp256k1 {
        const s = if (endian == .little) s_ else Fe.orderSwap(s_);
        const zero = comptime scalar.Scalar.zero.toBytes(.little);
        if (mem.eql(u8, &zero, &s)) {
            return error.IdentityElement;
        }
        const pc = precompute(p, 8);
        var lambda_p = try pcMul(&pc, Endormorphism.lambda_s, true);
        var split_scalar = try Endormorphism.splitScalar(s, .little);
        var px = p;

        // If a key is negative, flip the sign to keep it half-sized,
        // and flip the sign of the Y point coordinate to compensate.
        if (split_scalar.r1[split_scalar.r1.len / 2] != 0) {
            split_scalar.r1 = scalar.neg(split_scalar.r1, .little) catch zero;
            px = px.neg();
        }
        if (split_scalar.r2[split_scalar.r2.len / 2] != 0) {
            split_scalar.r2 = scalar.neg(split_scalar.r2, .little) catch zero;
            lambda_p = lambda_p.neg();
        }
        return mulDoubleBasePublicEndo(px, split_scalar.r1, lambda_p, split_scalar.r2);
    }

    // Half-size double-base public multiplication when using the curve endomorphism.
    // Scalars must be in little-endian.
    // The second point is unlikely to be the generator, so don't even try to use the comptime table for it.
    fn mulDoubleBasePublicEndo(p1: Secp256k1, s1: [32]u8, p2: Secp256k1, s2: [32]u8) IdentityElementError!Secp256k1 {
        var pc1_array: [9]Secp256k1 = undefined;
        const pc1 = if (p1.is_base) basePointPc[0..9] else pc: {
            pc1_array = precompute(p1, 8);
            break :pc &pc1_array;
        };
        const pc2 = precompute(p2, 8);
        std.debug.assert(s1[s1.len / 2] == 0);
        std.debug.assert(s2[s2.len / 2] == 0);
        const e1 = slide(s1);
        const e2 = slide(s2);
        var q = Secp256k1.identityElement;
        var pos: usize = 2 * 32 / 2; // second half is all zero
        while (true) : (pos -= 1) {
            const slot1 = e1[pos];
            if (slot1 > 0) {
                q = q.add(pc1[@as(usize, @intCast(slot1))]);
            } else if (slot1 < 0) {
                q = q.sub(pc1[@as(usize, @intCast(-slot1))]);
            }
            const slot2 = e2[pos];
            if (slot2 > 0) {
                q = q.add(pc2[@as(usize, @intCast(slot2))]);
            } else if (slot2 < 0) {
                q = q.sub(pc2[@as(usize, @intCast(-slot2))]);
            }
            if (pos == 0) break;
            q = q.dbl().dbl().dbl().dbl();
        }
        try q.rejectIdentity();
        return q;
    }

    /// Double-base multiplication of public parameters - Compute (p1*s1)+(p2*s2) *IN VARIABLE TIME*
    /// This can be used for signature verification.
    pub fn mulDoubleBasePublic(p1: Secp256k1, s1_: [32]u8, p2: Secp256k1, s2_: [32]u8, endian: std.builtin.Endian) IdentityElementError!Secp256k1 {
        const s1 = if (endian == .little) s1_ else Fe.orderSwap(s1_);
        const s2 = if (endian == .little) s2_ else Fe.orderSwap(s2_);
        try p1.rejectIdentity();
        var pc1_array: [9]Secp256k1 = undefined;
        const pc1 = if (p1.is_base) basePointPc[0..9] else pc: {
            pc1_array = precompute(p1, 8);
            break :pc &pc1_array;
        };
        try p2.rejectIdentity();
        var pc2_array: [9]Secp256k1 = undefined;
        const pc2 = if (p2.is_base) basePointPc[0..9] else pc: {
            pc2_array = precompute(p2, 8);
            break :pc &pc2_array;
        };
        const e1 = slide(s1);
        const e2 = slide(s2);
        var q = Secp256k1.identityElement;
        var pos: usize = 2 * 32;
        while (true) : (pos -= 1) {
            const slot1 = e1[pos];
            if (slot1 > 0) {
                q = q.add(pc1[@as(usize, @intCast(slot1))]);
            } else if (slot1 < 0) {
                q = q.sub(pc1[@as(usize, @intCast(-slot1))]);
            }
            const slot2 = e2[pos];
            if (slot2 > 0) {
                q = q.add(pc2[@as(usize, @intCast(slot2))]);
            } else if (slot2 < 0) {
                q = q.sub(pc2[@as(usize, @intCast(-slot2))]);
            }
            if (pos == 0) break;
            q = q.dbl().dbl().dbl().dbl();
        }
        try q.rejectIdentity();
        return q;
    }
};

/// A point in affine coordinates.
pub const AffineCoordinates = struct {
    x: Secp256k1.Fe,
    y: Secp256k1.Fe,

    /// Identity element in affine coordinates.
    pub const identityElement = AffineCoordinates{ .x = Secp256k1.identityElement.x, .y = Secp256k1.identityElement.y };

    fn cMov(p: *AffineCoordinates, a: AffineCoordinates, c: u1) void {
        p.x.cMov(a.x, c);
        p.y.cMov(a.y, c);
    }
};

test {
    if (@import("builtin").zig_backend == .stage2_c) return error.SkipZigTest;

    _ = @import("tests/secp256k1.zig");
}
