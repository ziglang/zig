// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../../std.zig");
const mem = std.mem;
const testing = std.testing;
const Managed = std.math.big.int.Managed;
const Mutable = std.math.big.int.Mutable;
const Limb = std.math.big.Limb;
const DoubleLimb = std.math.big.DoubleLimb;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;

// NOTE: All the following tests assume the max machine-word will be 64-bit.
//
// They will still run on larger than this and should pass, but the multi-limb code-paths
// may be untested in some cases.

test "big.int comptime_int set" {
    comptime var s = 0xefffffff00000001eeeeeeefaaaaaaab;
    var a = try Managed.initSet(testing.allocator, s);
    defer a.deinit();

    const s_limb_count = 128 / @typeInfo(Limb).Int.bits;

    comptime var i: usize = 0;
    inline while (i < s_limb_count) : (i += 1) {
        const result = @as(Limb, s & maxInt(Limb));
        s >>= @typeInfo(Limb).Int.bits / 2;
        s >>= @typeInfo(Limb).Int.bits / 2;
        testing.expect(a.limbs[i] == result);
    }
}

test "big.int comptime_int set negative" {
    var a = try Managed.initSet(testing.allocator, -10);
    defer a.deinit();

    testing.expect(a.limbs[0] == 10);
    testing.expect(a.isPositive() == false);
}

test "big.int int set unaligned small" {
    var a = try Managed.initSet(testing.allocator, @as(u7, 45));
    defer a.deinit();

    testing.expect(a.limbs[0] == 45);
    testing.expect(a.isPositive() == true);
}

test "big.int comptime_int to" {
    var a = try Managed.initSet(testing.allocator, 0xefffffff00000001eeeeeeefaaaaaaab);
    defer a.deinit();

    testing.expect((try a.to(u128)) == 0xefffffff00000001eeeeeeefaaaaaaab);
}

test "big.int sub-limb to" {
    var a = try Managed.initSet(testing.allocator, 10);
    defer a.deinit();

    testing.expect((try a.to(u8)) == 10);
}

test "big.int to target too small error" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff);
    defer a.deinit();

    testing.expectError(error.TargetTooSmall, a.to(u8));
}

test "big.int normalize" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    try a.ensureCapacity(8);

    a.limbs[0] = 1;
    a.limbs[1] = 2;
    a.limbs[2] = 3;
    a.limbs[3] = 0;
    a.normalize(4);
    testing.expect(a.len() == 3);

    a.limbs[0] = 1;
    a.limbs[1] = 2;
    a.limbs[2] = 3;
    a.normalize(3);
    testing.expect(a.len() == 3);

    a.limbs[0] = 0;
    a.limbs[1] = 0;
    a.normalize(2);
    testing.expect(a.len() == 1);

    a.limbs[0] = 0;
    a.normalize(1);
    testing.expect(a.len() == 1);
}

test "big.int normalize multi" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    try a.ensureCapacity(8);

    a.limbs[0] = 1;
    a.limbs[1] = 2;
    a.limbs[2] = 0;
    a.limbs[3] = 0;
    a.normalize(4);
    testing.expect(a.len() == 2);

    a.limbs[0] = 1;
    a.limbs[1] = 2;
    a.limbs[2] = 3;
    a.normalize(3);
    testing.expect(a.len() == 3);

    a.limbs[0] = 0;
    a.limbs[1] = 0;
    a.limbs[2] = 0;
    a.limbs[3] = 0;
    a.normalize(4);
    testing.expect(a.len() == 1);

    a.limbs[0] = 0;
    a.normalize(1);
    testing.expect(a.len() == 1);
}

test "big.int parity" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.set(0);
    testing.expect(a.isEven());
    testing.expect(!a.isOdd());

    try a.set(7);
    testing.expect(!a.isEven());
    testing.expect(a.isOdd());
}

test "big.int bitcount + sizeInBaseUpperBound" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.set(0b100);
    testing.expect(a.bitCountAbs() == 3);
    testing.expect(a.sizeInBaseUpperBound(2) >= 3);
    testing.expect(a.sizeInBaseUpperBound(10) >= 1);

    a.negate();
    testing.expect(a.bitCountAbs() == 3);
    testing.expect(a.sizeInBaseUpperBound(2) >= 4);
    testing.expect(a.sizeInBaseUpperBound(10) >= 2);

    try a.set(0xffffffff);
    testing.expect(a.bitCountAbs() == 32);
    testing.expect(a.sizeInBaseUpperBound(2) >= 32);
    testing.expect(a.sizeInBaseUpperBound(10) >= 10);

    try a.shiftLeft(a, 5000);
    testing.expect(a.bitCountAbs() == 5032);
    testing.expect(a.sizeInBaseUpperBound(2) >= 5032);
    a.setSign(false);

    testing.expect(a.bitCountAbs() == 5032);
    testing.expect(a.sizeInBaseUpperBound(2) >= 5033);
}

