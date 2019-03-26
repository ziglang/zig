const std = @import("../../std.zig");
const builtin = @import("builtin");
const debug = std.debug;
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const TypeId = builtin.TypeId;

const bn = @import("int.zig");
const Limb = bn.Limb;
const DoubleLimb = bn.DoubleLimb;
const Int = bn.Int;

pub const Rational = struct {
    // sign of Rational is a.positive, b.positive is ignored
    p: Int,
    q: Int,

    pub fn init(a: *Allocator) !Rational {
        return Rational{
            .p = try Int.init(a),
            .q = try Int.initSet(a, 1),
        };
    }

    pub fn deinit(self: *Rational) void {
        self.p.deinit();
        self.q.deinit();
    }

    pub fn setInt(self: *Rational, a: var) !void {
        try self.p.set(a);
        try self.q.set(1);
    }

    // TODO: Accept a/b fractions and exponent form
    pub fn setFloatString(self: *Rational, str: []const u8) !void {
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

            const base = Int.initFixed(([]Limb{10})[0..]);

            var j: usize = start;
            while (j < str.len - i - 1) : (j += 1) {
                try self.p.mul(self.p, base);
            }

            try self.q.setString(10, str[i + 1 ..]);
            try self.p.add(self.p, self.q);

            try self.q.set(1);
            var k: usize = i + 1;
            while (k < str.len) : (k += 1) {
                try self.q.mul(self.q, base);
            }

            try self.reduce();
        } else {
            try self.p.setString(10, str[0..]);
            try self.q.set(1);
        }
    }

    // Translated from golang.go/src/math/big/rat.go.
    pub fn setFloat(self: *Rational, comptime T: type, f: T) !void {
        debug.assert(@typeId(T) == builtin.TypeId.Float);

        const UnsignedIntType = @IntType(false, T.bit_count);
        const f_bits = @bitCast(UnsignedIntType, f);

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
        self.p.positive = f >= 0;

        try self.q.set(1);
        if (shift >= 0) {
            try self.q.shiftLeft(self.q, @intCast(usize, shift));
        } else {
            try self.p.shiftLeft(self.p, @intCast(usize, -shift));
        }

        try self.reduce();
    }

    // Translated from golang.go/src/math/big/rat.go.
    pub fn toFloat(self: Rational, comptime T: type) !T {
        debug.assert(@typeId(T) == builtin.TypeId.Float);

        const fsize = T.bit_count;
        const BitReprType = @IntType(false, T.bit_count);

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
        var q = try Int.init(self.p.allocator.?);
        defer q.deinit();

        // unused
        var r = try Int.init(self.p.allocator.?);
        defer r.deinit();

        try Int.divTrunc(&q, &r, a2, b2);

        var mantissa = extractLowBits(q, BitReprType);
        var have_rem = r.len > 0;

        // 3. q didn't fit in msize2 bits, redo division b2 << 1
        if (mantissa >> msize2 == 1) {
            if (mantissa & 1 == 1) {
                have_rem = true;
            }
            mantissa >>= 1;
            exp += 1;
        }
        if (mantissa >> msize1 != 1) {
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

        return if (self.p.positive) f else -f;
    }

    pub fn setRatio(self: *Rational, p: var, q: var) !void {
        try self.p.set(p);
        try self.q.set(q);

        self.p.positive = (@boolToInt(self.p.positive) ^ @boolToInt(self.q.positive)) == 0;
        self.q.positive = true;
        try self.reduce();

        if (self.q.eqZero()) {
            @panic("cannot set rational with denominator = 0");
        }
    }

    pub fn copyInt(self: *Rational, a: Int) !void {
        try self.p.copy(a);
        try self.q.set(1);
    }

    pub fn copyRatio(self: *Rational, a: Int, b: Int) !void {
        try self.p.copy(a);
        try self.q.copy(b);

        self.p.positive = (@boolToInt(self.p.positive) ^ @boolToInt(self.q.positive)) == 0;
        self.q.positive = true;
        try self.reduce();
    }

    pub fn abs(r: *Rational) void {
        r.p.abs();
    }

    pub fn negate(r: *Rational) void {
        r.p.negate();
    }

    pub fn swap(r: *Rational, other: *Rational) void {
        r.p.swap(&other.p);
        r.q.swap(&other.q);
    }

    pub fn cmp(a: Rational, b: Rational) !i8 {
        return cmpInternal(a, b, true);
    }

    pub fn cmpAbs(a: Rational, b: Rational) !i8 {
        return cmpInternal(a, b, false);
    }

    // p/q > x/y iff p*y > x*q
    fn cmpInternal(a: Rational, b: Rational, is_abs: bool) !i8 {
        // TODO: Would a div compare algorithm of sorts be viable and quicker? Can we avoid
        // the memory allocations here?
        var q = try Int.init(a.p.allocator.?);
        defer q.deinit();

        var p = try Int.init(b.p.allocator.?);
        defer p.deinit();

        try q.mul(a.p, b.q);
        try p.mul(b.p, a.q);

        return if (is_abs) q.cmpAbs(p) else q.cmp(p);
    }

    // r/q = ap/aq + bp/bq = (ap*bq + bp*aq) / (aq*bq)
    //
    // For best performance, rma should not alias a or b.
    pub fn add(rma: *Rational, a: Rational, b: Rational) !void {
        var r = rma;
        var aliased = rma.p.limbs.ptr == a.p.limbs.ptr or rma.p.limbs.ptr == b.p.limbs.ptr;

        var sr: Rational = undefined;
        if (aliased) {
            sr = try Rational.init(rma.p.allocator.?);
            r = &sr;
            aliased = true;
        }
        defer if (aliased) {
            rma.swap(r);
            r.deinit();
        };

        try r.p.mul(a.p, b.q);
        try r.q.mul(b.p, a.q);
        try r.p.add(r.p, r.q);

        try r.q.mul(a.q, b.q);
        try r.reduce();
    }

    // r/q = ap/aq - bp/bq = (ap*bq - bp*aq) / (aq*bq)
    //
    // For best performance, rma should not alias a or b.
    pub fn sub(rma: *Rational, a: Rational, b: Rational) !void {
        var r = rma;
        var aliased = rma.p.limbs.ptr == a.p.limbs.ptr or rma.p.limbs.ptr == b.p.limbs.ptr;

        var sr: Rational = undefined;
        if (aliased) {
            sr = try Rational.init(rma.p.allocator.?);
            r = &sr;
            aliased = true;
        }
        defer if (aliased) {
            rma.swap(r);
            r.deinit();
        };

        try r.p.mul(a.p, b.q);
        try r.q.mul(b.p, a.q);
        try r.p.sub(r.p, r.q);

        try r.q.mul(a.q, b.q);
        try r.reduce();
    }

    // r/q = ap/aq * bp/bq = ap*bp / aq*bq
    pub fn mul(r: *Rational, a: Rational, b: Rational) !void {
        try r.p.mul(a.p, b.p);
        try r.q.mul(a.q, b.q);
        try r.reduce();
    }

    // r/q = (ap/aq) / (bp/bq) = ap*bq / bp*aq
    pub fn div(r: *Rational, a: Rational, b: Rational) !void {
        if (b.p.eqZero()) {
            @panic("division by zero");
        }

        try r.p.mul(a.p, b.q);
        try r.q.mul(b.p, a.q);
        try r.reduce();
    }

    // r/q = q/r
    pub fn invert(r: *Rational) void {
        Int.swap(&r.p, &r.q);
    }

    // reduce r/q such that gcd(r, q) = 1
    fn reduce(r: *Rational) !void {
        var a = try Int.init(r.p.allocator.?);
        defer a.deinit();

        const sign = r.p.positive;

        r.p.abs();
        try gcd(&a, r.p, r.q);
        r.p.positive = sign;

        const one = Int.initFixed(([]Limb{1})[0..]);
        if (a.cmp(one) != 0) {
            var unused = try Int.init(r.p.allocator.?);
            defer unused.deinit();

            // TODO: divexact would be useful here
            // TODO: don't copy r.q for div
            try Int.divTrunc(&r.p, &unused, r.p, a);
            try Int.divTrunc(&r.q, &unused, r.q, a);
        }
    }
};

