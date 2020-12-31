// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../../std.zig");
const debug = std.debug;
const math = std.math;
const mem = std.mem;
const testing = std.testing;
const Allocator = mem.Allocator;

const Limb = std.math.big.Limb;
const DoubleLimb = std.math.big.DoubleLimb;
const Int = std.math.big.int.Managed;
const IntConst = std.math.big.int.Const;

/// An arbitrary-precision rational number.
///
/// Memory is allocated as needed for operations to ensure full precision is kept. The precision
/// of a Rational is only bounded by memory.
///
/// Rational's are always normalized. That is, for a Rational r = p/q where p and q are integers,
/// gcd(p, q) = 1 always.
///
/// TODO rework this to store its own allocator and use a non-managed big int, to avoid double
/// allocator storage.
pub const Rational = struct {
    /// Numerator. Determines the sign of the Rational.
    p: Int,

    /// Denominator. Sign is ignored.
    q: Int,

    /// Create a new Rational. A small amount of memory will be allocated on initialization.
    /// This will be 2 * Int.default_capacity.
    pub fn init(a: *Allocator) !Rational {
        return Rational{
            .p = try Int.init(a),
            .q = try Int.initSet(a, 1),
        };
    }

    /// Frees all memory associated with a Rational.
    pub fn deinit(self: *Rational) void {
        self.p.deinit();
        self.q.deinit();
    }

    /// Set a Rational from a primitive integer type.
    pub fn setInt(self: *Rational, a: anytype) !void {
        try self.p.set(a);
        try self.q.set(1);
    }

    /// Set a Rational from a string of the form `A/B` where A and B are base-10 integers.
    pub fn setFloatString(self: *Rational, str: []const u8) !void {
        // TODO: Accept a/b fractions and exponent form
        if (str.len == 0) {
            return error.InvalidFloatString;
        }

        const State = enum {
            Integer,
            Fractional,
        };

        var state = State.Integer;
        var point: ?usize = null;

        var start: usize = 0;
        if (str[0] == '-') {
            start += 1;
        }

        for (str) |c, i| {
            switch (state) {
                State.Integer => {
                    switch (c) {
                        '.' => {
                            state = State.Fractional;
                            point = i;
                        },
                        '0'...'9' => {
                            // okay
                        },
                        else => {
                            return error.InvalidFloatString;
                        },
                    }
                },
                State.Fractional => {
                    switch (c) {
                        '0'...'9' => {
                            // okay
                        },
                        else => {
                            return error.InvalidFloatString;
                        },
                    }
                },
            }
        }

        // TODO: batch the multiplies by 10
        if (point) |i| {
            try self.p.setString(10, str[0..i]);

            const base = IntConst{ .limbs = &[_]Limb{10}, .positive = true };

            var j: usize = start;
            while (j < str.len - i - 1) : (j += 1) {
                try self.p.ensureMulCapacity(self.p.toConst(), base);
                try self.p.mul(self.p.toConst(), base);
            }

            try self.q.setString(10, str[i + 1 ..]);
            try self.p.add(self.p.toConst(), self.q.toConst());

            try self.q.set(1);
            var k: usize = i + 1;
            while (k < str.len) : (k += 1) {
                try self.q.mul(self.q.toConst(), base);
            }

            try self.reduce();
        } else {
            try self.p.setString(10, str[0..]);
            try self.q.set(1);
        }
    }

    /// Set a Rational from a floating-point value. The rational will have enough precision to
    /// completely represent the provided float.
    pub fn setFloat(self: *Rational, comptime T: type, f: T) !void {
        // Translated from golang.go/src/math/big/rat.go.
        debug.assert(@typeInfo(T) == .Float);

        const UnsignedInt = std.meta.Int(.unsigned, @typeInfo(T).Float.bits);
        const f_bits = @bitCast(UnsignedInt, f);

        const exponent_bits = math.floatExponentBits(T);
        const exponent_bias = (1 << (exponent_bits - 1)) - 1;
        const mantissa_bits = math.floatMantissaBits(T);

        const exponent_mask = (1 << exponent_bits) - 1;
        const mantissa_mask = (1 << mantissa_bits) - 1;

        var exponent = @intCast(i16, (f_bits >> mantissa_bits) & exponent_mask);
        var mantissa = f_bits & mantissa_mask;

        switch (exponent) {
            exponent_mask => {
                return error.NonFiniteFloat;
            },
            0 => {
                // denormal
                exponent -= exponent_bias - 1;
            },
            else => {
                // normal
                mantissa |= 1 << mantissa_bits;
                exponent -= exponent_bias;
            },
        }

        var shift: i16 = mantissa_bits - exponent;

        // factor out powers of two early from rational
        while (mantissa & 1 == 0 and shift > 0) {
            mantissa >>= 1;
            shift -= 1;
        }

        try self.p.set(mantissa);
        self.p.setSign(f >= 0);

        try self.q.set(1);
        if (shift >= 0) {
            try self.q.shiftLeft(self.q, @intCast(usize, shift));
        } else {
            try self.p.shiftLeft(self.p, @intCast(usize, -shift));
        }

        try self.reduce();
    }

    /// Return a floating-point value that is the closest value to a Rational.
    ///
    /// The result may not be exact if the Rational is too precise or too large for the
    /// target type.
    pub fn toFloat(self: Rational, comptime T: type) !T {
        // Translated from golang.go/src/math/big/rat.go.
        // TODO: Indicate whether the result is not exact.
        debug.assert(@typeInfo(T) == .Float);

        const fsize = @typeInfo(T).Float.bits;
        const BitReprType = std.meta.Int(.unsigned, fsize);

        const msize = math.floatMantissaBits(T);
        const msize1 = msize + 1;
        const msize2 = msize1 + 1;

        const esize = math.floatExponentBits(T);
        const ebias = (1 << (esize - 1)) - 1;
        const emin = 1 - ebias;
        const emax = ebias;

        if (self.p.eqZero()) {
            return 0;
        }

        // 1. left-shift a or sub so that a/b is in [1 << msize1, 1 << (msize2 + 1)]
        var exp = @intCast(isize, self.p.bitCountTwosComp()) - @intCast(isize, self.q.bitCountTwosComp());

        var a2 = try self.p.clone();
        defer a2.deinit();

        var b2 = try self.q.clone();
        defer b2.deinit();

        const shift = msize2 - exp;
        if (shift >= 0) {
            try a2.shiftLeft(a2, @intCast(usize, shift));
        } else {
            try b2.shiftLeft(b2, @intCast(usize, -shift));
        }

        // 2. compute quotient and remainder
        var q = try Int.init(self.p.allocator);
        defer q.deinit();

        // unused
        var r = try Int.init(self.p.allocator);
        defer r.deinit();

        try Int.divTrunc(&q, &r, a2.toConst(), b2.toConst());

        var mantissa = extractLowBits(q, BitReprType);
        var have_rem = r.len() > 0;

        // 3. q didn't fit in msize2 bits, redo division b2 << 1
        if (mantissa >> msize2 == 1) {
            if (mantissa & 1 == 1) {
                have_rem = true;
            }
            mantissa >>= 1;
            exp += 1;
        }
        if (mantissa >> msize1 != 1) {
            // NOTE: This can be hit if the limb size is small (u8/16).
            @panic("unexpected bits in result");
        }

        // 4. Rounding
        if (emin - msize <= exp and exp <= emin) {
            // denormal
            const shift1 = @intCast(math.Log2Int(BitReprType), emin - (exp - 1));
            const lost_bits = mantissa & ((@intCast(BitReprType, 1) << shift1) - 1);
            have_rem = have_rem or lost_bits != 0;
            mantissa >>= shift1;
            exp = 2 - ebias;
        }

        // round q using round-half-to-even
        var exact = !have_rem;
        if (mantissa & 1 != 0) {
            exact = false;
            if (have_rem or (mantissa & 2 != 0)) {
                mantissa += 1;
                if (mantissa >= 1 << msize2) {
                    // 11...1 => 100...0
                    mantissa >>= 1;
                    exp += 1;
                }
            }
        }
        mantissa >>= 1;

        const f = math.scalbn(@intToFloat(T, mantissa), @intCast(i32, exp - msize1));
        if (math.isInf(f)) {
            exact = false;
        }

        return if (self.p.isPositive()) f else -f;
    }

    /// Set a rational from an integer ratio.
    pub fn setRatio(self: *Rational, p: anytype, q: anytype) !void {
        try self.p.set(p);
        try self.q.set(q);

        self.p.setSign(@boolToInt(self.p.isPositive()) ^ @boolToInt(self.q.isPositive()) == 0);
        self.q.setSign(true);

        try self.reduce();

        if (self.q.eqZero()) {
            @panic("cannot set rational with denominator = 0");
        }
    }

    /// Set a Rational directly from an Int.
    pub fn copyInt(self: *Rational, a: Int) !void {
        try self.p.copy(a.toConst());
        try self.q.set(1);
    }

    /// Set a Rational directly from a ratio of two Int's.
    pub fn copyRatio(self: *Rational, a: Int, b: Int) !void {
        try self.p.copy(a.toConst());
        try self.q.copy(b.toConst());

        self.p.setSign(@boolToInt(self.p.isPositive()) ^ @boolToInt(self.q.isPositive()) == 0);
        self.q.setSign(true);

        try self.reduce();
    }

    /// Make a Rational positive.
    pub fn abs(r: *Rational) void {
        r.p.abs();
    }

    /// Negate the sign of a Rational.
    pub fn negate(r: *Rational) void {
        r.p.negate();
    }

    /// Efficiently swap a Rational with another. This swaps the limb pointers and a full copy is not
    /// performed. The address of the limbs field will not be the same after this function.
    pub fn swap(r: *Rational, other: *Rational) void {
        r.p.swap(&other.p);
        r.q.swap(&other.q);
    }

    /// Returns math.Order.lt, math.Order.eq, math.Order.gt if a < b, a == b or a
    /// > b respectively.
    pub fn order(a: Rational, b: Rational) !math.Order {
        return cmpInternal(a, b, true);
    }

    /// Returns math.Order.lt, math.Order.eq, math.Order.gt if |a| < |b|, |a| ==
    /// |b| or |a| > |b| respectively.
    pub fn orderAbs(a: Rational, b: Rational) !math.Order {
        return cmpInternal(a, b, false);
    }

    // p/q > x/y iff p*y > x*q
    fn cmpInternal(a: Rational, b: Rational, is_abs: bool) !math.Order {
        // TODO: Would a div compare algorithm of sorts be viable and quicker? Can we avoid
        // the memory allocations here?
        var q = try Int.init(a.p.allocator);
        defer q.deinit();

        var p = try Int.init(b.p.allocator);
        defer p.deinit();

        try q.mul(a.p.toConst(), b.q.toConst());
        try p.mul(b.p.toConst(), a.q.toConst());

        return if (is_abs) q.orderAbs(p) else q.order(p);
    }

    /// rma = a + b.
    ///
    /// rma, a and b may be aliases. However, it is more efficient if rma does not alias a or b.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn add(rma: *Rational, a: Rational, b: Rational) !void {
        var r = rma;
        var aliased = rma.p.limbs.ptr == a.p.limbs.ptr or rma.p.limbs.ptr == b.p.limbs.ptr;

        var sr: Rational = undefined;
        if (aliased) {
            sr = try Rational.init(rma.p.allocator);
            r = &sr;
            aliased = true;
        }
        defer if (aliased) {
            rma.swap(r);
            r.deinit();
        };

        try r.p.mul(a.p.toConst(), b.q.toConst());
        try r.q.mul(b.p.toConst(), a.q.toConst());
        try r.p.add(r.p.toConst(), r.q.toConst());

        try r.q.mul(a.q.toConst(), b.q.toConst());
        try r.reduce();
    }

    /// rma = a - b.
    ///
    /// rma, a and b may be aliases. However, it is more efficient if rma does not alias a or b.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn sub(rma: *Rational, a: Rational, b: Rational) !void {
        var r = rma;
        var aliased = rma.p.limbs.ptr == a.p.limbs.ptr or rma.p.limbs.ptr == b.p.limbs.ptr;

        var sr: Rational = undefined;
        if (aliased) {
            sr = try Rational.init(rma.p.allocator);
            r = &sr;
            aliased = true;
        }
        defer if (aliased) {
            rma.swap(r);
            r.deinit();
        };

        try r.p.mul(a.p.toConst(), b.q.toConst());
        try r.q.mul(b.p.toConst(), a.q.toConst());
        try r.p.sub(r.p.toConst(), r.q.toConst());

        try r.q.mul(a.q.toConst(), b.q.toConst());
        try r.reduce();
    }

    /// rma = a * b.
    ///
    /// rma, a and b may be aliases. However, it is more efficient if rma does not alias a or b.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn mul(r: *Rational, a: Rational, b: Rational) !void {
        try r.p.mul(a.p.toConst(), b.p.toConst());
        try r.q.mul(a.q.toConst(), b.q.toConst());
        try r.reduce();
    }

    /// rma = a / b.
    ///
    /// rma, a and b may be aliases. However, it is more efficient if rma does not alias a or b.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn div(r: *Rational, a: Rational, b: Rational) !void {
        if (b.p.eqZero()) {
            @panic("division by zero");
        }

        try r.p.mul(a.p.toConst(), b.q.toConst());
        try r.q.mul(b.p.toConst(), a.q.toConst());
        try r.reduce();
    }

    /// Invert the numerator and denominator fields of a Rational. p/q => q/p.
    pub fn invert(r: *Rational) void {
        Int.swap(&r.p, &r.q);
    }

    // reduce r/q such that gcd(r, q) = 1
    fn reduce(r: *Rational) !void {
        var a = try Int.init(r.p.allocator);
        defer a.deinit();

        const sign = r.p.isPositive();
        r.p.abs();
        try a.gcd(r.p, r.q);
        r.p.setSign(sign);

        const one = IntConst{ .limbs = &[_]Limb{1}, .positive = true };
        if (a.toConst().order(one) != .eq) {
            var unused = try Int.init(r.p.allocator);
            defer unused.deinit();

            // TODO: divexact would be useful here
            // TODO: don't copy r.q for div
            try Int.divTrunc(&r.p, &unused, r.p.toConst(), a.toConst());
            try Int.divTrunc(&r.q, &unused, r.q.toConst(), a.toConst());
        }
    }
};