test "big.int bitcount/to" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.set(0);
    testing.expect(a.bitCountTwosComp() == 0);

    testing.expect((try a.to(u0)) == 0);
    testing.expect((try a.to(i0)) == 0);

    try a.set(-1);
    testing.expect(a.bitCountTwosComp() == 1);
    testing.expect((try a.to(i1)) == -1);

    try a.set(-8);
    testing.expect(a.bitCountTwosComp() == 4);
    testing.expect((try a.to(i4)) == -8);

    try a.set(127);
    testing.expect(a.bitCountTwosComp() == 7);
    testing.expect((try a.to(u7)) == 127);

    try a.set(-128);
    testing.expect(a.bitCountTwosComp() == 8);
    testing.expect((try a.to(i8)) == -128);

    try a.set(-129);
    testing.expect(a.bitCountTwosComp() == 9);
    testing.expect((try a.to(i9)) == -129);
}

test "big.int fits" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.set(0);
    testing.expect(a.fits(u0));
    testing.expect(a.fits(i0));

    try a.set(255);
    testing.expect(!a.fits(u0));
    testing.expect(!a.fits(u1));
    testing.expect(!a.fits(i8));
    testing.expect(a.fits(u8));
    testing.expect(a.fits(u9));
    testing.expect(a.fits(i9));

    try a.set(-128);
    testing.expect(!a.fits(i7));
    testing.expect(a.fits(i8));
    testing.expect(a.fits(i9));
    testing.expect(!a.fits(u9));

    try a.set(0x1ffffffffeeeeeeee);
    testing.expect(!a.fits(u32));
    testing.expect(!a.fits(u64));
    testing.expect(a.fits(u65));
}

test "big.int string set" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.setString(10, "120317241209124781241290847124");
    testing.expect((try a.to(u128)) == 120317241209124781241290847124);
}

test "big.int string negative" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.setString(10, "-1023");
    testing.expect((try a.to(i32)) == -1023);
}

test "big.int string set number with underscores" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.setString(10, "__1_2_0_3_1_7_2_4_1_2_0_____9_1__2__4_7_8_1_2_4_1_2_9_0_8_4_7_1_2_4___");
    testing.expect((try a.to(u128)) == 120317241209124781241290847124);
}

test "big.int string set case insensitive number" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    try a.setString(16, "aB_cD_eF");
    testing.expect((try a.to(u32)) == 0xabcdef);
}

test "big.int string set bad char error" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    testing.expectError(error.InvalidCharacter, a.setString(10, "x"));
}

test "big.int string set bad base error" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    testing.expectError(error.InvalidBase, a.setString(45, "10"));
}

test "big.int string to" {
    var a = try Managed.initSet(testing.allocator, 120317241209124781241290847124);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 10, false);
    defer testing.allocator.free(as);
    const es = "120317241209124781241290847124";

    testing.expect(mem.eql(u8, as, es));
}

test "big.int string to base base error" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff);
    defer a.deinit();

    testing.expectError(error.InvalidBase, a.toString(testing.allocator, 45, false));
}

test "big.int string to base 2" {
    var a = try Managed.initSet(testing.allocator, -0b1011);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 2, false);
    defer testing.allocator.free(as);
    const es = "-1011";

    testing.expect(mem.eql(u8, as, es));
}

test "big.int string to base 16" {
    var a = try Managed.initSet(testing.allocator, 0xefffffff00000001eeeeeeefaaaaaaab);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 16, false);
    defer testing.allocator.free(as);
    const es = "efffffff00000001eeeeeeefaaaaaaab";

    testing.expect(mem.eql(u8, as, es));
}

test "big.int neg string to" {
    var a = try Managed.initSet(testing.allocator, -123907434);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 10, false);
    defer testing.allocator.free(as);
    const es = "-123907434";

    testing.expect(mem.eql(u8, as, es));
}

test "big.int zero string to" {
    var a = try Managed.initSet(testing.allocator, 0);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 10, false);
    defer testing.allocator.free(as);
    const es = "0";

    testing.expect(mem.eql(u8, as, es));
}

test "big.int clone" {
    var a = try Managed.initSet(testing.allocator, 1234);
    defer a.deinit();
    var b = try a.clone();
    defer b.deinit();

    testing.expect((try a.to(u32)) == 1234);
    testing.expect((try b.to(u32)) == 1234);

    try a.set(77);
    testing.expect((try a.to(u32)) == 77);
    testing.expect((try b.to(u32)) == 1234);
}