var al = debug.global_allocator;

const SignedDoubleLimb = @IntType(true, DoubleLimb.bit_count);

fn gcd(rma: *Int, x: Int, y: Int) !void {
    var r = rma;
    var aliased = rma.limbs.ptr == x.limbs.ptr or rma.limbs.ptr == y.limbs.ptr;

    var sr: Int = undefined;
    if (aliased) {
        sr = try Int.initCapacity(rma.allocator.?, math.max(x.len, y.len));
        r = &sr;
        aliased = true;
    }
    defer if (aliased) {
        rma.swap(r);
        r.deinit();
    };

    if (x.cmp(y) > 0) {
        try gcdLehmer(r, x, y);
    } else {
        try gcdLehmer(r, y, x);
    }
}

// Storage must live for the lifetime of the returned value
fn FixedIntFromSignedDoubleLimb(A: SignedDoubleLimb, storage: []Limb) Int {
    std.debug.assert(storage.len >= 2);

    var A_is_positive = A >= 0;
    const Au = @intCast(DoubleLimb, if (A < 0) -A else A);
    storage[0] = @truncate(Limb, Au);
    storage[1] = @truncate(Limb, Au >> Limb.bit_count);
    var Ap = Int.initFixed(storage[0..2]);
    Ap.positive = A_is_positive;
    return Ap;
}

