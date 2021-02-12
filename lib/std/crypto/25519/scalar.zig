// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std");
const mem = std.mem;

/// 2^252 + 27742317777372353535851937790883648493
pub const field_size = [32]u8{
    0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10, // 2^252+27742317777372353535851937790883648493
};

/// A compressed scalar
pub const CompressedScalar = [32]u8;

/// Zero
pub const zero = [_]u8{0} ** 32;

/// Reject a scalar whose encoding is not canonical.
pub fn rejectNonCanonical(s: [32]u8) !void {
    var c: u8 = 0;
    var n: u8 = 1;
    var i: usize = 31;
    while (true) : (i -= 1) {
        const xs = @as(u16, s[i]);
        const xfield_size = @as(u16, field_size[i]);
        c |= @intCast(u8, ((xs -% xfield_size) >> 8) & n);
        n &= @intCast(u8, ((xs ^ xfield_size) -% 1) >> 8);
        if (i == 0) break;
    }
    if (c == 0) {
        return error.NonCanonical;
    }
}

/// Reduce a scalar to the field size.
pub fn reduce(s: [32]u8) [32]u8 {
    return Scalar.fromBytes(s).toBytes();
}

/// Reduce a 64-bytes scalar to the field size.
pub fn reduce64(s: [64]u8) [32]u8 {
    return ScalarDouble.fromBytes64(s).toBytes();
}

/// Perform the X25519 "clamping" operation.
/// The scalar is then guaranteed to be a multiple of the cofactor.
pub fn clamp(s: *[32]u8) callconv(.Inline) void {
    s[0] &= 248;
    s[31] = (s[31] & 127) | 64;
}

/// Return a*b (mod L)
pub fn mul(a: [32]u8, b: [32]u8) [32]u8 {
    return Scalar.fromBytes(a).mul(Scalar.fromBytes(b)).toBytes();
}

/// Return a*b+c (mod L)
pub fn mulAdd(a: [32]u8, b: [32]u8, c: [32]u8) [32]u8 {
    return Scalar.fromBytes(a).mul(Scalar.fromBytes(b)).add(Scalar.fromBytes(c)).toBytes();
}

/// Return a*8 (mod L)
pub fn mul8(s: [32]u8) [32]u8 {
    var x = Scalar.fromBytes(s);
    x = x.add(x);
    x = x.add(x);
    x = x.add(x);
    return x.toBytes();
}

/// Return a+b (mod L)
pub fn add(a: [32]u8, b: [32]u8) [32]u8 {
    return Scalar.fromBytes(a).add(Scalar.fromBytes(b)).toBytes();
}

/// Return -s (mod L)
pub fn neg(s: [32]u8) [32]u8 {
    const fs: [64]u8 = field_size ++ [_]u8{0} ** 32;
    var sx: [64]u8 = undefined;
    mem.copy(u8, sx[0..32], s[0..]);
    mem.set(u8, sx[32..], 0);
    var carry: u32 = 0;
    var i: usize = 0;
    while (i < 64) : (i += 1) {
        carry = @as(u32, fs[i]) -% sx[i] -% @as(u32, carry);
        sx[i] = @truncate(u8, carry);
        carry = (carry >> 8) & 1;
    }
    return reduce64(sx);
}

/// Return (a-b) (mod L)
pub fn sub(a: [32]u8, b: [32]u8) [32]u8 {
    return add(a, neg(b));
}