test "big.int swap" {
    var a = try Managed.initSet(testing.allocator, 1234);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5678);
    defer b.deinit();

    testing.expect((try a.to(u32)) == 1234);
    testing.expect((try b.to(u32)) == 5678);

    a.swap(&b);

    testing.expect((try a.to(u32)) == 5678);
    testing.expect((try b.to(u32)) == 1234);
}

test "big.int to negative" {
    var a = try Managed.initSet(testing.allocator, -10);
    defer a.deinit();

    testing.expect((try a.to(i32)) == -10);
}

test "big.int compare" {
    var a = try Managed.initSet(testing.allocator, -11);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 10);
    defer b.deinit();

    testing.expect(a.orderAbs(b) == .gt);
    testing.expect(a.order(b) == .lt);
}

test "big.int compare similar" {
    var a = try Managed.initSet(testing.allocator, 0xffffffffeeeeeeeeffffffffeeeeeeee);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xffffffffeeeeeeeeffffffffeeeeeeef);
    defer b.deinit();

    testing.expect(a.orderAbs(b) == .lt);
    testing.expect(b.orderAbs(a) == .gt);
}

test "big.int compare different limb size" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    testing.expect(a.orderAbs(b) == .gt);
    testing.expect(b.orderAbs(a) == .lt);
}

test "big.int compare multi-limb" {
    var a = try Managed.initSet(testing.allocator, -0x7777777799999999ffffeeeeffffeeeeffffeeeef);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x7777777799999999ffffeeeeffffeeeeffffeeeee);
    defer b.deinit();

    testing.expect(a.orderAbs(b) == .gt);
    testing.expect(a.order(b) == .lt);
}

test "big.int equality" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, -0xffffffff1);
    defer b.deinit();

    testing.expect(a.eqAbs(b));
    testing.expect(!a.eq(b));
}

test "big.int abs" {
    var a = try Managed.initSet(testing.allocator, -5);
    defer a.deinit();

    a.abs();
    testing.expect((try a.to(u32)) == 5);

    a.abs();
    testing.expect((try a.to(u32)) == 5);
}

test "big.int negate" {
    var a = try Managed.initSet(testing.allocator, 5);
    defer a.deinit();

    a.negate();
    testing.expect((try a.to(i32)) == -5);

    a.negate();
    testing.expect((try a.to(i32)) == 5);
}

test "big.int add single-single" {
    var a = try Managed.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.add(a.toConst(), b.toConst());

    testing.expect((try c.to(u32)) == 55);
}

test "big.int add multi-single" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();

    try c.add(a.toConst(), b.toConst());
    testing.expect((try c.to(DoubleLimb)) == maxInt(Limb) + 2);

    try c.add(b.toConst(), a.toConst());
    testing.expect((try c.to(DoubleLimb)) == maxInt(Limb) + 2);
}

test "big.int add multi-multi" {
    const op1 = 0xefefefef7f7f7f7f;
    const op2 = 0xfefefefe9f9f9f9f;
    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.add(a.toConst(), b.toConst());

    testing.expect((try c.to(u128)) == op1 + op2);
}

test "big.int add zero-zero" {
    var a = try Managed.initSet(testing.allocator, 0);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.add(a.toConst(), b.toConst());

    testing.expect((try c.to(u32)) == 0);
}

test "big.int add alias multi-limb nonzero-zero" {
    const op1 = 0xffffffff777777771;
    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0);
    defer b.deinit();

    try a.add(a.toConst(), b.toConst());

    testing.expect((try a.to(u128)) == op1);
}

test "big.int add sign" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    var one = try Managed.initSet(testing.allocator, 1);
    defer one.deinit();
    var two = try Managed.initSet(testing.allocator, 2);
    defer two.deinit();
    var neg_one = try Managed.initSet(testing.allocator, -1);
    defer neg_one.deinit();
    var neg_two = try Managed.initSet(testing.allocator, -2);
    defer neg_two.deinit();

    try a.add(one.toConst(), two.toConst());
    testing.expect((try a.to(i32)) == 3);

    try a.add(neg_one.toConst(), two.toConst());
    testing.expect((try a.to(i32)) == 1);

    try a.add(one.toConst(), neg_two.toConst());
    testing.expect((try a.to(i32)) == -1);

    try a.add(neg_one.toConst(), neg_two.toConst());
    testing.expect((try a.to(i32)) == -3);
}

test "big.int sub single-single" {
    var a = try Managed.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.sub(a.toConst(), b.toConst());

    testing.expect((try c.to(u32)) == 45);
}

test "big.int sub multi-single" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 1);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.sub(a.toConst(), b.toConst());

    testing.expect((try c.to(Limb)) == maxInt(Limb));
}