// Handbook of Applied Cryptography, 14.57
//
// r = gcd(x, y) where x, y > 0
fn gcdLehmer(r: *Int, xa: Int, ya: Int) !void {
    debug.assert(xa.positive and ya.positive);
    debug.assert(xa.cmp(ya) >= 0);

    var x = try xa.clone();
    defer x.deinit();

    var y = try ya.clone();
    defer y.deinit();

    var T = try Int.init(r.allocator.?);
    defer T.deinit();

    while (y.len > 1) {
        debug.assert(x.len >= y.len);

        // chop the leading zeros of the limbs and normalize
        const offset = @clz(x.limbs[x.len - 1]);

        var xh: SignedDoubleLimb = math.shl(Limb, x.limbs[x.len - 1], offset) |
            math.shr(Limb, x.limbs[x.len - 2], Limb.bit_count - offset);

        var yh: SignedDoubleLimb = if (y.len == x.len)
            math.shl(Limb, y.limbs[y.len - 1], offset) | math.shr(Limb, y.limbs[y.len - 2], Limb.bit_count - offset)
        else if (y.len == x.len - 1)
            math.shr(Limb, y.limbs[y.len - 2], Limb.bit_count - offset)
        else
            0;

        var A: SignedDoubleLimb = 1;
        var B: SignedDoubleLimb = 0;
        var C: SignedDoubleLimb = 0;
        var D: SignedDoubleLimb = 1;

        while (yh + C != 0 and yh + D != 0) {
            const q = @divFloor(xh + A, yh + C);
            const qp = @divFloor(xh + B, yh + D);
            if (q != qp) {
                break;
            }

            var t = A - q * C;
            A = C;
            C = t;
            t = B - q * D;
            B = D;
            D = t;

            t = xh - q * yh;
            xh = yh;
            yh = t;
        }

        if (B == 0) {
            // T = x % y, r is unused
            try Int.divTrunc(r, &T, x, y);
            debug.assert(T.positive);

            x.swap(&y);
            y.swap(&T);
        } else {
            var storage: [8]Limb = undefined;
            const Ap = FixedIntFromSignedDoubleLimb(A, storage[0..2]);
            const Bp = FixedIntFromSignedDoubleLimb(B, storage[2..4]);
            const Cp = FixedIntFromSignedDoubleLimb(C, storage[4..6]);
            const Dp = FixedIntFromSignedDoubleLimb(D, storage[6..8]);

            // T = Ax + By
            try r.mul(x, Ap);
            try T.mul(y, Bp);
            try T.add(r.*, T);

            // u = Cx + Dy, r as u
            try x.mul(x, Cp);
            try r.mul(y, Dp);
            try r.add(x, r.*);

            x.swap(&T);
            y.swap(r);
        }
    }

    // euclidean algorithm
    debug.assert(x.cmp(y) >= 0);

    while (!y.eqZero()) {
        try Int.divTrunc(&T, r, x, y);
        x.swap(&y);
        y.swap(r);
    }

    r.swap(&x);
}

