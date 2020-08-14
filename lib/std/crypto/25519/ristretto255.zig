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

    p: Curve,

    fn sqrtRatioM1(u: Fe, v: Fe) !Fe {
        const v3 = v.sq().mul(v); // v^3
        var x = v3.sq().mul(u).mul(v).pow2523().mul(v3).mul(u); // uv^3(uv^7)^((q-5)/8)
        const vxx = x.sq().mul(v); // vx^2
        const m_root_check = vxx.sub(u); // vx^2-u
        const p_root_check = vxx.add(u); // vx^2+u
        const f_root_check = u.mul(Fe.sqrtm1()).add(vxx); // vx^2+u*sqrt(-1)
        const has_m_root = m_root_check.isZero();
        const has_p_root = p_root_check.isZero();
        const has_f_root = f_root_check.isZero();
        const x_sqrtm1 = x.mul(Fe.sqrtm1()); // x*sqrt(-1)
        x.cMov(x_sqrtm1, @boolToInt(has_p_root) | @boolToInt(has_f_root));
        x = x.abs();
        if ((@boolToInt(has_m_root) | @boolToInt(has_p_root)) == 0) {
            return error.NoRoot;
        }
        return x;
    }

    fn rejectNonCanonical(s: [32]u8) !void {
        if ((s[0] & 1) != 0) {
            return error.NonCanonical;
        }
        try Fe.rejectNonCanonical(s, false);
    }

    /// Reject the neutral element.
    pub inline fn rejectIdentity(p: Ristretto255) !void {
        return p.p.rejectIdentity();
    }

    /// Return the base point (Ristretto is a curve in desguise).
    pub inline fn basePoint() Ristretto255 {
        return .{ .p = Curve.basePoint() };
    }

    /// Decode a Ristretto255 representative.
    pub fn fromBytes(s: [32]u8) !Ristretto255 {
        try rejectNonCanonical(s);
        const s_ = Fe.fromBytes(s);
        const ss = s_.sq(); // s^2
        const u1_ = Fe.one().sub(ss); // (1-s^2)
        const u1u1 = u1_.sq(); // (1-s^2)^2
        const u2_ = Fe.one().add(ss); // (1+s^2)
        const u2u2 = u2_.sq(); // (1+s^2)^2
        const v = Fe.edwards25519d().mul(u1u1).neg().sub(u2u2); // -(d*u1^2)-u2^2
        const v_u2u2 = v.mul(u2u2); // v*u2^2
        const inv_sqrt = sqrtRatioM1(Fe.one(), v_u2u2) catch |e| {
            return error.InvalidEncoding;
        };
        var x = inv_sqrt.mul(u2_);
        const y = inv_sqrt.mul(x).mul(v).mul(u1_);
        x = x.mul(s_);
        x = x.add(x).abs();
        const t = x.mul(y);
        if ((@boolToInt(t.isNegative()) | @boolToInt(y.isZero())) != 0) {
            return error.InvalidEncoding;
        }
        const p: Curve = .{
            .x = x,
            .y = y,
            .z = Fe.one(),
            .t = t,
        };
        return Ristretto255 { .p = p };
    }

    /// Encode to a Ristretto255 representative.
    pub fn toBytes(e: Ristretto255) [32]u8 {
        const p = &e.p;
        var u1_ = p.z.add(p.y); // Z+Y
        const zmy = p.z.sub(p.y); // Z-Y
        u1_ = u1_.mul(zmy); // (Z+Y)*(Z-Y)
        const u2_ = p.x.mul(p.y); // X*Y
        const u1_u2u2 = u2_.sq().mul(u1_); // u1*u2^2
        const inv_sqrt = sqrtRatioM1(Fe.one(), u1_u2u2) catch unreachable;
        const den1 = inv_sqrt.mul(u1_);
        const den2 = inv_sqrt.mul(u2_);
        const z_inv = den1.mul(den2).mul(p.t); // den1*den2*T
        const ix = p.x.mul(Fe.sqrtm1()); // X*sqrt(-1)
        const iy = p.y.mul(Fe.sqrtm1()); // Y*sqrt(-1)
        const eden = den1.mul(Fe.edwards25519sqrtamd()); // den1/sqrt(a-d)
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

    /// Double a Ristretto255 element.
    pub inline fn dbl(p: Ristretto255) Ristretto255 {
        return .{ .p = p.p.dbl() };
    }

    /// Add two Ristretto255 elements.
    pub inline fn add(p: Ristretto255, q: Ristretto255) Ristretto255 {
        return .{ .p = p.p.add(q.p) };
    }

    /// Multiply a Ristretto255 element with a scalar.
    /// Return error.WeakPublicKey if the resulting element is
    /// the identity element.
    pub inline fn mul(p: Ristretto255, s: [32]u8) !Ristretto255 {
        return Ristretto255 { .p = try p.p.mul(s) };
    }
};

test "ristretto255" {
    const p = Ristretto255.basePoint();
    var buf: [256]u8 = undefined;
    const alloc = &std.heap.FixedBufferAllocator.init(&buf).allocator;
    std.testing.expectEqualStrings(try std.fmt.allocPrint(alloc, "{X}", .{p.toBytes()}), "E2F2AE0A6ABC4E71A884A961C500515F58E30B6AA582DD8DB6A65945E08D2D76");

    var r: [32]u8 = undefined;
    try fmt.hexToBytes(r[0..], "6a493210f7499cd17fecb510ae0cea23a110e8d5b901f8acadd3095c73a3b919");
    var q = try Ristretto255.fromBytes(r);
    q = q.dbl().add(p);
    std.testing.expectEqualStrings(try std.fmt.allocPrint(alloc, "{X}", .{q.toBytes()}), "E882B131016B52C1D3337080187CF768423EFCCBB517BB495AB812C4160FF44E");

    const s = [_]u8{15} ++ [_]u8{0} ** 31;
    const w = try p.mul(s);
    std.testing.expectEqualStrings(try std.fmt.allocPrint(alloc, "{X}", .{w.toBytes()}), "E0C418F7C8D9C4CDD7395B93EA124F3AD99021BB681DFC3302A9D99A2E53E64E");
}