test "big.int sub multi-multi" {
    const op1 = 0xefefefefefefefefefefefef;
    const op2 = 0xabababababababababababab;

    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.sub(a.toConst(), b.toConst());

    testing.expect((try c.to(u128)) == op1 - op2);
}

test "big.int sub equal" {
    var a = try Managed.initSet(testing.allocator, 0x11efefefefefefefefefefefef);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x11efefefefefefefefefefefef);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.sub(a.toConst(), b.toConst());

    testing.expect((try c.to(u32)) == 0);
}

test "big.int sub sign" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    var one = try Managed.initSet(testing.allocator, 1);
    defer one.deinit();
    var two = try Managed.initSet(testing.allocator, 2);
    defer two.deinit();
    var neg_one = try Managed.initSet(testing.allocator, -1);
    defer neg_one.deinit();
    var neg_two = try Managed.initSet(testing.allocator, -2);
    defer neg_two.deinit();

    try a.sub(one.toConst(), two.toConst());
    testing.expect((try a.to(i32)) == -1);

    try a.sub(neg_one.toConst(), two.toConst());
    testing.expect((try a.to(i32)) == -3);

    try a.sub(one.toConst(), neg_two.toConst());
    testing.expect((try a.to(i32)) == 3);

    try a.sub(neg_one.toConst(), neg_two.toConst());
    testing.expect((try a.to(i32)) == 1);

    try a.sub(neg_two.toConst(), neg_one.toConst());
    testing.expect((try a.to(i32)) == -1);
}

test "big.int mul single-single" {
    var a = try Managed.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mul(a.toConst(), b.toConst());

    testing.expect((try c.to(u64)) == 250);
}

test "big.int mul multi-single" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 2);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mul(a.toConst(), b.toConst());

    testing.expect((try c.to(DoubleLimb)) == 2 * maxInt(Limb));
}

test "big.int mul multi-multi" {
    const op1 = 0x998888efefefefefefefef;
    const op2 = 0x333000abababababababab;
    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mul(a.toConst(), b.toConst());

    testing.expect((try c.to(u256)) == op1 * op2);
}

test "big.int mul alias r with a" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 2);
    defer b.deinit();

    try a.mul(a.toConst(), b.toConst());

    testing.expect((try a.to(DoubleLimb)) == 2 * maxInt(Limb));
}

test "big.int mul alias r with b" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 2);
    defer b.deinit();

    try a.mul(b.toConst(), a.toConst());

    testing.expect((try a.to(DoubleLimb)) == 2 * maxInt(Limb));
}

test "big.int mul alias r with a and b" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();

    try a.mul(a.toConst(), a.toConst());

    testing.expect((try a.to(DoubleLimb)) == maxInt(Limb) * maxInt(Limb));
}

test "big.int mul a*0" {
    var a = try Managed.initSet(testing.allocator, 0xefefefefefefefef);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mul(a.toConst(), b.toConst());

    testing.expect((try c.to(u32)) == 0);
}

test "big.int mul 0*0" {
    var a = try Managed.initSet(testing.allocator, 0);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0);
    defer b.deinit();

    var c = try Managed.init(testing.allocator);
    defer c.deinit();
    try c.mul(a.toConst(), b.toConst());

    testing.expect((try c.to(u32)) == 0);
}

test "big.int mul large" {
    var a = try Managed.initCapacity(testing.allocator, 50);
    defer a.deinit();
    var b = try Managed.initCapacity(testing.allocator, 100);
    defer b.deinit();
    var c = try Managed.initCapacity(testing.allocator, 100);
    defer c.deinit();

    // Generate a number that's large enough to cross the thresholds for the use
    // of subquadratic algorithms
    for (a.limbs) |*p| {
        p.* = std.math.maxInt(Limb);
    }
    a.setMetadata(true, 50);

    try b.mul(a.toConst(), a.toConst());
    try c.sqr(a.toConst());

    testing.expect(b.eq(c));
}

test "big.int div single-single no rem" {
    var a = try Managed.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u32)) == 10);
    testing.expect((try r.to(u32)) == 0);
}

test "big.int div single-single with rem" {
    var a = try Managed.initSet(testing.allocator, 49);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 5);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u32)) == 9);
    testing.expect((try r.to(u32)) == 4);
}

test "big.int div multi-single no rem" {
    const op1 = 0xffffeeeeddddcccc;
    const op2 = 34;

    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u64)) == op1 / op2);
    testing.expect((try r.to(u64)) == 0);
}

test "big.int div multi-single with rem" {
    const op1 = 0xffffeeeeddddcccf;
    const op2 = 34;

    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u64)) == op1 / op2);
    testing.expect((try r.to(u64)) == 3);
}

