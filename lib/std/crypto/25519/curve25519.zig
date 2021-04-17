// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const crypto = std.crypto;

const IdentityElementError = crypto.errors.IdentityElementError;
const NonCanonicalError = crypto.errors.NonCanonicalError;
const WeakPublicKeyError = crypto.errors.WeakPublicKeyError;

/// Group operations over Curve25519.
pub const Curve25519 = struct {
    /// The underlying prime field.
    pub const Fe = @import("field.zig").Fe;
    /// Field arithmetic mod the order of the main subgroup.
    pub const scalar = @import("scalar.zig");

    x: Fe,

    /// Decode a Curve25519 point from its compressed (X) coordinates.
    pub fn fromBytes(s: [32]u8) callconv(.Inline) Curve25519 {
        return .{ .x = Fe.fromBytes(s) };
    }

    /// Encode a Curve25519 point.
    pub fn toBytes(p: Curve25519) callconv(.Inline) [32]u8 {
        return p.x.toBytes();
    }

    /// The Curve25519 base point.
    pub const basePoint = Curve25519{ .x = Fe.curve25519BasePoint };

    /// Check that the encoding of a Curve25519 point is canonical.
    pub fn rejectNonCanonical(s: [32]u8) NonCanonicalError!void {
        return Fe.rejectNonCanonical(s, false);
    }

    /// Reject the neutral element.
    pub fn rejectIdentity(p: Curve25519) IdentityElementError!void {
        if (p.x.isZero()) {
            return error.IdentityElement;
        }
    }

    /// Multiply a point by the cofactor
    pub fn clearCofactor(p: Edwards25519) Edwards25519 {
        return p.dbl().dbl().dbl();
    }

    fn ladder(p: Curve25519, s: [32]u8, comptime bits: usize) IdentityElementError!Curve25519 {
        var x1 = p.x;
        var x2 = Fe.one;
        var z2 = Fe.zero;
        var x3 = x1;
        var z3 = Fe.one;
        var swap: u8 = 0;
        var pos: usize = bits - 1;
        while (true) : (pos -= 1) {
            const bit = (s[pos >> 3] >> @truncate(u3, pos)) & 1;
            swap ^= bit;
            Fe.cSwap2(&x2, &x3, &z2, &z3, swap);
            swap = bit;
            const a = x2.add(z2);
            const b = x2.sub(z2);
            const aa = a.sq();
            const bb = b.sq();
            x2 = aa.mul(bb);
            const e = aa.sub(bb);
            const da = x3.sub(z3).mul(a);
            const cb = x3.add(z3).mul(b);
            x3 = da.add(cb).sq();
            z3 = x1.mul(da.sub(cb).sq());
            z2 = e.mul(bb.add(e.mul32(121666)));
            if (pos == 0) break;
        }
        Fe.cSwap2(&x2, &x3, &z2, &z3, swap);
        z2 = z2.invert();
        x2 = x2.mul(z2);
        if (x2.isZero()) {
            return error.IdentityElement;
        }
        return Curve25519{ .x = x2 };
    }

    /// Multiply a Curve25519 point by a scalar after "clamping" it.
    /// Clamping forces the scalar to be a multiple of the cofactor in
    /// order to prevent small subgroups attacks. This is the standard
    /// way to use Curve25519 for a DH operation.
    /// Return error.IdentityElement if the resulting point is
    /// the identity element.
    pub fn clampedMul(p: Curve25519, s: [32]u8) IdentityElementError!Curve25519 {
        var t: [32]u8 = s;
        scalar.clamp(&t);
        return try ladder(p, t, 255);
    }

    /// Multiply a Curve25519 point by a scalar without clamping it.
    /// Return error.IdentityElement if the resulting point is
    /// the identity element or error.WeakPublicKey if the public
    /// key is a low-order point.
    pub fn mul(p: Curve25519, s: [32]u8) (IdentityElementError || WeakPublicKeyError)!Curve25519 {
        const cofactor = [_]u8{8} ++ [_]u8{0} ** 31;
        _ = ladder(p, cofactor, 4) catch |_| return error.WeakPublicKey;
        return try ladder(p, s, 256);
    }

    /// Compute the Curve25519 equivalent to an Edwards25519 point.
    pub fn fromEdwards25519(p: crypto.ecc.Edwards25519) IdentityElementError!Curve25519 {
        try p.clearCofactor().rejectIdentity();
        const one = crypto.ecc.Edwards25519.Fe.one;
        const x = one.add(p.y).mul(one.sub(p.y).invert()); // xMont=(1+yEd)/(1-yEd)
        return Curve25519{ .x = x };
    }
};

test "curve25519" {
    var s = [32]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8 };
    const p = try Curve25519.basePoint.clampedMul(s);
    try p.rejectIdentity();
    var buf: [128]u8 = undefined;
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{s}", .{std.fmt.fmtSliceHexUpper(&p.toBytes())}), "E6F2A4D1C28EE5C7AD0329268255A468AD407D2672824C0C0EB30EA6EF450145");
    const q = try p.clampedMul(s);
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{s}", .{std.fmt.fmtSliceHexUpper(&q.toBytes())}), "3614E119FFE55EC55B87D6B19971A9F4CBC78EFE80BEC55B96392BABCC712537");

    try Curve25519.rejectNonCanonical(s);
    s[31] |= 0x80;
    std.testing.expectError(error.NonCanonical, Curve25519.rejectNonCanonical(s));
}

test "curve25519 small order check" {
    var s: [32]u8 = [_]u8{1} ++ [_]u8{0} ** 31;
    const small_order_ss: [7][32]u8 = .{
        .{
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 0 (order 4)
        },
        .{
            0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 1 (order 1)
        },
        .{
            0xe0, 0xeb, 0x7a, 0x7c, 0x3b, 0x41, 0xb8, 0xae, 0x16, 0x56, 0xe3, 0xfa, 0xf1, 0x9f, 0xc4, 0x6a, 0xda, 0x09, 0x8d, 0xeb, 0x9c, 0x32, 0xb1, 0xfd, 0x86, 0x62, 0x05, 0x16, 0x5f, 0x49, 0xb8, 0x00, // 325606250916557431795983626356110631294008115727848805560023387167927233504 (order 8) */
        },
        .{
            0x5f, 0x9c, 0x95, 0xbc, 0xa3, 0x50, 0x8c, 0x24, 0xb1, 0xd0, 0xb1, 0x55, 0x9c, 0x83, 0xef, 0x5b, 0x04, 0x44, 0x5c, 0xc4, 0x58, 0x1c, 0x8e, 0x86, 0xd8, 0x22, 0x4e, 0xdd, 0xd0, 0x9f, 0x11, 0x57, // 39382357235489614581723060781553021112529911719440698176882885853963445705823 (order 8)
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
        std.testing.expectError(error.WeakPublicKey, Curve25519.fromBytes(small_order_s).mul(s));
        var extra = small_order_s;
        extra[31] ^= 0x80;
        std.testing.expectError(error.WeakPublicKey, Curve25519.fromBytes(extra).mul(s));
        var valid = small_order_s;
        valid[31] = 0x40;
        s[0] = 0;
        std.testing.expectError(error.IdentityElement, Curve25519.fromBytes(valid).mul(s));
    }
}