test "big.rational gcd non-one small" {
    var a = try Int.initSet(al, 17);
    var b = try Int.initSet(al, 97);
    var r = try Int.init(al);

    try gcd(&r, a, b);

    debug.assert((try r.to(u32)) == 1);
}

test "big.rational gcd non-one small" {
    var a = try Int.initSet(al, 4864);
    var b = try Int.initSet(al, 3458);
    var r = try Int.init(al);

    try gcd(&r, a, b);

    debug.assert((try r.to(u32)) == 38);
}

test "big.rational gcd non-one large" {
    var a = try Int.initSet(al, 0xffffffffffffffff);
    var b = try Int.initSet(al, 0xffffffffffffffff7777);
    var r = try Int.init(al);

    try gcd(&r, a, b);

    debug.assert((try r.to(u32)) == 4369);
}

test "big.rational gcd large multi-limb result" {
    var a = try Int.initSet(al, 0x12345678123456781234567812345678123456781234567812345678);
    var b = try Int.initSet(al, 0x12345671234567123456712345671234567123456712345671234567);
    var r = try Int.init(al);

    try gcd(&r, a, b);

    debug.assert((try r.to(u256)) == 0xf000000ff00000fff0000ffff000fffff00ffffff1);
}

fn extractLowBits(a: Int, comptime T: type) T {
    debug.assert(@typeId(T) == builtin.TypeId.Int);

    if (T.bit_count <= Limb.bit_count) {
        return @truncate(T, a.limbs[0]);
    } else {
        var r: T = 0;
        comptime var i: usize = 0;

        // Remainder is always 0 since if T.bit_count >= Limb.bit_count -> Limb | T and both
        // are powers of two.
        inline while (i < T.bit_count / Limb.bit_count) : (i += 1) {
            r |= math.shl(T, a.limbs[i], i * Limb.bit_count);
        }

        return r;
    }
}

test "big.rational extractLowBits" {
    var a = try Int.initSet(al, 0x11112222333344441234567887654321);

    const a1 = extractLowBits(a, u8);
    debug.assert(a1 == 0x21);

    const a2 = extractLowBits(a, u16);
    debug.assert(a2 == 0x4321);

    const a3 = extractLowBits(a, u32);
    debug.assert(a3 == 0x87654321);

    const a4 = extractLowBits(a, u64);
    debug.assert(a4 == 0x1234567887654321);

    const a5 = extractLowBits(a, u128);
    debug.assert(a5 == 0x11112222333344441234567887654321);
}