test "big.int div multi>2-single" {
    const op1 = 0xfefefefefefefefefefefefefefefefe;
    const op2 = 0xefab8;

    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u128)) == op1 / op2);
    testing.expect((try r.to(u32)) == 0x3e4e);
}

test "big.int div single-single q < r" {
    var a = try Managed.initSet(testing.allocator, 0x0078f432);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x01000000);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u64)) == 0);
    testing.expect((try r.to(u64)) == 0x0078f432);
}

test "big.int div single-single q == r" {
    var a = try Managed.initSet(testing.allocator, 10);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 10);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u64)) == 1);
    testing.expect((try r.to(u64)) == 0);
}

test "big.int div q=0 alias" {
    var a = try Managed.initSet(testing.allocator, 3);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 10);
    defer b.deinit();

    try Managed.divTrunc(&a, &b, a.toConst(), b.toConst());

    testing.expect((try a.to(u64)) == 0);
    testing.expect((try b.to(u64)) == 3);
}

test "big.int div multi-multi q < r" {
    const op1 = 0x1ffffffff0078f432;
    const op2 = 0x1ffffffff01000000;
    var a = try Managed.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u128)) == 0);
    testing.expect((try r.to(u128)) == op1);
}

test "big.int div trunc single-single +/+" {
    const u: i32 = 5;
    const v: i32 = 3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    // n = q * d + r
    // 5 = 1 * 3 + 2
    const eq = @divTrunc(u, v);
    const er = @mod(u, v);

    testing.expect((try q.to(i32)) == eq);
    testing.expect((try r.to(i32)) == er);
}

test "big.int div trunc single-single -/+" {
    const u: i32 = -5;
    const v: i32 = 3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    //  n = q *  d + r
    // -5 = 1 * -3 - 2
    const eq = -1;
    const er = -2;

    testing.expect((try q.to(i32)) == eq);
    testing.expect((try r.to(i32)) == er);
}

test "big.int div trunc single-single +/-" {
    const u: i32 = 5;
    const v: i32 = -3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    // n =  q *  d + r
    // 5 = -1 * -3 + 2
    const eq = -1;
    const er = 2;

    testing.expect((try q.to(i32)) == eq);
    testing.expect((try r.to(i32)) == er);
}

test "big.int div trunc single-single -/-" {
    const u: i32 = -5;
    const v: i32 = -3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    //  n = q *  d + r
    // -5 = 1 * -3 - 2
    const eq = 1;
    const er = -2;

    testing.expect((try q.to(i32)) == eq);
    testing.expect((try r.to(i32)) == er);
}

test "big.int div floor single-single +/+" {
    const u: i32 = 5;
    const v: i32 = 3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divFloor(&q, &r, a.toConst(), b.toConst());

    //  n =  q *  d + r
    //  5 =  1 *  3 + 2
    const eq = 1;
    const er = 2;

    testing.expect((try q.to(i32)) == eq);
    testing.expect((try r.to(i32)) == er);
}

test "big.int div floor single-single -/+" {
    const u: i32 = -5;
    const v: i32 = 3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divFloor(&q, &r, a.toConst(), b.toConst());

    //  n =  q *  d + r
    // -5 = -2 *  3 + 1
    const eq = -2;
    const er = 1;

    testing.expect((try q.to(i32)) == eq);
    testing.expect((try r.to(i32)) == er);
}

test "big.int div floor single-single +/-" {
    const u: i32 = 5;
    const v: i32 = -3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divFloor(&q, &r, a.toConst(), b.toConst());

    //  n =  q *  d + r
    //  5 = -2 * -3 - 1
    const eq = -2;
    const er = -1;

    testing.expect((try q.to(i32)) == eq);
    testing.expect((try r.to(i32)) == er);
}

test "big.int div floor single-single -/-" {
    const u: i32 = -5;
    const v: i32 = -3;

    var a = try Managed.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divFloor(&q, &r, a.toConst(), b.toConst());

    //  n =  q *  d + r
    // -5 =  2 * -3 + 1
    const eq = 1;
    const er = -2;

    testing.expect((try q.to(i32)) == eq);
    testing.expect((try r.to(i32)) == er);
}

test "big.int div multi-multi with rem" {
    var a = try Managed.initSet(testing.allocator, 0x8888999911110000ffffeeeeddddccccbbbbaaaa9999);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x99990000111122223333);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u128)) == 0xe38f38e39161aaabd03f0f1b);
    testing.expect((try r.to(u128)) == 0x28de0acacd806823638);
}

test "big.int div multi-multi no rem" {
    var a = try Managed.initSet(testing.allocator, 0x8888999911110000ffffeeeedb4fec200ee3a4286361);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x99990000111122223333);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u128)) == 0xe38f38e39161aaabd03f0f1b);
    testing.expect((try r.to(u128)) == 0);
}