/// A scalar in unpacked reprentation
pub const Scalar = struct {
    const Limbs = [5]u64;
    limbs: Limbs = undefined,

    /// Unpack a 32-byte representation of a scalar
    pub fn fromBytes(bytes: [32]u8) Scalar {
        return ScalarDouble.fromBytes32(bytes).reduce(5);
    }

    /// Pack a scalar into bytes
    pub fn toBytes(expanded: *const Scalar) [32]u8 {
        var bytes: [32]u8 = undefined;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            mem.writeIntLittle(u64, bytes[i * 7 ..][0..8], expanded.limbs[i]);
        }
        mem.writeIntLittle(u32, bytes[i * 7 ..][0..4], @intCast(u32, expanded.limbs[i]));
        return bytes;
    }

    /// Return x+y (mod l)
    pub fn add(x: Scalar, y: Scalar) Scalar {
        const carry0 = (x.limbs[0] + y.limbs[0]) >> 56;
        const t0 = (x.limbs[0] + y.limbs[0]) & 0xffffffffffffff;
        const t00 = t0;
        const c0 = carry0;
        const carry1 = (x.limbs[1] + y.limbs[1] + c0) >> 56;
        const t1 = (x.limbs[1] + y.limbs[1] + c0) & 0xffffffffffffff;
        const t10 = t1;
        const c1 = carry1;
        const carry2 = (x.limbs[2] + y.limbs[2] + c1) >> 56;
        const t2 = (x.limbs[2] + y.limbs[2] + c1) & 0xffffffffffffff;
        const t20 = t2;
        const c2 = carry2;
        const carry = (x.limbs[3] + y.limbs[3] + c2) >> 56;
        const t3 = (x.limbs[3] + y.limbs[3] + c2) & 0xffffffffffffff;
        const t30 = t3;
        const c3 = carry;
        const t4 = x.limbs[4] + y.limbs[4] + c3;

        const y01: u64 = 5175514460705773;
        const y11: u64 = 70332060721272408;
        const y21: u64 = 5342;
        const y31: u64 = 0;
        const y41: u64 = 268435456;

        const b5 = (t00 -% y01) >> 63;
        const t5 = ((b5 << 56) + t00) -% y01;
        const b0 = b5;
        const t01 = t5;
        const b6 = (t10 -% (y11 + b0)) >> 63;
        const t6 = ((b6 << 56) + t10) -% (y11 + b0);
        const b1 = b6;
        const t11 = t6;
        const b7 = (t20 -% (y21 + b1)) >> 63;
        const t7 = ((b7 << 56) + t20) -% (y21 + b1);
        const b2 = b7;
        const t21 = t7;
        const b8 = (t30 -% (y31 + b2)) >> 63;
        const t8 = ((b8 << 56) + t30) -% (y31 + b2);
        const b3 = b8;
        const t31 = t8;
        const b = (t4 -% (y41 + b3)) >> 63;
        const t = ((b << 56) + t4) -% (y41 + b3);
        const b4 = b;
        const t41 = t;

        const mask = (b4 -% 1);
        const z00 = t00 ^ (mask & (t00 ^ t01));
        const z10 = t10 ^ (mask & (t10 ^ t11));
        const z20 = t20 ^ (mask & (t20 ^ t21));
        const z30 = t30 ^ (mask & (t30 ^ t31));
        const z40 = t4 ^ (mask & (t4 ^ t41));

        return Scalar{ .limbs = .{ z00, z10, z20, z30, z40 } };
    }

    /// Return x*r (mod l)
    pub fn mul(x: Scalar, y: Scalar) Scalar {
        const xy000 = @as(u128, x.limbs[0]) * @as(u128, y.limbs[0]);
        const xy010 = @as(u128, x.limbs[0]) * @as(u128, y.limbs[1]);
        const xy020 = @as(u128, x.limbs[0]) * @as(u128, y.limbs[2]);
        const xy030 = @as(u128, x.limbs[0]) * @as(u128, y.limbs[3]);
        const xy040 = @as(u128, x.limbs[0]) * @as(u128, y.limbs[4]);
        const xy100 = @as(u128, x.limbs[1]) * @as(u128, y.limbs[0]);
        const xy110 = @as(u128, x.limbs[1]) * @as(u128, y.limbs[1]);
        const xy120 = @as(u128, x.limbs[1]) * @as(u128, y.limbs[2]);
        const xy130 = @as(u128, x.limbs[1]) * @as(u128, y.limbs[3]);
        const xy140 = @as(u128, x.limbs[1]) * @as(u128, y.limbs[4]);
        const xy200 = @as(u128, x.limbs[2]) * @as(u128, y.limbs[0]);
        const xy210 = @as(u128, x.limbs[2]) * @as(u128, y.limbs[1]);
        const xy220 = @as(u128, x.limbs[2]) * @as(u128, y.limbs[2]);
        const xy230 = @as(u128, x.limbs[2]) * @as(u128, y.limbs[3]);
        const xy240 = @as(u128, x.limbs[2]) * @as(u128, y.limbs[4]);
        const xy300 = @as(u128, x.limbs[3]) * @as(u128, y.limbs[0]);
        const xy310 = @as(u128, x.limbs[3]) * @as(u128, y.limbs[1]);
        const xy320 = @as(u128, x.limbs[3]) * @as(u128, y.limbs[2]);
        const xy330 = @as(u128, x.limbs[3]) * @as(u128, y.limbs[3]);
        const xy340 = @as(u128, x.limbs[3]) * @as(u128, y.limbs[4]);
        const xy400 = @as(u128, x.limbs[4]) * @as(u128, y.limbs[0]);
        const xy410 = @as(u128, x.limbs[4]) * @as(u128, y.limbs[1]);
        const xy420 = @as(u128, x.limbs[4]) * @as(u128, y.limbs[2]);
        const xy430 = @as(u128, x.limbs[4]) * @as(u128, y.limbs[3]);
        const xy440 = @as(u128, x.limbs[4]) * @as(u128, y.limbs[4]);
        const z00 = xy000;
        const z10 = xy010 + xy100;
        const z20 = xy020 + xy110 + xy200;
        const z30 = xy030 + xy120 + xy210 + xy300;
        const z40 = xy040 + xy130 + xy220 + xy310 + xy400;
        const z50 = xy140 + xy230 + xy320 + xy410;
        const z60 = xy240 + xy330 + xy420;
        const z70 = xy340 + xy430;
        const z80 = xy440;

        const carry0 = z00 >> 56;
        const t10 = @truncate(u64, z00) & 0xffffffffffffff;
        const c00 = carry0;
        const t00 = t10;
        const carry1 = (z10 + c00) >> 56;
        const t11 = @truncate(u64, (z10 + c00)) & 0xffffffffffffff;
        const c10 = carry1;
        const t12 = t11;
        const carry2 = (z20 + c10) >> 56;
        const t13 = @truncate(u64, (z20 + c10)) & 0xffffffffffffff;
        const c20 = carry2;
        const t20 = t13;
        const carry3 = (z30 + c20) >> 56;
        const t14 = @truncate(u64, (z30 + c20)) & 0xffffffffffffff;
        const c30 = carry3;
        const t30 = t14;
        const carry4 = (z40 + c30) >> 56;
        const t15 = @truncate(u64, (z40 + c30)) & 0xffffffffffffff;
        const c40 = carry4;
        const t40 = t15;
        const carry5 = (z50 + c40) >> 56;
        const t16 = @truncate(u64, (z50 + c40)) & 0xffffffffffffff;
        const c50 = carry5;
        const t50 = t16;
        const carry6 = (z60 + c50) >> 56;
        const t17 = @truncate(u64, (z60 + c50)) & 0xffffffffffffff;
        const c60 = carry6;
        const t60 = t17;
        const carry7 = (z70 + c60) >> 56;
        const t18 = @truncate(u64, (z70 + c60)) & 0xffffffffffffff;
        const c70 = carry7;
        const t70 = t18;
        const carry8 = (z80 + c70) >> 56;
        const t19 = @truncate(u64, (z80 + c70)) & 0xffffffffffffff;
        const c80 = carry8;
        const t80 = t19;
        const t90 = (@truncate(u64, c80));
        const r0 = t00;
        const r1 = t12;
        const r2 = t20;
        const r3 = t30;
        const r4 = t40;
        const r5 = t50;
        const r6 = t60;
        const r7 = t70;
        const r8 = t80;
        const r9 = t90;

        const m0: u64 = 5175514460705773;
        const m1: u64 = 70332060721272408;
        const m2: u64 = 5342;
        const m3: u64 = 0;
        const m4: u64 = 268435456;
        const mu0: u64 = 44162584779952923;
        const mu1: u64 = 9390964836247533;
        const mu2: u64 = 72057594036560134;
        const mu3: u64 = 72057594037927935;
        const mu4: u64 = 68719476735;

        const y_ = (r5 & 0xffffff) << 32;
        const x_ = r4 >> 24;
        const z01 = (x_ | y_);
        const y_0 = (r6 & 0xffffff) << 32;
        const x_0 = r5 >> 24;
        const z11 = (x_0 | y_0);
        const y_1 = (r7 & 0xffffff) << 32;
        const x_1 = r6 >> 24;
        const z21 = (x_1 | y_1);
        const y_2 = (r8 & 0xffffff) << 32;
        const x_2 = r7 >> 24;
        const z31 = (x_2 | y_2);
        const y_3 = (r9 & 0xffffff) << 32;
        const x_3 = r8 >> 24;
        const z41 = (x_3 | y_3);
        const q0 = z01;
        const q1 = z11;
        const q2 = z21;
        const q3 = z31;
        const q4 = z41;
        const xy001 = @as(u128, q0) * @as(u128, mu0);
        const xy011 = @as(u128, q0) * @as(u128, mu1);
        const xy021 = @as(u128, q0) * @as(u128, mu2);
        const xy031 = @as(u128, q0) * @as(u128, mu3);
        const xy041 = @as(u128, q0) * @as(u128, mu4);
        const xy101 = @as(u128, q1) * @as(u128, mu0);
        const xy111 = @as(u128, q1) * @as(u128, mu1);
        const xy121 = @as(u128, q1) * @as(u128, mu2);
        const xy131 = @as(u128, q1) * @as(u128, mu3);
        const xy14 = @as(u128, q1) * @as(u128, mu4);
        const xy201 = @as(u128, q2) * @as(u128, mu0);
        const xy211 = @as(u128, q2) * @as(u128, mu1);
        const xy221 = @as(u128, q2) * @as(u128, mu2);
        const xy23 = @as(u128, q2) * @as(u128, mu3);
        const xy24 = @as(u128, q2) * @as(u128, mu4);
        const xy301 = @as(u128, q3) * @as(u128, mu0);
        const xy311 = @as(u128, q3) * @as(u128, mu1);
        const xy32 = @as(u128, q3) * @as(u128, mu2);
        const xy33 = @as(u128, q3) * @as(u128, mu3);
        const xy34 = @as(u128, q3) * @as(u128, mu4);
        const xy401 = @as(u128, q4) * @as(u128, mu0);
        const xy41 = @as(u128, q4) * @as(u128, mu1);
        const xy42 = @as(u128, q4) * @as(u128, mu2);
        const xy43 = @as(u128, q4) * @as(u128, mu3);
        const xy44 = @as(u128, q4) * @as(u128, mu4);
        const z02 = xy001;
        const z12 = xy011 + xy101;
        const z22 = xy021 + xy111 + xy201;
        const z32 = xy031 + xy121 + xy211 + xy301;
        const z42 = xy041 + xy131 + xy221 + xy311 + xy401;
        const z5 = xy14 + xy23 + xy32 + xy41;
        const z6 = xy24 + xy33 + xy42;
        const z7 = xy34 + xy43;
        const z8 = xy44;

        const carry9 = z02 >> 56;
        const c01 = carry9;
        const carry10 = (z12 + c01) >> 56;
        const t21 = @truncate(u64, z12 + c01) & 0xffffffffffffff;
        const c11 = carry10;
        const carry11 = (z22 + c11) >> 56;
        const t22 = @truncate(u64, z22 + c11) & 0xffffffffffffff;
        const c21 = carry11;
        const carry12 = (z32 + c21) >> 56;
        const t23 = @truncate(u64, z32 + c21) & 0xffffffffffffff;
        const c31 = carry12;
        const carry13 = (z42 + c31) >> 56;
        const t24 = @truncate(u64, z42 + c31) & 0xffffffffffffff;
        const c41 = carry13;
        const t41 = t24;
        const carry14 = (z5 + c41) >> 56;
        const t25 = @truncate(u64, z5 + c41) & 0xffffffffffffff;
        const c5 = carry14;
        const t5 = t25;
        const carry15 = (z6 + c5) >> 56;
        const t26 = @truncate(u64, z6 + c5) & 0xffffffffffffff;
        const c6 = carry15;
        const t6 = t26;
        const carry16 = (z7 + c6) >> 56;
        const t27 = @truncate(u64, z7 + c6) & 0xffffffffffffff;
        const c7 = carry16;
        const t7 = t27;
        const carry17 = (z8 + c7) >> 56;
        const t28 = @truncate(u64, z8 + c7) & 0xffffffffffffff;
        const c8 = carry17;
        const t8 = t28;
        const t9 = @truncate(u64, c8);

        const qmu4_ = t41;
        const qmu5_ = t5;
        const qmu6_ = t6;
        const qmu7_ = t7;
        const qmu8_ = t8;
        const qmu9_ = t9;
        const y_4 = (qmu5_ & 0xffffffffff) << 16;
        const x_4 = qmu4_ >> 40;
        const z03 = (x_4 | y_4);
        const y_5 = (qmu6_ & 0xffffffffff) << 16;
        const x_5 = qmu5_ >> 40;
        const z13 = (x_5 | y_5);
        const y_6 = (qmu7_ & 0xffffffffff) << 16;
        const x_6 = qmu6_ >> 40;
        const z23 = (x_6 | y_6);
        const y_7 = (qmu8_ & 0xffffffffff) << 16;
        const x_7 = qmu7_ >> 40;
        const z33 = (x_7 | y_7);
        const y_8 = (qmu9_ & 0xffffffffff) << 16;
        const x_8 = qmu8_ >> 40;
        const z43 = (x_8 | y_8);
        const qdiv0 = z03;
        const qdiv1 = z13;
        const qdiv2 = z23;
        const qdiv3 = z33;
        const qdiv4 = z43;
        const r01 = r0;
        const r11 = r1;
        const r21 = r2;
        const r31 = r3;
        const r41 = (r4 & 0xffffffffff);

        const xy00 = @as(u128, qdiv0) * @as(u128, m0);
        const xy01 = @as(u128, qdiv0) * @as(u128, m1);
        const xy02 = @as(u128, qdiv0) * @as(u128, m2);
        const xy03 = @as(u128, qdiv0) * @as(u128, m3);
        const xy04 = @as(u128, qdiv0) * @as(u128, m4);
        const xy10 = @as(u128, qdiv1) * @as(u128, m0);
        const xy11 = @as(u128, qdiv1) * @as(u128, m1);
        const xy12 = @as(u128, qdiv1) * @as(u128, m2);
        const xy13 = @as(u128, qdiv1) * @as(u128, m3);
        const xy20 = @as(u128, qdiv2) * @as(u128, m0);
        const xy21 = @as(u128, qdiv2) * @as(u128, m1);
        const xy22 = @as(u128, qdiv2) * @as(u128, m2);
        const xy30 = @as(u128, qdiv3) * @as(u128, m0);
        const xy31 = @as(u128, qdiv3) * @as(u128, m1);
        const xy40 = @as(u128, qdiv4) * @as(u128, m0);
        const carry18 = xy00 >> 56;
        const t29 = @truncate(u64, xy00) & 0xffffffffffffff;
        const c0 = carry18;
        const t01 = t29;
        const carry19 = (xy01 + xy10 + c0) >> 56;
        const t31 = @truncate(u64, xy01 + xy10 + c0) & 0xffffffffffffff;
        const c12 = carry19;
        const t110 = t31;
        const carry20 = (xy02 + xy11 + xy20 + c12) >> 56;
        const t32 = @truncate(u64, xy02 + xy11 + xy20 + c12) & 0xffffffffffffff;
        const c22 = carry20;
        const t210 = t32;
        const carry = (xy03 + xy12 + xy21 + xy30 + c22) >> 56;
        const t33 = @truncate(u64, xy03 + xy12 + xy21 + xy30 + c22) & 0xffffffffffffff;
        const c32 = carry;
        const t34 = t33;
        const t42 = @truncate(u64, xy04 + xy13 + xy22 + xy31 + xy40 + c32) & 0xffffffffff;

        const qmul0 = t01;
        const qmul1 = t110;
        const qmul2 = t210;
        const qmul3 = t34;
        const qmul4 = t42;
        const b5 = (r01 -% qmul0) >> 63;
        const t35 = ((b5 << 56) + r01) -% qmul0;
        const c1 = b5;
        const t02 = t35;
        const b6 = (r11 -% (qmul1 + c1)) >> 63;
        const t36 = ((b6 << 56) + r11) -% (qmul1 + c1);
        const c2 = b6;
        const t111 = t36;
        const b7 = (r21 -% (qmul2 + c2)) >> 63;
        const t37 = ((b7 << 56) + r21) -% (qmul2 + c2);
        const c3 = b7;
        const t211 = t37;
        const b8 = (r31 -% (qmul3 + c3)) >> 63;
        const t38 = ((b8 << 56) + r31) -% (qmul3 + c3);
        const c4 = b8;
        const t39 = t38;
        const b9 = (r41 -% (qmul4 + c4)) >> 63;
        const t43 = ((b9 << 40) + r41) -% (qmul4 + c4);
        const t44 = t43;
        const s0 = t02;
        const s1 = t111;
        const s2 = t211;
        const s3 = t39;
        const s4 = t44;

        const y01: u64 = 5175514460705773;
        const y11: u64 = 70332060721272408;
        const y21: u64 = 5342;
        const y31: u64 = 0;
        const y41: u64 = 268435456;

        const b10 = (s0 -% y01) >> 63;
        const t45 = ((b10 << 56) + s0) -% y01;
        const b0 = b10;
        const t0 = t45;
        const b11 = (s1 -% (y11 + b0)) >> 63;
        const t46 = ((b11 << 56) + s1) -% (y11 + b0);
        const b1 = b11;
        const t1 = t46;
        const b12 = (s2 -% (y21 + b1)) >> 63;
        const t47 = ((b12 << 56) + s2) -% (y21 + b1);
        const b2 = b12;
        const t2 = t47;
        const b13 = (s3 -% (y31 + b2)) >> 63;
        const t48 = ((b13 << 56) + s3) -% (y31 + b2);
        const b3 = b13;
        const t3 = t48;
        const b = (s4 -% (y41 + b3)) >> 63;
        const t = ((b << 56) + s4) -% (y41 + b3);
        const b4 = b;
        const t4 = t;
        const mask = (b4 -% @intCast(u64, ((1))));
        const z04 = s0 ^ (mask & (s0 ^ t0));
        const z14 = s1 ^ (mask & (s1 ^ t1));
        const z24 = s2 ^ (mask & (s2 ^ t2));
        const z34 = s3 ^ (mask & (s3 ^ t3));
        const z44 = s4 ^ (mask & (s4 ^ t4));

        return Scalar{ .limbs = .{ z04, z14, z24, z34, z44 } };
    }
};