fn extractLowBits(a: Int, comptime T: type) T {
    testing.expect(@typeInfo(T) == .Int);

    const t_bits = @typeInfo(T).Int.bits;
    const limb_bits = @typeInfo(Limb).Int.bits;
    if (t_bits <= limb_bits) {
        return @truncate(T, a.limbs[0]);
    } else {
        var r: T = 0;
        comptime var i: usize = 0;

        // Remainder is always 0 since if t_bits >= limb_bits -> Limb | T and both
        // are powers of two.
        inline while (i < t_bits / limb_bits) : (i += 1) {
            r |= math.shl(T, a.limbs[i], i * limb_bits);
        }

        return r;
    }
}

test "big.rational extractLowBits" {
    var a = try Int.initSet(testing.allocator, 0x11112222333344441234567887654321);
    defer a.deinit();

    const a1 = extractLowBits(a, u8);
    testing.expect(a1 == 0x21);

    const a2 = extractLowBits(a, u16);
    testing.expect(a2 == 0x4321);

    const a3 = extractLowBits(a, u32);
    testing.expect(a3 == 0x87654321);

    const a4 = extractLowBits(a, u64);
    testing.expect(a4 == 0x1234567887654321);

    const a5 = extractLowBits(a, u128);
    testing.expect(a5 == 0x11112222333344441234567887654321);
}