test "big.int div multi-multi (2 branch)" {
    var a = try Managed.initSet(testing.allocator, 0x866666665555555588888887777777761111111111111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x86666666555555554444444433333333);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u128)) == 0x10000000000000000);
    testing.expect((try r.to(u128)) == 0x44444443444444431111111111111111);
}

test "big.int div multi-multi (3.1/3.3 branch)" {
    var a = try Managed.initSet(testing.allocator, 0x11111111111111111111111111111111111111111111111111111111111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x1111111111111111111111111111111111111111171);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u128)) == 0xfffffffffffffffffff);
    testing.expect((try r.to(u256)) == 0x1111111111111111111110b12222222222222222282);
}

test "big.int div multi-single zero-limb trailing" {
    var a = try Managed.initSet(testing.allocator, 0x60000000000000000000000000000000000000000000000000000000000000000);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x10000000000000000);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    var expected = try Managed.initSet(testing.allocator, 0x6000000000000000000000000000000000000000000000000);
    defer expected.deinit();
    testing.expect(q.eq(expected));
    testing.expect(r.eqZero());
}

test "big.int div multi-multi zero-limb trailing (with rem)" {
    var a = try Managed.initSet(testing.allocator, 0x86666666555555558888888777777776111111111111111100000000000000000000000000000000);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x8666666655555555444444443333333300000000000000000000000000000000);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u128)) == 0x10000000000000000);

    const rs = try r.toString(testing.allocator, 16, false);
    defer testing.allocator.free(rs);
    testing.expect(std.mem.eql(u8, rs, "4444444344444443111111111111111100000000000000000000000000000000"));
}

test "big.int div multi-multi zero-limb trailing (with rem) and dividend zero-limb count > divisor zero-limb count" {
    var a = try Managed.initSet(testing.allocator, 0x8666666655555555888888877777777611111111111111110000000000000000);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x8666666655555555444444443333333300000000000000000000000000000000);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    testing.expect((try q.to(u128)) == 0x1);

    const rs = try r.toString(testing.allocator, 16, false);
    defer testing.allocator.free(rs);
    testing.expect(std.mem.eql(u8, rs, "444444434444444311111111111111110000000000000000"));
}

test "big.int div multi-multi zero-limb trailing (with rem) and dividend zero-limb count < divisor zero-limb count" {
    var a = try Managed.initSet(testing.allocator, 0x86666666555555558888888777777776111111111111111100000000000000000000000000000000);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x866666665555555544444444333333330000000000000000);
    defer b.deinit();

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    const qs = try q.toString(testing.allocator, 16, false);
    defer testing.allocator.free(qs);
    testing.expect(std.mem.eql(u8, qs, "10000000000000000820820803105186f"));

    const rs = try r.toString(testing.allocator, 16, false);
    defer testing.allocator.free(rs);
    testing.expect(std.mem.eql(u8, rs, "4e11f2baa5896a321d463b543d0104e30000000000000000"));
}

test "big.int div multi-multi fuzz case #1" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    var b = try Managed.init(testing.allocator);
    defer b.deinit();

    try a.setString(16, "ffffffffffffffffffffffffffffc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    try b.setString(16, "3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0000000000000000000000000000000000001ffffffffffffffffffffffffffffffffffffffffffffffffffc000000000000000000000000000000007fffffffffff");

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    const qs = try q.toString(testing.allocator, 16, false);
    defer testing.allocator.free(qs);
    testing.expect(std.mem.eql(u8, qs, "3ffffffffffffffffffffffffffff0000000000000000000000000000000000001ffffffffffffffffffffffffffff7fffffffe000000000000000000000000000180000000000000000000003fffffbfffffffdfffffffffffffeffff800000100101000000100000000020003fffffdfbfffffe3ffffffffffffeffff7fffc00800a100000017ffe000002000400007efbfff7fe9f00000037ffff3fff7fffa004006100000009ffe00000190038200bf7d2ff7fefe80400060000f7d7f8fbf9401fe38e0403ffc0bdffffa51102c300d7be5ef9df4e5060007b0127ad3fa69f97d0f820b6605ff617ddf7f32ad7a05c0d03f2e7bc78a6000e087a8bbcdc59e07a5a079128a7861f553ddebed7e8e56701756f9ead39b48cd1b0831889ea6ec1fddf643d0565b075ff07e6caea4e2854ec9227fd635ed60a2f5eef2893052ffd54718fa08604acbf6a15e78a467c4a3c53c0278af06c4416573f925491b195e8fd79302cb1aaf7caf4ecfc9aec1254cc969786363ac729f914c6ddcc26738d6b0facd54eba026580aba2eb6482a088b0d224a8852420b91ec1"));

    const rs = try r.toString(testing.allocator, 16, false);
    defer testing.allocator.free(rs);
    testing.expect(std.mem.eql(u8, rs, "310d1d4c414426b4836c2635bad1df3a424e50cbdd167ffccb4dfff57d36b4aae0d6ca0910698220171a0f3373c1060a046c2812f0027e321f72979daa5e7973214170d49e885de0c0ecc167837d44502430674a82522e5df6a0759548052420b91ec1"));
}

