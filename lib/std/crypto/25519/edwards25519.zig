// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const fmt = std.fmt;

/// Group operations over Edwards25519.
pub const Edwards25519 = struct {
    /// The underlying prime field.
    pub const Fe = @import("field.zig").Fe;
    /// Field arithmetic mod the order of the main subgroup.
    pub const scalar = @import("scalar.zig");

    x: Fe,
    y: Fe,
    z: Fe,
    t: Fe,

    is_base: bool = false,

    /// Decode an Edwards25519 point from its compressed (Y+sign) coordinates.
    pub fn fromBytes(s: [32]u8) !Edwards25519 {
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
    pub fn toBytes(p: Edwards25519) [32]u8 {
        const zi = p.z.invert();
        var s = p.y.mul(zi).toBytes();
        s[31] ^= @as(u8, @boolToInt(p.x.mul(zi).isNegative())) << 7;
        return s;
    }

    /// Check that the encoding of a point is canonical.
    pub fn rejectNonCanonical(s: [32]u8) !void {
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

    const identityElement = Edwards25519{ .x = Fe.zero, .y = Fe.one, .z = Fe.one, .t = Fe.zero };

    /// Reject the neutral element.
    pub fn rejectIdentity(p: Edwards25519) !void {
        if (p.x.isZero()) {
            return error.IdentityElement;
        }
    }

    /// Flip the sign of the X coordinate.
    pub inline fn neg(p: Edwards25519) Edwards25519 {
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

    inline fn cMov(p: *Edwards25519, a: Edwards25519, c: u64) void {
        p.x.cMov(a.x, c);
        p.y.cMov(a.y, c);
        p.z.cMov(a.z, c);
        p.t.cMov(a.t, c);
    }

    inline fn pcSelect(pc: [16]Edwards25519, b: u8) Edwards25519 {
        var t = Edwards25519.identityElement;
        comptime var i: u8 = 0;
        inline while (i < 16) : (i += 1) {
            t.cMov(pc[i], ((@as(usize, b ^ i) -% 1) >> 8) & 1);
        }
        return t;
    }

    fn pcMul(pc: [16]Edwards25519, s: [32]u8) !Edwards25519 {
        var q = Edwards25519.identityElement;
        var pos: usize = 252;
        while (true) : (pos -= 4) {
            q = q.dbl().dbl().dbl().dbl();
            const bit = (s[pos >> 3] >> @truncate(u3, pos)) & 0xf;
            q = q.add(pcSelect(pc, bit));
            if (pos == 0) break;
        }
        try q.rejectIdentity();
        return q;
    }

    fn precompute(p: Edwards25519) [16]Edwards25519 {
        var pc: [16]Edwards25519 = undefined;
        pc[0] = Edwards25519.identityElement;
        pc[1] = p;
        var i: usize = 2;
        while (i < 16) : (i += 1) {
            pc[i] = pc[i - 1].add(p);
        }
        return pc;
    }

    /// Multiply an Edwards25519 point by a scalar without clamping it.
    /// Return error.WeakPublicKey if the resulting point is
    /// the identity element.
    pub fn mul(p: Edwards25519, s: [32]u8) !Edwards25519 {
        var pc: [16]Edwards25519 = undefined;
        if (p.is_base) {
            @setEvalBranchQuota(10000);
            pc = comptime precompute(Edwards25519.basePoint);
        } else {
            pc = precompute(p);
            pc[4].rejectIdentity() catch |_| return error.WeakPublicKey;
        }
        return pcMul(pc, s);
    }

    /// Multiply an Edwards25519 point by a scalar after "clamping" it.
    /// Clamping forces the scalar to be a multiple of the cofactor in
    /// order to prevent small subgroups attacks.
    /// This is strongly recommended for DH operations.
    /// Return error.WeakPublicKey if the resulting point is
    /// the identity element.
    pub fn clampedMul(p: Edwards25519, s: [32]u8) !Edwards25519 {
        var t: [32]u8 = s;
        scalar.clamp(&t);
        return mul(p, t);
    }
};

test "edwards25519 packing/unpacking" {
    const s = [_]u8{170} ++ [_]u8{0} ** 31;
    var b = Edwards25519.basePoint;
    const pk = try b.mul(s);
    var buf: [128]u8 = undefined;
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{X}", .{pk.toBytes()}), "074BC7E0FCBD587FDBC0969444245FADC562809C8F6E97E949AF62484B5B81A6");

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