test "big.rational set" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();

    try a.setInt(5);
    testing.expect((try a.p.to(u32)) == 5);
    testing.expect((try a.q.to(u32)) == 1);

    try a.setRatio(7, 3);
    testing.expect((try a.p.to(u32)) == 7);
    testing.expect((try a.q.to(u32)) == 3);

    try a.setRatio(9, 3);
    testing.expect((try a.p.to(i32)) == 3);
    testing.expect((try a.q.to(i32)) == 1);

    try a.setRatio(-9, 3);
    testing.expect((try a.p.to(i32)) == -3);
    testing.expect((try a.q.to(i32)) == 1);

    try a.setRatio(9, -3);
    testing.expect((try a.p.to(i32)) == -3);
    testing.expect((try a.q.to(i32)) == 1);

    try a.setRatio(-9, -3);
    testing.expect((try a.p.to(i32)) == 3);
    testing.expect((try a.q.to(i32)) == 1);
}

test "big.rational setFloat" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();

    try a.setFloat(f64, 2.5);
    testing.expect((try a.p.to(i32)) == 5);
    testing.expect((try a.q.to(i32)) == 2);

    try a.setFloat(f32, -2.5);
    testing.expect((try a.p.to(i32)) == -5);
    testing.expect((try a.q.to(i32)) == 2);

    try a.setFloat(f32, 3.141593);

    //                = 3.14159297943115234375
    testing.expect((try a.p.to(u32)) == 3294199);
    testing.expect((try a.q.to(u32)) == 1048576);

    try a.setFloat(f64, 72.141593120712409172417410926841290461290467124);

    //                = 72.1415931207124145885245525278151035308837890625
    testing.expect((try a.p.to(u128)) == 5076513310880537);
    testing.expect((try a.q.to(u128)) == 70368744177664);
}

