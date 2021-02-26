// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const fmt = std.fmt;

/// Group operations over Edwards25519.
pub const Ristretto255 = struct {
    /// The underlying elliptic curve.
    pub const Curve = @import("edwards25519.zig").Edwards25519;
    /// The underlying prime field.
    pub const Fe = Curve.Fe;
    /// Field arithmetic mod the order of the main subgroup.
    pub const scalar = Curve.scalar;
    /// Length in byte of an encoded element.
    pub const encoded_length: usize = 32;

    p: Curve,

    fn sqrtRatioM1(u: Fe, v: Fe) struct { ratio_is_square: u32, root: Fe } {
        const v3 = v.sq().mul(v); // v^3
        var x = v3.sq().mul(u).mul(v).pow2523().mul(v3).mul(u); // uv^3(uv^7)^((q-5)/8)
        const vxx = x.sq().mul(v); // vx^2
        const m_root_check = vxx.sub(u); // vx^2-u
        const p_root_check = vxx.add(u); // vx^2+u
        const f_root_check = u.mul(Fe.sqrtm1).add(vxx); // vx^2+u*sqrt(-1)
        const has_m_root = m_root_check.isZero();
        const has_p_root = p_root_check.isZero();
        const has_f_root = f_root_check.isZero();
        const x_sqrtm1 = x.mul(Fe.sqrtm1); // x*sqrt(-1)
        x.cMov(x_sqrtm1, @boolToInt(has_p_root) | @boolToInt(has_f_root));
        return .{ .ratio_is_square = @boolToInt(has_m_root) | @boolToInt(has_p_root), .root = x.abs() };
    }

    fn rejectNonCanonical(s: [encoded_length]u8) !void {
        if ((s[0] & 1) != 0) {
            return error.NonCanonical;
        }
        try Fe.rejectNonCanonical(s, false);
    }

    /// Reject the neutral element.
    pub fn rejectIdentity(p: Ristretto255) callconv(.Inline) !void {
        return p.p.rejectIdentity();
    }

    /// The base point (Ristretto is a curve in desguise).
    pub const basePoint = Ristretto255{ .p = Curve.basePoint };

    /// Decode a Ristretto255 representative.
    pub fn fromBytes(s: [encoded_length]u8) !Ristretto255 {
        try rejectNonCanonical(s);
        const s_ = Fe.fromBytes(s);
        const ss = s_.sq(); // s^2
        const u1_ = Fe.one.sub(ss); // (1-s^2)
        const u1u1 = u1_.sq(); // (1-s^2)^2
        const u2_ = Fe.one.add(ss); // (1+s^2)
        const u2u2 = u2_.sq(); // (1+s^2)^2
        const v = Fe.edwards25519d.mul(u1u1).neg().sub(u2u2); // -(d*u1^2)-u2^2
        const v_u2u2 = v.mul(u2u2); // v*u2^2

        const inv_sqrt = sqrtRatioM1(Fe.one, v_u2u2);
        var x = inv_sqrt.root.mul(u2_);
        const y = inv_sqrt.root.mul(x).mul(v).mul(u1_);
        x = x.mul(s_);
        x = x.add(x).abs();
        const t = x.mul(y);
        if ((1 - inv_sqrt.ratio_is_square) | @boolToInt(t.isNegative()) | @boolToInt(y.isZero()) != 0) {
            return error.InvalidEncoding;
        }
        const p: Curve = .{
            .x = x,
            .y = y,
            .z = Fe.one,
            .t = t,
        };
        return Ristretto255{ .p = p };
    }

    /// Encode to a Ristretto255 representative.
    pub fn toBytes(e: Ristretto255) [encoded_length]u8 {
        const p = &e.p;
        var u1_ = p.z.add(p.y); // Z+Y
        const zmy = p.z.sub(p.y); // Z-Y
        u1_ = u1_.mul(zmy); // (Z+Y)*(Z-Y)
        const u2_ = p.x.mul(p.y); // X*Y
        const u1_u2u2 = u2_.sq().mul(u1_); // u1*u2^2
        const inv_sqrt = sqrtRatioM1(Fe.one, u1_u2u2);
        const den1 = inv_sqrt.root.mul(u1_);
        const den2 = inv_sqrt.root.mul(u2_);
        const z_inv = den1.mul(den2).mul(p.t); // den1*den2*T
        const ix = p.x.mul(Fe.sqrtm1); // X*sqrt(-1)
        const iy = p.y.mul(Fe.sqrtm1); // Y*sqrt(-1)
        const eden = den1.mul(Fe.edwards25519sqrtamd); // den1/sqrt(a-d)
        const t_z_inv = p.t.mul(z_inv); // T*z_inv

        const rotate = @boolToInt(t_z_inv.isNegative());
        var x = p.x;
        var y = p.y;
        var den_inv = den2;
        x.cMov(iy, rotate);
        y.cMov(ix, rotate);
        den_inv.cMov(eden, rotate);

        const x_z_inv = x.mul(z_inv);
        const yneg = y.neg();
        y.cMov(yneg, @boolToInt(x_z_inv.isNegative()));

        return p.z.sub(y).mul(den_inv).abs().toBytes();
    }

    fn elligator(t: Fe) Curve {
        const r = t.sq().mul(Fe.sqrtm1); // sqrt(-1)*t^2
        const u = r.add(Fe.one).mul(Fe.edwards25519eonemsqd); // (r+1)*(1-d^2)
        var c = comptime Fe.one.neg(); // -1
        const v = c.sub(r.mul(Fe.edwards25519d)).mul(r.add(Fe.edwards25519d)); // (c-r*d)*(r+d)
        const ratio_sqrt = sqrtRatioM1(u, v);
        const wasnt_square = 1 - ratio_sqrt.ratio_is_square;
        var s = ratio_sqrt.root;
        const s_prime = s.mul(t).abs().neg(); // -|s*t|
        s.cMov(s_prime, wasnt_square);
        c.cMov(r, wasnt_square);

        const n = r.sub(Fe.one).mul(c).mul(Fe.edwards25519sqdmone).sub(v); // c*(r-1)*(d-1)^2-v
        const w0 = s.add(s).mul(v); // 2s*v
        const w1 = n.mul(Fe.edwards25519sqrtadm1); // n*sqrt(ad-1)
        const ss = s.sq(); // s^2
        const w2 = Fe.one.sub(ss); // 1-s^2
        const w3 = Fe.one.add(ss); // 1+s^2

        return .{ .x = w0.mul(w3), .y = w2.mul(w1), .z = w1.mul(w3), .t = w0.mul(w2) };
    }

    /// Map a 64-bit string into a Ristretto255 group element
    pub fn fromUniform(h: [64]u8) Ristretto255 {
        const p0 = elligator(Fe.fromBytes(h[0..32].*));
        const p1 = elligator(Fe.fromBytes(h[32..64].*));
        return Ristretto255{ .p = p0.add(p1) };
    }

    /// Double a Ristretto255 element.
    pub fn dbl(p: Ristretto255) callconv(.Inline) Ristretto255 {
        return .{ .p = p.p.dbl() };
    }

    /// Add two Ristretto255 elements.
    pub fn add(p: Ristretto255, q: Ristretto255) callconv(.Inline) Ristretto255 {
        return .{ .p = p.p.add(q.p) };
    }

    /// Multiply a Ristretto255 element with a scalar.
    /// Return error.WeakPublicKey if the resulting element is
    /// the identity element.
    pub fn mul(p: Ristretto255, s: [encoded_length]u8) callconv(.Inline) !Ristretto255 {
        return Ristretto255{ .p = try p.p.mul(s) };
    }

    /// Return true if two Ristretto255 elements are equivalent
    pub fn equivalent(p: Ristretto255, q: Ristretto255) bool {
        const p_ = &p.p;
        const q_ = &q.p;
        const a = p_.x.mul(q_.y).equivalent(p_.y.mul(q_.x));
        const b = p_.y.mul(q_.y).equivalent(p_.x.mul(q_.x));
        return (@boolToInt(a) | @boolToInt(b)) != 0;
    }
};