test "big.rational set" {
    var a = try Rational.init(al);

    try a.setInt(5);
    debug.assert((try a.p.to(u32)) == 5);
    debug.assert((try a.q.to(u32)) == 1);

    try a.setRatio(7, 3);
    debug.assert((try a.p.to(u32)) == 7);
    debug.assert((try a.q.to(u32)) == 3);

    try a.setRatio(9, 3);
    debug.assert((try a.p.to(i32)) == 3);
    debug.assert((try a.q.to(i32)) == 1);

    try a.setRatio(-9, 3);
    debug.assert((try a.p.to(i32)) == -3);
    debug.assert((try a.q.to(i32)) == 1);

    try a.setRatio(9, -3);
    debug.assert((try a.p.to(i32)) == -3);
    debug.assert((try a.q.to(i32)) == 1);

    try a.setRatio(-9, -3);
    debug.assert((try a.p.to(i32)) == 3);
    debug.assert((try a.q.to(i32)) == 1);
}

test "big.rational setFloat" {
    var a = try Rational.init(al);

    try a.setFloat(f64, 2.5);
    debug.assert((try a.p.to(i32)) == 5);
    debug.assert((try a.q.to(i32)) == 2);

    try a.setFloat(f32, -2.5);
    debug.assert((try a.p.to(i32)) == -5);
    debug.assert((try a.q.to(i32)) == 2);

    try a.setFloat(f32, 3.141593);

    //                = 3.14159297943115234375
    debug.assert((try a.p.to(u32)) == 3294199);
    debug.assert((try a.q.to(u32)) == 1048576);

    try a.setFloat(f64, 72.141593120712409172417410926841290461290467124);

    //                = 72.1415931207124145885245525278151035308837890625
    debug.assert((try a.p.to(u128)) == 5076513310880537);
    debug.assert((try a.q.to(u128)) == 70368744177664);
}

test "big.rational setFloatString" {
    var a = try Rational.init(al);

    try a.setFloatString("72.14159312071241458852455252781510353");

    //                  = 72.1415931207124145885245525278151035308837890625
    debug.assert((try a.p.to(u128)) == 7214159312071241458852455252781510353);
    debug.assert((try a.q.to(u128)) == 100000000000000000000000000000000000);
}

test "big.rational toFloat" {
    var a = try Rational.init(al);

    // = 3.14159297943115234375
    try a.setRatio(3294199, 1048576);
    debug.assert((try a.toFloat(f64)) == 3.14159297943115234375);

    // = 72.1415931207124145885245525278151035308837890625
    try a.setRatio(5076513310880537, 70368744177664);
    debug.assert((try a.toFloat(f64)) == 72.141593120712409172417410926841290461290467124);
}

test "big.rational set/to Float round-trip" {
    // toFloat allocates memory in a loop so we need to free it
    var buf: [512 * 1024]u8 = undefined;
    var fixed = std.heap.FixedBufferAllocator.init(buf[0..]);

    var a = try Rational.init(&fixed.allocator);

    var prng = std.rand.DefaultPrng.init(0x5EED);
    var i: usize = 0;
    while (i < 512) : (i += 1) {
        const r = prng.random.float(f64);
        try a.setFloat(f64, r);
        debug.assert((try a.toFloat(f64)) == r);
    }
}

test "big.rational copy" {
    var a = try Rational.init(al);

    const b = try Int.initSet(al, 5);

    try a.copyInt(b);
    debug.assert((try a.p.to(u32)) == 5);
    debug.assert((try a.q.to(u32)) == 1);

    const c = try Int.initSet(al, 7);
    const d = try Int.initSet(al, 3);

    try a.copyRatio(c, d);
    debug.assert((try a.p.to(u32)) == 7);
    debug.assert((try a.q.to(u32)) == 3);

    const e = try Int.initSet(al, 9);
    const f = try Int.initSet(al, 3);

    try a.copyRatio(e, f);
    debug.assert((try a.p.to(u32)) == 3);
    debug.assert((try a.q.to(u32)) == 1);
}

test "big.rational negate" {
    var a = try Rational.init(al);

    try a.setInt(-50);
    debug.assert((try a.p.to(i32)) == -50);
    debug.assert((try a.q.to(i32)) == 1);

    a.negate();
    debug.assert((try a.p.to(i32)) == 50);
    debug.assert((try a.q.to(i32)) == 1);

    a.negate();
    debug.assert((try a.p.to(i32)) == -50);
    debug.assert((try a.q.to(i32)) == 1);
}