test "big.rational setFloatString" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();

    try a.setFloatString("72.14159312071241458852455252781510353");

    //                  = 72.1415931207124145885245525278151035308837890625
    testing.expect((try a.p.to(u128)) == 7214159312071241458852455252781510353);
    testing.expect((try a.q.to(u128)) == 100000000000000000000000000000000000);
}

test "big.rational toFloat" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();

    // = 3.14159297943115234375
    try a.setRatio(3294199, 1048576);
    testing.expect((try a.toFloat(f64)) == 3.14159297943115234375);

    // = 72.1415931207124145885245525278151035308837890625
    try a.setRatio(5076513310880537, 70368744177664);
    testing.expect((try a.toFloat(f64)) == 72.141593120712409172417410926841290461290467124);
}

test "big.rational set/to Float round-trip" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();
    var prng = std.rand.DefaultPrng.init(0x5EED);
    var i: usize = 0;
    while (i < 512) : (i += 1) {
        const r = prng.random.float(f64);
        try a.setFloat(f64, r);
        testing.expect((try a.toFloat(f64)) == r);
    }
}

test "big.rational copy" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();

    var b = try Int.initSet(testing.allocator, 5);
    defer b.deinit();

    try a.copyInt(b);
    testing.expect((try a.p.to(u32)) == 5);
    testing.expect((try a.q.to(u32)) == 1);

    var c = try Int.initSet(testing.allocator, 7);
    defer c.deinit();
    var d = try Int.initSet(testing.allocator, 3);
    defer d.deinit();

    try a.copyRatio(c, d);
    testing.expect((try a.p.to(u32)) == 7);
    testing.expect((try a.q.to(u32)) == 3);

    var e = try Int.initSet(testing.allocator, 9);
    defer e.deinit();
    var f = try Int.initSet(testing.allocator, 3);
    defer f.deinit();

    try a.copyRatio(e, f);
    testing.expect((try a.p.to(u32)) == 3);
    testing.expect((try a.q.to(u32)) == 1);
}