const ScalarDouble = struct {
    const Limbs = [10]u64;
    limbs: Limbs = undefined,

    fn fromBytes64(bytes: [64]u8) ScalarDouble {
        var limbs: Limbs = undefined;
        var i: usize = 0;
        while (i < 9) : (i += 1) {
            limbs[i] = mem.readIntLittle(u64, bytes[i * 7 ..][0..8]) & 0xffffffffffffff;
        }
        limbs[i] = @as(u64, bytes[i * 7]);
        return ScalarDouble{ .limbs = limbs };
    }

    fn fromBytes32(bytes: [32]u8) ScalarDouble {
        var limbs: Limbs = undefined;
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            limbs[i] = mem.readIntLittle(u64, bytes[i * 7 ..][0..8]) & 0xffffffffffffff;
        }
        limbs[i] = @as(u64, mem.readIntLittle(u32, bytes[i * 7 ..][0..4]));
        mem.set(u64, limbs[5..], 0);
        return ScalarDouble{ .limbs = limbs };
    }

    fn toBytes(expanded_double: *ScalarDouble) [32]u8 {
        return expanded_double.reduce(10).toBytes();
    }

    /// Barrett reduction
    fn reduce(expanded: *ScalarDouble, comptime limbs_count: usize) Scalar {
        const t = expanded.limbs;
        const t0 = if (limbs_count <= 0) 0 else t[0];
        const t1 = if (limbs_count <= 1) 0 else t[1];
        const t2 = if (limbs_count <= 2) 0 else t[2];
        const t3 = if (limbs_count <= 3) 0 else t[3];
        const t4 = if (limbs_count <= 4) 0 else t[4];
        const t5 = if (limbs_count <= 5) 0 else t[5];
        const t6 = if (limbs_count <= 6) 0 else t[6];
        const t7 = if (limbs_count <= 7) 0 else t[7];
        const t8 = if (limbs_count <= 8) 0 else t[8];
        const t9 = if (limbs_count <= 9) 0 else t[9];

        const m0: u64 = 5175514460705773;
        const m1: u64 = 70332060721272408;
        const m2: u64 = 5342;
        const m3: u64 = 0;
        const m4: u64 = 268435456;
        const mu0: u64 = 44162584779952923;
        const mu1: u64 = 9390964836247533;
        const mu2: u64 = 72057594036560134;
        const mu3: u64 = 0xffffffffffffff;
        const mu4: u64 = 68719476735;

        const y_ = (t5 & 0xffffff) << 32;
        const x_ = t4 >> 24;
        const z00 = x_ | y_;
        const y_0 = (t6 & 0xffffff) << 32;
        const x_0 = t5 >> 24;
        const z10 = x_0 | y_0;
        const y_1 = (t7 & 0xffffff) << 32;
        const x_1 = t6 >> 24;
        const z20 = x_1 | y_1;
        const y_2 = (t8 & 0xffffff) << 32;
        const x_2 = t7 >> 24;
        const z30 = x_2 | y_2;
        const y_3 = (t9 & 0xffffff) << 32;
        const x_3 = t8 >> 24;
        const z40 = x_3 | y_3;
        const q0 = z00;
        const q1 = z10;
        const q2 = z20;
        const q3 = z30;
        const q4 = z40;

        const xy000 = @as(u128, q0) * @as(u128, mu0);
        const xy010 = @as(u128, q0) * @as(u128, mu1);
        const xy020 = @as(u128, q0) * @as(u128, mu2);
        const xy030 = @as(u128, q0) * @as(u128, mu3);
        const xy040 = @as(u128, q0) * @as(u128, mu4);
        const xy100 = @as(u128, q1) * @as(u128, mu0);
        const xy110 = @as(u128, q1) * @as(u128, mu1);
        const xy120 = @as(u128, q1) * @as(u128, mu2);
        const xy130 = @as(u128, q1) * @as(u128, mu3);
        const xy14 = @as(u128, q1) * @as(u128, mu4);
        const xy200 = @as(u128, q2) * @as(u128, mu0);
        const xy210 = @as(u128, q2) * @as(u128, mu1);
        const xy220 = @as(u128, q2) * @as(u128, mu2);
        const xy23 = @as(u128, q2) * @as(u128, mu3);
        const xy24 = @as(u128, q2) * @as(u128, mu4);
        const xy300 = @as(u128, q3) * @as(u128, mu0);
        const xy310 = @as(u128, q3) * @as(u128, mu1);
        const xy32 = @as(u128, q3) * @as(u128, mu2);
        const xy33 = @as(u128, q3) * @as(u128, mu3);
        const xy34 = @as(u128, q3) * @as(u128, mu4);
        const xy400 = @as(u128, q4) * @as(u128, mu0);
        const xy41 = @as(u128, q4) * @as(u128, mu1);
        const xy42 = @as(u128, q4) * @as(u128, mu2);
        const xy43 = @as(u128, q4) * @as(u128, mu3);
        const xy44 = @as(u128, q4) * @as(u128, mu4);
        const z01 = xy000;
        const z11 = xy010 + xy100;
        const z21 = xy020 + xy110 + xy200;
        const z31 = xy030 + xy120 + xy210 + xy300;
        const z41 = xy040 + xy130 + xy220 + xy310 + xy400;
        const z5 = xy14 + xy23 + xy32 + xy41;
        const z6 = xy24 + xy33 + xy42;
        const z7 = xy34 + xy43;
        const z8 = xy44;

        const carry0 = z01 >> 56;
        const c00 = carry0;
        const carry1 = (z11 + c00) >> 56;
        const t100 = @as(u64, @truncate(u64, z11 + c00)) & 0xffffffffffffff;
        const c10 = carry1;
        const carry2 = (z21 + c10) >> 56;
        const t101 = @as(u64, @truncate(u64, z21 + c10)) & 0xffffffffffffff;
        const c20 = carry2;
        const carry3 = (z31 + c20) >> 56;
        const t102 = @as(u64, @truncate(u64, z31 + c20)) & 0xffffffffffffff;
        const c30 = carry3;
        const carry4 = (z41 + c30) >> 56;
        const t103 = @as(u64, @truncate(u64, z41 + c30)) & 0xffffffffffffff;
        const c40 = carry4;
        const t410 = t103;
        const carry5 = (z5 + c40) >> 56;
        const t104 = @as(u64, @truncate(u64, z5 + c40)) & 0xffffffffffffff;
        const c5 = carry5;
        const t51 = t104;
        const carry6 = (z6 + c5) >> 56;
        const t105 = @as(u64, @truncate(u64, z6 + c5)) & 0xffffffffffffff;
        const c6 = carry6;
        const t61 = t105;
        const carry7 = (z7 + c6) >> 56;
        const t106 = @as(u64, @truncate(u64, z7 + c6)) & 0xffffffffffffff;
        const c7 = carry7;
        const t71 = t106;
        const carry8 = (z8 + c7) >> 56;
        const t107 = @as(u64, @truncate(u64, z8 + c7)) & 0xffffffffffffff;
        const c8 = carry8;
        const t81 = t107;
        const t91 = @as(u64, @truncate(u64, c8));

        const qmu4_ = t410;
        const qmu5_ = t51;
        const qmu6_ = t61;
        const qmu7_ = t71;
        const qmu8_ = t81;
        const qmu9_ = t91;
        const y_4 = (qmu5_ & 0xffffffffff) << 16;
        const x_4 = qmu4_ >> 40;
        const z02 = x_4 | y_4;
        const y_5 = (qmu6_ & 0xffffffffff) << 16;
        const x_5 = qmu5_ >> 40;
        const z12 = x_5 | y_5;
        const y_6 = (qmu7_ & 0xffffffffff) << 16;
        const x_6 = qmu6_ >> 40;
        const z22 = x_6 | y_6;
        const y_7 = (qmu8_ & 0xffffffffff) << 16;
        const x_7 = qmu7_ >> 40;
        const z32 = x_7 | y_7;
        const y_8 = (qmu9_ & 0xffffffffff) << 16;
        const x_8 = qmu8_ >> 40;
        const z42 = x_8 | y_8;
        const qdiv0 = z02;
        const qdiv1 = z12;
        const qdiv2 = z22;
        const qdiv3 = z32;
        const qdiv4 = z42;
        const r0 = t0;
        const r1 = t1;
        const r2 = t2;
        const r3 = t3;
        const r4 = t4 & 0xffffffffff;

        const xy00 = @as(u128, qdiv0) * @as(u128, m0);
        const xy01 = @as(u128, qdiv0) * @as(u128, m1);
        const xy02 = @as(u128, qdiv0) * @as(u128, m2);
        const xy03 = @as(u128, qdiv0) * @as(u128, m3);
        const xy04 = @as(u128, qdiv0) * @as(u128, m4);
        const xy10 = @as(u128, qdiv1) * @as(u128, m0);
        const xy11 = @as(u128, qdiv1) * @as(u128, m1);
        const xy12 = @as(u128, qdiv1) * @as(u128, m2);
        const xy13 = @as(u128, qdiv1) * @as(u128, m3);
        const xy20 = @as(u128, qdiv2) * @as(u128, m0);
        const xy21 = @as(u128, qdiv2) * @as(u128, m1);
        const xy22 = @as(u128, qdiv2) * @as(u128, m2);
        const xy30 = @as(u128, qdiv3) * @as(u128, m0);
        const xy31 = @as(u128, qdiv3) * @as(u128, m1);
        const xy40 = @as(u128, qdiv4) * @as(u128, m0);
        const carry9 = xy00 >> 56;
        const t108 = @truncate(u64, xy00) & 0xffffffffffffff;
        const c0 = carry9;
        const t010 = t108;
        const carry10 = (xy01 + xy10 + c0) >> 56;
        const t109 = @truncate(u64, xy01 + xy10 + c0) & 0xffffffffffffff;
        const c11 = carry10;
        const t110 = t109;
        const carry11 = (xy02 + xy11 + xy20 + c11) >> 56;
        const t1010 = @truncate(u64, xy02 + xy11 + xy20 + c11) & 0xffffffffffffff;
        const c21 = carry11;
        const t210 = t1010;
        const carry = (xy03 + xy12 + xy21 + xy30 + c21) >> 56;
        const t1011 = @truncate(u64, xy03 + xy12 + xy21 + xy30 + c21) & 0xffffffffffffff;
        const c31 = carry;
        const t310 = t1011;
        const t411 = @truncate(u64, xy04 + xy13 + xy22 + xy31 + xy40 + c31) & 0xffffffffff;

        const qmul0 = t010;
        const qmul1 = t110;
        const qmul2 = t210;
        const qmul3 = t310;
        const qmul4 = t411;
        const b5 = (r0 -% qmul0) >> 63;
        const t1012 = ((b5 << 56) + r0) -% qmul0;
        const c1 = b5;
        const t011 = t1012;
        const b6 = (r1 -% (qmul1 + c1)) >> 63;
        const t1013 = ((b6 << 56) + r1) -% (qmul1 + c1);
        const c2 = b6;
        const t111 = t1013;
        const b7 = (r2 -% (qmul2 + c2)) >> 63;
        const t1014 = ((b7 << 56) + r2) -% (qmul2 + c2);
        const c3 = b7;
        const t211 = t1014;
        const b8 = (r3 -% (qmul3 + c3)) >> 63;
        const t1015 = ((b8 << 56) + r3) -% (qmul3 + c3);
        const c4 = b8;
        const t311 = t1015;
        const b9 = (r4 -% (qmul4 + c4)) >> 63;
        const t1016 = ((b9 << 40) + r4) -% (qmul4 + c4);
        const t412 = t1016;
        const s0 = t011;
        const s1 = t111;
        const s2 = t211;
        const s3 = t311;
        const s4 = t412;

        const y0: u64 = 5175514460705773;
        const y1: u64 = 70332060721272408;
        const y2: u64 = 5342;
        const y3: u64 = 0;
        const y4: u64 = 268435456;

        const b10 = (s0 -% y0) >> 63;
        const t1017 = ((b10 << 56) + s0) -% y0;
        const b0 = b10;
        const t01 = t1017;
        const b11 = (s1 -% (y1 + b0)) >> 63;
        const t1018 = ((b11 << 56) + s1) -% (y1 + b0);
        const b1 = b11;
        const t11 = t1018;
        const b12 = (s2 -% (y2 + b1)) >> 63;
        const t1019 = ((b12 << 56) + s2) -% (y2 + b1);
        const b2 = b12;
        const t21 = t1019;
        const b13 = (s3 -% (y3 + b2)) >> 63;
        const t1020 = ((b13 << 56) + s3) -% (y3 + b2);
        const b3 = b13;
        const t31 = t1020;
        const b = (s4 -% (y4 + b3)) >> 63;
        const t10 = ((b << 56) + s4) -% (y4 + b3);
        const b4 = b;
        const t41 = t10;
        const mask = b4 -% @as(u64, @as(u64, 1));
        const z03 = s0 ^ (mask & (s0 ^ t01));
        const z13 = s1 ^ (mask & (s1 ^ t11));
        const z23 = s2 ^ (mask & (s2 ^ t21));
        const z33 = s3 ^ (mask & (s3 ^ t31));
        const z43 = s4 ^ (mask & (s4 ^ t41));

        return Scalar{ .limbs = .{ z03, z13, z23, z33, z43 } };
    }
};