test "ristretto255" {
    const p = Ristretto255.basePoint;
    var buf: [256]u8 = undefined;
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{X}", .{p.toBytes()}), "E2F2AE0A6ABC4E71A884A961C500515F58E30B6AA582DD8DB6A65945E08D2D76");

    var r: [Ristretto255.encoded_length]u8 = undefined;
    _ = try fmt.hexToBytes(r[0..], "6a493210f7499cd17fecb510ae0cea23a110e8d5b901f8acadd3095c73a3b919");
    var q = try Ristretto255.fromBytes(r);
    q = q.dbl().add(p);
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{X}", .{q.toBytes()}), "E882B131016B52C1D3337080187CF768423EFCCBB517BB495AB812C4160FF44E");

    const s = [_]u8{15} ++ [_]u8{0} ** 31;
    const w = try p.mul(s);
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{X}", .{w.toBytes()}), "E0C418F7C8D9C4CDD7395B93EA124F3AD99021BB681DFC3302A9D99A2E53E64E");

    std.testing.expect(p.dbl().dbl().dbl().dbl().equivalent(w.add(p)));

    const h = [_]u8{69} ** 32 ++ [_]u8{42} ** 32;
    const ph = Ristretto255.fromUniform(h);
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{X}", .{ph.toBytes()}), "DCCA54E037A4311EFBEEF413ACD21D35276518970B7A61DC88F8587B493D5E19");
}