test "big.rational negate" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();

    try a.setInt(-50);
    testing.expect((try a.p.to(i32)) == -50);
    testing.expect((try a.q.to(i32)) == 1);

    a.negate();
    testing.expect((try a.p.to(i32)) == 50);
    testing.expect((try a.q.to(i32)) == 1);

    a.negate();
    testing.expect((try a.p.to(i32)) == -50);
    testing.expect((try a.q.to(i32)) == 1);
}

test "big.rational abs" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();

    try a.setInt(-50);
    testing.expect((try a.p.to(i32)) == -50);
    testing.expect((try a.q.to(i32)) == 1);

    a.abs();
    testing.expect((try a.p.to(i32)) == 50);
    testing.expect((try a.q.to(i32)) == 1);

    a.abs();
    testing.expect((try a.p.to(i32)) == 50);
    testing.expect((try a.q.to(i32)) == 1);
}

test "big.rational swap" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();
    var b = try Rational.init(testing.allocator);
    defer b.deinit();

    try a.setRatio(50, 23);
    try b.setRatio(17, 3);

    testing.expect((try a.p.to(u32)) == 50);
    testing.expect((try a.q.to(u32)) == 23);

    testing.expect((try b.p.to(u32)) == 17);
    testing.expect((try b.q.to(u32)) == 3);

    a.swap(&b);

    testing.expect((try a.p.to(u32)) == 17);
    testing.expect((try a.q.to(u32)) == 3);

    testing.expect((try b.p.to(u32)) == 50);
    testing.expect((try b.q.to(u32)) == 23);
}