test "scalar25519" {
    const bytes: [32]u8 = .{ 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 255 };
    var x = Scalar.fromBytes(bytes);
    var y = x.toBytes();
    try rejectNonCanonical(y);
    var buf: [128]u8 = undefined;
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{X}", .{y}), "1E979B917937F3DE71D18077F961F6CEFF01030405060708010203040506070F");

    const reduced = reduce(field_size);
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{X}", .{reduced}), "0000000000000000000000000000000000000000000000000000000000000000");
}

test "non-canonical scalar25519" {
    const too_targe: [32]u8 = .{ 0xed, 0xd3, 0xf5, 0x5c, 0x1a, 0x63, 0x12, 0x58, 0xd6, 0x9c, 0xf7, 0xa2, 0xde, 0xf9, 0xde, 0x14, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x10 };
    std.testing.expectError(error.NonCanonical, rejectNonCanonical(too_targe));
}

test "mulAdd overflow check" {
    const a: [32]u8 = [_]u8{0xff} ** 32;
    const b: [32]u8 = [_]u8{0xff} ** 32;
    const c: [32]u8 = [_]u8{0xff} ** 32;
    const x = mulAdd(a, b, c);
    var buf: [128]u8 = undefined;
    std.testing.expectEqualStrings(try std.fmt.bufPrint(&buf, "{X}", .{x}), "D14DF91389432C25AD60FF9791B9FD1D67BEF517D273ECCE3D9A307C1B419903");
}