test "big.int div multi-multi fuzz case #2" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();
    var b = try Managed.init(testing.allocator);
    defer b.deinit();

    try a.setString(16, "3ffffffffe00000000000000000000000000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffe000000000000000000000000000000000000000000000000000000000000001fffffffffffffffff800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffc000000000000000000000000000000000000000000000000000000000000000");
    try b.setString(16, "ffc0000000000000000000000000000000000000000000000000");

    var q = try Managed.init(testing.allocator);
    defer q.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();
    try Managed.divTrunc(&q, &r, a.toConst(), b.toConst());

    const qs = try q.toString(testing.allocator, 16, false);
    defer testing.allocator.free(qs);
    testing.expect(std.mem.eql(u8, qs, "40100400fe3f8fe3f8fe3f8fe3f8fe3f8fe4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f91e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4992649926499264991e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4792e4b92e4b92e4b92e4b92a4a92a4a92a4"));

    const rs = try r.toString(testing.allocator, 16, false);
    defer testing.allocator.free(rs);
    testing.expect(std.mem.eql(u8, rs, "a900000000000000000000000000000000000000000000000000"));
}

test "big.int shift-right single" {
    var a = try Managed.initSet(testing.allocator, 0xffff0000);
    defer a.deinit();
    try a.shiftRight(a, 16);

    testing.expect((try a.to(u32)) == 0xffff);
}

test "big.int shift-right multi" {
    var a = try Managed.initSet(testing.allocator, 0xffff0000eeee1111dddd2222cccc3333);
    defer a.deinit();
    try a.shiftRight(a, 67);

    testing.expect((try a.to(u64)) == 0x1fffe0001dddc222);

    try a.set(0xffff0000eeee1111dddd2222cccc3333);
    try a.shiftRight(a, 63);
    try a.shiftRight(a, 63);
    try a.shiftRight(a, 2);
    testing.expect(a.eqZero());
}

test "big.int shift-left single" {
    var a = try Managed.initSet(testing.allocator, 0xffff);
    defer a.deinit();
    try a.shiftLeft(a, 16);

    testing.expect((try a.to(u64)) == 0xffff0000);
}

test "big.int shift-left multi" {
    var a = try Managed.initSet(testing.allocator, 0x1fffe0001dddc222);
    defer a.deinit();
    try a.shiftLeft(a, 67);

    testing.expect((try a.to(u128)) == 0xffff0000eeee11100000000000000000);
}

test "big.int shift-right negative" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    var arg = try Managed.initSet(testing.allocator, -20);
    defer arg.deinit();
    try a.shiftRight(arg, 2);
    testing.expect((try a.to(i32)) == -20 >> 2);

    var arg2 = try Managed.initSet(testing.allocator, -5);
    defer arg2.deinit();
    try a.shiftRight(arg2, 10);
    testing.expect((try a.to(i32)) == -5 >> 10);
}

test "big.int shift-left negative" {
    var a = try Managed.init(testing.allocator);
    defer a.deinit();

    var arg = try Managed.initSet(testing.allocator, -10);
    defer arg.deinit();
    try a.shiftRight(arg, 1232);
    testing.expect((try a.to(i32)) == -10 >> 1232);
}

test "big.int bitwise and simple" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitAnd(a, b);

    testing.expect((try a.to(u64)) == 0xeeeeeeee00000000);
}

test "big.int bitwise and multi-limb" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer b.deinit();

    try a.bitAnd(a, b);

    testing.expect((try a.to(u128)) == 0);
}

test "big.int bitwise xor simple" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitXor(a, b);

    testing.expect((try a.to(u64)) == 0x1111111133333333);
}

test "big.int bitwise xor multi-limb" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer b.deinit();

    try a.bitXor(a, b);

    testing.expect((try a.to(DoubleLimb)) == (maxInt(Limb) + 1) ^ maxInt(Limb));
}

test "big.int bitwise or simple" {
    var a = try Managed.initSet(testing.allocator, 0xffffffff11111111);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitOr(a, b);

    testing.expect((try a.to(u64)) == 0xffffffff33333333);
}