test "big.rational order" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();
    var b = try Rational.init(testing.allocator);
    defer b.deinit();

    try a.setRatio(500, 231);
    try b.setRatio(18903, 8584);
    testing.expect((try a.order(b)) == .lt);

    try a.setRatio(890, 10);
    try b.setRatio(89, 1);
    testing.expect((try a.order(b)) == .eq);
}

test "big.rational add single-limb" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();
    var b = try Rational.init(testing.allocator);
    defer b.deinit();

    try a.setRatio(500, 231);
    try b.setRatio(18903, 8584);
    testing.expect((try a.order(b)) == .lt);

    try a.setRatio(890, 10);
    try b.setRatio(89, 1);
    testing.expect((try a.order(b)) == .eq);
}

test "big.rational add" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();
    var b = try Rational.init(testing.allocator);
    defer b.deinit();
    var r = try Rational.init(testing.allocator);
    defer r.deinit();

    try a.setRatio(78923, 23341);
    try b.setRatio(123097, 12441414);
    try a.add(a, b);

    try r.setRatio(984786924199, 290395044174);
    testing.expect((try a.order(r)) == .eq);
}

test "big.rational sub" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();
    var b = try Rational.init(testing.allocator);
    defer b.deinit();
    var r = try Rational.init(testing.allocator);
    defer r.deinit();

    try a.setRatio(78923, 23341);
    try b.setRatio(123097, 12441414);
    try a.sub(a, b);

    try r.setRatio(979040510045, 290395044174);
    testing.expect((try a.order(r)) == .eq);
}

test "big.rational mul" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();
    var b = try Rational.init(testing.allocator);
    defer b.deinit();
    var r = try Rational.init(testing.allocator);
    defer r.deinit();

    try a.setRatio(78923, 23341);
    try b.setRatio(123097, 12441414);
    try a.mul(a, b);

    try r.setRatio(571481443, 17082061422);
    testing.expect((try a.order(r)) == .eq);
}

test "big.rational div" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();
    var b = try Rational.init(testing.allocator);
    defer b.deinit();
    var r = try Rational.init(testing.allocator);
    defer r.deinit();

    try a.setRatio(78923, 23341);
    try b.setRatio(123097, 12441414);
    try a.div(a, b);

    try r.setRatio(75531824394, 221015929);
    testing.expect((try a.order(r)) == .eq);
}

test "big.rational div" {
    var a = try Rational.init(testing.allocator);
    defer a.deinit();
    var r = try Rational.init(testing.allocator);
    defer r.deinit();

    try a.setRatio(78923, 23341);
    a.invert();

    try r.setRatio(23341, 78923);
    testing.expect((try a.order(r)) == .eq);

    try a.setRatio(-78923, 23341);
    a.invert();

    try r.setRatio(-23341, 78923);
    testing.expect((try a.order(r)) == .eq);
}