test "big.rational abs" {
    var a = try Rational.init(al);

    try a.setInt(-50);
    debug.assert((try a.p.to(i32)) == -50);
    debug.assert((try a.q.to(i32)) == 1);

    a.abs();
    debug.assert((try a.p.to(i32)) == 50);
    debug.assert((try a.q.to(i32)) == 1);

    a.abs();
    debug.assert((try a.p.to(i32)) == 50);
    debug.assert((try a.q.to(i32)) == 1);
}

test "big.rational swap" {
    var a = try Rational.init(al);
    var b = try Rational.init(al);

    try a.setRatio(50, 23);
    try b.setRatio(17, 3);

    debug.assert((try a.p.to(u32)) == 50);
    debug.assert((try a.q.to(u32)) == 23);

    debug.assert((try b.p.to(u32)) == 17);
    debug.assert((try b.q.to(u32)) == 3);

    a.swap(&b);

    debug.assert((try a.p.to(u32)) == 17);
    debug.assert((try a.q.to(u32)) == 3);

    debug.assert((try b.p.to(u32)) == 50);
    debug.assert((try b.q.to(u32)) == 23);
}

test "big.rational cmp" {
    var a = try Rational.init(al);
    var b = try Rational.init(al);

    try a.setRatio(500, 231);
    try b.setRatio(18903, 8584);
    debug.assert((try a.cmp(b)) < 0);

    try a.setRatio(890, 10);
    try b.setRatio(89, 1);
    debug.assert((try a.cmp(b)) == 0);
}

test "big.rational add single-limb" {
    var a = try Rational.init(al);
    var b = try Rational.init(al);

    try a.setRatio(500, 231);
    try b.setRatio(18903, 8584);
    debug.assert((try a.cmp(b)) < 0);

    try a.setRatio(890, 10);
    try b.setRatio(89, 1);
    debug.assert((try a.cmp(b)) == 0);
}

test "big.rational add" {
    var a = try Rational.init(al);
    var b = try Rational.init(al);
    var r = try Rational.init(al);

    try a.setRatio(78923, 23341);
    try b.setRatio(123097, 12441414);
    try a.add(a, b);

    try r.setRatio(984786924199, 290395044174);
    debug.assert((try a.cmp(r)) == 0);
}

test "big.rational sub" {
    var a = try Rational.init(al);
    var b = try Rational.init(al);
    var r = try Rational.init(al);

    try a.setRatio(78923, 23341);
    try b.setRatio(123097, 12441414);
    try a.sub(a, b);

    try r.setRatio(979040510045, 290395044174);
    debug.assert((try a.cmp(r)) == 0);
}

test "big.rational mul" {
    var a = try Rational.init(al);
    var b = try Rational.init(al);
    var r = try Rational.init(al);

    try a.setRatio(78923, 23341);
    try b.setRatio(123097, 12441414);
    try a.mul(a, b);

    try r.setRatio(571481443, 17082061422);
    debug.assert((try a.cmp(r)) == 0);
}

test "big.rational div" {
    var a = try Rational.init(al);
    var b = try Rational.init(al);
    var r = try Rational.init(al);

    try a.setRatio(78923, 23341);
    try b.setRatio(123097, 12441414);
    try a.div(a, b);

    try r.setRatio(75531824394, 221015929);
    debug.assert((try a.cmp(r)) == 0);
}

test "big.rational div" {
    var a = try Rational.init(al);
    var r = try Rational.init(al);

    try a.setRatio(78923, 23341);
    a.invert();

    try r.setRatio(23341, 78923);
    debug.assert((try a.cmp(r)) == 0);

    try a.setRatio(-78923, 23341);
    a.invert();

    try r.setRatio(-23341, 78923);
    debug.assert((try a.cmp(r)) == 0);
}