test "big.int bitwise or multi-limb" {
    var a = try Managed.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, maxInt(Limb));
    defer b.deinit();

    try a.bitOr(a, b);

    // TODO: big.int.cpp or is wrong on multi-limb.
    testing.expect((try a.to(DoubleLimb)) == (maxInt(Limb) + 1) + maxInt(Limb));
}

test "big.int var args" {
    var a = try Managed.initSet(testing.allocator, 5);
    defer a.deinit();

    var b = try Managed.initSet(testing.allocator, 6);
    defer b.deinit();
    try a.add(a.toConst(), b.toConst());
    testing.expect((try a.to(u64)) == 11);

    var c = try Managed.initSet(testing.allocator, 11);
    defer c.deinit();
    testing.expect(a.order(c) == .eq);

    var d = try Managed.initSet(testing.allocator, 14);
    defer d.deinit();
    testing.expect(a.order(d) != .gt);
}

test "big.int gcd non-one small" {
    var a = try Managed.initSet(testing.allocator, 17);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 97);
    defer b.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();

    try r.gcd(a, b);

    testing.expect((try r.to(u32)) == 1);
}

test "big.int gcd non-one small" {
    var a = try Managed.initSet(testing.allocator, 4864);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 3458);
    defer b.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();

    try r.gcd(a, b);

    testing.expect((try r.to(u32)) == 38);
}

test "big.int gcd non-one large" {
    var a = try Managed.initSet(testing.allocator, 0xffffffffffffffff);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0xffffffffffffffff7777);
    defer b.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();

    try r.gcd(a, b);

    testing.expect((try r.to(u32)) == 4369);
}

test "big.int gcd large multi-limb result" {
    var a = try Managed.initSet(testing.allocator, 0x12345678123456781234567812345678123456781234567812345678);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 0x12345671234567123456712345671234567123456712345671234567);
    defer b.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();

    try r.gcd(a, b);

    const answer = (try r.to(u256));
    testing.expect(answer == 0xf000000ff00000fff0000ffff000fffff00ffffff1);
}

test "big.int gcd one large" {
    var a = try Managed.initSet(testing.allocator, 1897056385327307);
    defer a.deinit();
    var b = try Managed.initSet(testing.allocator, 2251799813685248);
    defer b.deinit();
    var r = try Managed.init(testing.allocator);
    defer r.deinit();

    try r.gcd(a, b);

    testing.expect((try r.to(u64)) == 1);
}

test "big.int mutable to managed" {
    const allocator = testing.allocator;
    var limbs_buf = try allocator.alloc(Limb, 8);
    defer allocator.free(limbs_buf);

    var a = Mutable.init(limbs_buf, 0xdeadbeef);
    var a_managed = a.toManaged(allocator);

    testing.expect(a.toConst().eq(a_managed.toConst()));
}

test "big.int const to managed" {
    var a = try Managed.initSet(testing.allocator, 123423453456);
    defer a.deinit();

    var b = try a.toConst().toManaged(testing.allocator);
    defer b.deinit();

    testing.expect(a.toConst().eq(b.toConst()));
}

test "big.int pow" {
    {
        var a = try Managed.initSet(testing.allocator, -3);
        defer a.deinit();

        try a.pow(a.toConst(), 3);
        testing.expectEqual(@as(i32, -27), try a.to(i32));

        try a.pow(a.toConst(), 4);
        testing.expectEqual(@as(i32, 531441), try a.to(i32));
    }
    {
        var a = try Managed.initSet(testing.allocator, 10);
        defer a.deinit();

        var y = try Managed.init(testing.allocator);
        defer y.deinit();

        // y and a are not aliased
        try y.pow(a.toConst(), 123);
        // y and a are aliased
        try a.pow(a.toConst(), 123);

        testing.expect(a.eq(y));

        const ys = try y.toString(testing.allocator, 16, false);
        defer testing.allocator.free(ys);
        testing.expectEqualSlices(
            u8,
            "183425a5f872f126e00a5ad62c839075cd6846c6fb0230887c7ad7a9dc530fcb" ++
                "4933f60e8000000000000000000000000000000",
            ys,
        );
    }
    // Special cases
    {
        var a = try Managed.initSet(testing.allocator, 0);
        defer a.deinit();

        try a.pow(a.toConst(), 100);
        testing.expectEqual(@as(i32, 0), try a.to(i32));

        try a.set(1);
        try a.pow(a.toConst(), 0);
        testing.expectEqual(@as(i32, 1), try a.to(i32));
        try a.pow(a.toConst(), 100);
        testing.expectEqual(@as(i32, 1), try a.to(i32));
        try a.set(-1);
        try a.pow(a.toConst(), 15);
        testing.expectEqual(@as(i32, -1), try a.to(i32));
        try a.pow(a.toConst(), 16);
        testing.expectEqual(@as(i32, 1), try a.to(i32));
    }
}
