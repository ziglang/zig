//! Allocation-free, (best-effort) constant-time, finite field arithmetic for large integers.
//!
//! Unlike `std.math.big`, these integers have a fixed maximum length and are only designed to be used for modular arithmetic.
//! Arithmetic operations are meant to run in constant-time for a given modulus, making them suitable for cryptography.
//!
//! Parts of that code was ported from the BSD-licensed crypto/internal/bigmod/nat.go file in the Go language, itself inspired from BearSSL.

const std = @import("std");
const builtin = std.builtin;
const crypto = std.crypto;
const math = std.math;
const mem = std.mem;
const meta = std.meta;
const testing = std.testing;
const BoundedArray = std.BoundedArray;
const assert = std.debug.assert;

// A Limb is a single digit in a big integer.
const Limb = usize;

// The number of reserved bits in a Limb.
const carry_bits = 1;

// The number of active bits in a Limb.
const t_bits: usize = @bitSizeOf(Limb) - carry_bits;

// A TLimb is a Limb that is truncated to t_bits.
const TLimb = meta.Int(.unsigned, t_bits);

const native_endian = @import("builtin").target.cpu.arch.endian();

// A WideLimb is a Limb that is twice as wide as a normal Limb.
const WideLimb = struct {
    hi: Limb,
    lo: Limb,
};

/// Value is too large for the destination.
pub const OverflowError = error{Overflow};

/// Invalid modulus. Modulus must be odd.
pub const InvalidModulusError = error{ EvenModulus, ModulusTooSmall };

/// Exponentation with a null exponent.
/// Exponentiation in cryptographic protocols is almost always a sign of a bug which can lead to trivial attacks.
/// Therefore, this module returns an error when a null exponent is encountered, encouraging applications to handle this case explicitly.
pub const NullExponentError = error{NullExponent};

/// Invalid field element for the given modulus.
pub const FieldElementError = error{NonCanonical};

/// Invalid representation (Montgomery vs non-Montgomery domain.)
pub const RepresentationError = error{UnexpectedRepresentation};

/// The set of all possible errors `std.crypto.ff` functions can return.
pub const Error = OverflowError || InvalidModulusError || NullExponentError || FieldElementError || RepresentationError;

/// An unsigned big integer with a fixed maximum size (`max_bits`), suitable for cryptographic operations.
/// Unless side-channels mitigations are explicitly disabled, operations are designed to be constant-time.
pub fn Uint(comptime max_bits: comptime_int) type {
    comptime assert(@bitSizeOf(Limb) % 8 == 0); // Limb size must be a multiple of 8

    return struct {
        const Self = @This();

        const max_limbs_count = math.divCeil(usize, max_bits, t_bits) catch unreachable;
        const Limbs = BoundedArray(Limb, max_limbs_count);
        limbs: Limbs,

        /// Number of bytes required to serialize an integer.
        pub const encoded_bytes = math.divCeil(usize, max_bits, 8) catch unreachable;

        // Returns the number of active limbs.
        fn limbs_count(self: Self) usize {
            return self.limbs.len;
        }

        // Removes limbs whose value is zero from the active limbs.
        fn normalize(self: Self) Self {
            var res = self;
            if (self.limbs_count() < 2) {
                return res;
            }
            var i = self.limbs_count() - 1;
            while (i > 0 and res.limbs.get(i) == 0) : (i -= 1) {}
            res.limbs.resize(i + 1) catch unreachable;
            return res;
        }

        /// The zero integer.
        pub const zero = zero: {
            var limbs = Limbs.init(0) catch unreachable;
            limbs.appendNTimesAssumeCapacity(0, max_limbs_count);
            break :zero Self{ .limbs = limbs };
        };

        /// Creates a new big integer from a primitive type.
        /// This function may not run in constant time.
        pub fn fromPrimitive(comptime T: type, x_: T) OverflowError!Self {
            var x = x_;
            var out = Self.zero;
            for (0..out.limbs.capacity()) |i| {
                const t = if (@bitSizeOf(T) > t_bits) @as(TLimb, @truncate(x)) else x;
                out.limbs.set(i, t);
                x = math.shr(T, x, t_bits);
            }
            if (x != 0) {
                return error.Overflow;
            }
            return out;
        }

        /// Converts a big integer to a primitive type.
        /// This function may not run in constant time.
        pub fn toPrimitive(self: Self, comptime T: type) OverflowError!T {
            var x: T = 0;
            var i = self.limbs_count() - 1;
            while (true) : (i -= 1) {
                if (@bitSizeOf(T) >= t_bits and math.shr(T, x, @bitSizeOf(T) - t_bits) != 0) {
                    return error.Overflow;
                }
                x = math.shl(T, x, t_bits);
                const v = math.cast(T, self.limbs.get(i)) orelse return error.Overflow;
                x |= v;
                if (i == 0) break;
            }
            return x;
        }

        /// Encodes a big integer into a byte array.
        pub fn toBytes(self: Self, bytes: []u8, comptime endian: builtin.Endian) OverflowError!void {
            if (bytes.len == 0) {
                if (self.isZero()) return;
                return error.Overflow;
            }
            @memset(bytes, 0);
            var shift: usize = 0;
            var out_i: usize = switch (endian) {
                .Big => bytes.len - 1,
                .Little => 0,
            };
            for (0..self.limbs.len) |i| {
                var remaining_bits = t_bits;
                var limb = self.limbs.get(i);
                while (remaining_bits >= 8) {
                    bytes[out_i] |= math.shl(u8, @as(u8, @truncate(limb)), shift);
                    const consumed = 8 - shift;
                    limb >>= @as(u4, @truncate(consumed));
                    remaining_bits -= consumed;
                    shift = 0;
                    switch (endian) {
                        .Big => {
                            if (out_i == 0) {
                                if (i != self.limbs.len - 1 or limb != 0) {
                                    return error.Overflow;
                                }
                                return;
                            }
                            out_i -= 1;
                        },
                        .Little => {
                            out_i += 1;
                            if (out_i == bytes.len) {
                                if (i != self.limbs.len - 1 or limb != 0) {
                                    return error.Overflow;
                                }
                                return;
                            }
                        },
                    }
                }
                bytes[out_i] |= @as(u8, @truncate(limb));
                shift = remaining_bits;
            }
        }

        /// Creates a new big integer from a byte array.
        pub fn fromBytes(bytes: []const u8, comptime endian: builtin.Endian) OverflowError!Self {
            if (bytes.len == 0) return Self.zero;
            var shift: usize = 0;
            var out = Self.zero;
            var out_i: usize = 0;
            var i: usize = switch (endian) {
                .Big => bytes.len - 1,
                .Little => 0,
            };
            while (true) {
                const bi = bytes[i];
                out.limbs.set(out_i, out.limbs.get(out_i) | math.shl(Limb, bi, shift));
                shift += 8;
                if (shift >= t_bits) {
                    shift -= t_bits;
                    out.limbs.set(out_i, @as(TLimb, @truncate(out.limbs.get(out_i))));
                    const overflow = math.shr(Limb, bi, 8 - shift);
                    out_i += 1;
                    if (out_i >= out.limbs.len) {
                        if (overflow != 0 or i != 0) {
                            return error.Overflow;
                        }
                        break;
                    }
                    out.limbs.set(out_i, overflow);
                }
                switch (endian) {
                    .Big => {
                        if (i == 0) break;
                        i -= 1;
                    },
                    .Little => {
                        i += 1;
                        if (i == bytes.len) break;
                    },
                }
            }
            return out;
        }

        /// Returns `true` if both integers are equal.
        pub fn eql(x: Self, y: Self) bool {
            return crypto.utils.timingSafeEql([max_limbs_count]Limb, x.limbs.buffer, y.limbs.buffer);
        }

        /// Compares two integers.
        pub fn compare(x: Self, y: Self) math.Order {
            return crypto.utils.timingSafeCompare(
                Limb,
                x.limbs.constSlice(),
                y.limbs.constSlice(),
                .Little,
            );
        }

        /// Returns `true` if the integer is zero.
        pub fn isZero(x: Self) bool {
            const x_limbs = x.limbs.constSlice();
            var t: Limb = 0;
            for (0..x.limbs_count()) |i| {
                t |= x_limbs[i];
            }
            return ct.eql(t, 0);
        }

        /// Returns `true` if the integer is odd.
        pub fn isOdd(x: Self) bool {
            return @as(bool, @bitCast(@as(u1, @truncate(x.limbs.get(0)))));
        }

        /// Adds `y` to `x`, and returns `true` if the operation overflowed.
        pub fn addWithOverflow(x: *Self, y: Self) u1 {
            return x.conditionalAddWithOverflow(true, y);
        }

        /// Subtracts `y` from `x`, and returns `true` if the operation overflowed.
        pub fn subWithOverflow(x: *Self, y: Self) u1 {
            return x.conditionalSubWithOverflow(true, y);
        }

        // Replaces the limbs of `x` with the limbs of `y` if `on` is `true`.
        fn cmov(x: *Self, on: bool, y: Self) void {
            const x_limbs = x.limbs.slice();
            const y_limbs = y.limbs.constSlice();
            for (0..y.limbs_count()) |i| {
                x_limbs[i] = ct.select(on, y_limbs[i], x_limbs[i]);
            }
        }

        // Adds `y` to `x` if `on` is `true`, and returns `true` if the operation overflowed.
        fn conditionalAddWithOverflow(x: *Self, on: bool, y: Self) u1 {
            assert(x.limbs_count() == y.limbs_count()); // Operands must have the same size.
            const x_limbs = x.limbs.slice();
            const y_limbs = y.limbs.constSlice();

            var carry: u1 = 0;
            for (0..x.limbs_count()) |i| {
                const res = x_limbs[i] + y_limbs[i] + carry;
                x_limbs[i] = ct.select(on, @as(TLimb, @truncate(res)), x_limbs[i]);
                carry = @as(u1, @truncate(res >> t_bits));
            }
            return carry;
        }

        // Subtracts `y` from `x` if `on` is `true`, and returns `true` if the operation overflowed.
        fn conditionalSubWithOverflow(x: *Self, on: bool, y: Self) u1 {
            assert(x.limbs_count() == y.limbs_count()); // Operands must have the same size.
            const x_limbs = x.limbs.slice();
            const y_limbs = y.limbs.constSlice();

            var borrow: u1 = 0;
            for (0..x.limbs_count()) |i| {
                const res = x_limbs[i] -% y_limbs[i] -% borrow;
                x_limbs[i] = ct.select(on, @as(TLimb, @truncate(res)), x_limbs[i]);
                borrow = @as(u1, @truncate(res >> t_bits));
            }
            return borrow;
        }
    };
}

/// A field element.
fn Fe_(comptime bits: comptime_int) type {
    return struct {
        const Self = @This();

        const FeUint = Uint(bits);

        /// The element value as a `Uint`.
        v: FeUint,

        /// `true` is the element is in Montgomery form.
        montgomery: bool = false,

        /// The maximum number of bytes required to encode a field element.
        pub const encoded_bytes = FeUint.encoded_bytes;

        // The number of active limbs to represent the field element.
        fn limbs_count(self: Self) usize {
            return self.v.limbs_count();
        }

        /// Creates a field element from a primitive.
        /// This function may not run in constant time.
        pub fn fromPrimitive(comptime T: type, m: Modulus(bits), x: T) (OverflowError || FieldElementError)!Self {
            comptime assert(@bitSizeOf(T) <= bits); // Primitive type is larger than the modulus type.
            const v = try FeUint.fromPrimitive(T, x);
            var fe = Self{ .v = v };
            try m.shrink(&fe);
            try m.rejectNonCanonical(fe);
            return fe;
        }

        /// Converts the field element to a primitive.
        /// This function may not run in constant time.
        pub fn toPrimitive(self: Self, comptime T: type) OverflowError!T {
            return self.v.toPrimitive(T);
        }

        /// Creates a field element from a byte string.
        pub fn fromBytes(m: Modulus(bits), bytes: []const u8, comptime endian: builtin.Endian) (OverflowError || FieldElementError)!Self {
            const v = try FeUint.fromBytes(bytes, endian);
            var fe = Self{ .v = v };
            try m.shrink(&fe);
            try m.rejectNonCanonical(fe);
            return fe;
        }

        /// Converts the field element to a byte string.
        pub fn toBytes(self: Self, bytes: []u8, comptime endian: builtin.Endian) OverflowError!void {
            return self.v.toBytes(bytes, endian);
        }

        /// Returns `true` if the field elements are equal, in constant time.
        pub fn eql(x: Self, y: Self) bool {
            return x.v.eql(y.v);
        }

        /// Compares two field elements in constant time.
        pub fn compare(x: Self, y: Self) math.Order {
            return x.v.compare(y.v);
        }

        /// Returns `true` if the element is zero.
        pub fn isZero(self: Self) bool {
            return self.v.isZero();
        }

        /// Returns `true` is the element is odd.
        pub fn isOdd(self: Self) bool {
            return self.v.isOdd();
        }
    };
}

/// A modulus, defining a finite field.
/// All operations within the field are performed modulo this modulus, without heap allocations.
/// `max_bits` represents the number of bits in the maximum value the modulus can be set to.
pub fn Modulus(comptime max_bits: comptime_int) type {
    return struct {
        const Self = @This();

        /// A field element, representing a value within the field defined by this modulus.
        pub const Fe = Fe_(max_bits);

        const FeUint = Fe.FeUint;

        /// The neutral element.
        zero: Fe,

        /// The modulus value.
        v: FeUint,

        /// R^2 for the Montgomery representation.
        rr: Fe,
        /// Inverse of the first limb
        m0inv: Limb,
        /// Number of leading zero bits in the modulus.
        leading: usize,

        // Number of active limbs in the modulus.
        fn limbs_count(self: Self) usize {
            return self.v.limbs_count();
        }

        /// Actual size of the modulus, in bits.
        pub fn bits(self: Self) usize {
            return self.limbs_count() * t_bits - self.leading;
        }

        /// Returns the element `1`.
        pub fn one(self: Self) Fe {
            var fe = self.zero;
            fe.v.limbs.set(0, 1);
            return fe;
        }

        /// Creates a new modulus from a `Uint` value.
        /// The modulus must be odd and larger than 2.
        pub fn fromUint(v_: FeUint) InvalidModulusError!Self {
            if (!v_.isOdd()) return error.EvenModulus;

            var v = v_.normalize();
            const hi = v.limbs.get(v.limbs_count() - 1);
            const lo = v.limbs.get(0);

            if (v.limbs_count() < 2 and lo < 3) {
                return error.ModulusTooSmall;
            }

            const leading = @clz(hi) - carry_bits;

            var y = lo;

            inline for (0..comptime math.log2_int(usize, t_bits)) |_| {
                y = y *% (2 -% lo *% y);
            }
            const m0inv = (@as(Limb, 1) << t_bits) - (@as(TLimb, @truncate(y)));

            const zero = Fe{ .v = FeUint.zero };

            var m = Self{
                .zero = zero,
                .v = v,
                .leading = leading,
                .m0inv = m0inv,
                .rr = undefined, // will be computed right after
            };
            m.shrink(&m.zero) catch unreachable;
            computeRR(&m);

            return m;
        }

        /// Creates a new modulus from a primitive value.
        /// The modulus must be odd and larger than 2.
        pub fn fromPrimitive(comptime T: type, x: T) (InvalidModulusError || OverflowError)!Self {
            comptime assert(@bitSizeOf(T) <= max_bits); // Primitive type is larger than the modulus type.
            const v = try FeUint.fromPrimitive(T, x);
            return try Self.fromUint(v);
        }

        /// Creates a new modulus from a byte string.
        pub fn fromBytes(bytes: []const u8, comptime endian: builtin.Endian) (InvalidModulusError || OverflowError)!Self {
            const v = try FeUint.fromBytes(bytes, endian);
            return try Self.fromUint(v);
        }

        /// Serializes the modulus to a byte string.
        pub fn toBytes(self: Self, bytes: []u8, comptime endian: builtin.Endian) OverflowError!void {
            return self.v.toBytes(bytes, endian);
        }

        /// Rejects field elements that are not in the canonical form.
        pub fn rejectNonCanonical(self: Self, fe: Fe) error{NonCanonical}!void {
            if (fe.limbs_count() != self.limbs_count() or ct.limbsCmpGeq(fe.v, self.v)) {
                return error.NonCanonical;
            }
        }

        // Makes the number of active limbs in a field element match the one of the modulus.
        fn shrink(self: Self, fe: *Fe) OverflowError!void {
            const new_len = self.limbs_count();
            if (fe.limbs_count() < new_len) return error.Overflow;
            var acc: Limb = 0;
            for (fe.v.limbs.constSlice()[new_len..]) |limb| {
                acc |= limb;
            }
            if (acc != 0) return error.Overflow;
            try fe.v.limbs.resize(new_len);
        }

        // Computes R^2 for the Montgomery representation.
        fn computeRR(self: *Self) void {
            self.rr = self.zero;
            const n = self.rr.limbs_count();
            self.rr.v.limbs.set(n - 1, 1);
            for ((n - 1)..(2 * n)) |_| {
                self.shiftIn(&self.rr, 0);
            }
            self.shrink(&self.rr) catch unreachable;
        }

        /// Computes x << t_bits + y (mod m)
        fn shiftIn(self: Self, x: *Fe, y: Limb) void {
            var d = self.zero;
            const x_limbs = x.v.limbs.slice();
            const d_limbs = d.v.limbs.slice();
            const m_limbs = self.v.limbs.constSlice();

            var need_sub = false;
            var i: usize = t_bits - 1;
            while (true) : (i -= 1) {
                var carry: u1 = @truncate(math.shr(Limb, y, i));
                var borrow: u1 = 0;
                for (0..self.limbs_count()) |j| {
                    const l = ct.select(need_sub, d_limbs[j], x_limbs[j]);
                    var res = (l << 1) + carry;
                    x_limbs[j] = @as(TLimb, @truncate(res));
                    carry = @truncate(res >> t_bits);

                    res = x_limbs[j] -% m_limbs[j] -% borrow;
                    d_limbs[j] = @as(TLimb, @truncate(res));

                    borrow = @truncate(res >> t_bits);
                }
                need_sub = ct.eql(carry, borrow);
                if (i == 0) break;
            }
            x.v.cmov(need_sub, d.v);
        }

        /// Adds two field elements (mod m).
        pub fn add(self: Self, x: Fe, y: Fe) Fe {
            var out = x;
            const overflow = out.v.addWithOverflow(y.v);
            const underflow: u1 = @bitCast(ct.limbsCmpLt(out.v, self.v));
            const need_sub = ct.eql(overflow, underflow);
            _ = out.v.conditionalSubWithOverflow(need_sub, self.v);
            return out;
        }

        /// Subtracts two field elements (mod m).
        pub fn sub(self: Self, x: Fe, y: Fe) Fe {
            var out = x;
            const underflow: bool = @bitCast(out.v.subWithOverflow(y.v));
            _ = out.v.conditionalAddWithOverflow(underflow, self.v);
            return out;
        }

        /// Converts a field element to the Montgomery form.
        pub fn toMontgomery(self: Self, x: *Fe) RepresentationError!void {
            if (x.montgomery) {
                return error.UnexpectedRepresentation;
            }
            self.shrink(x) catch unreachable;
            x.* = self.montgomeryMul(x.*, self.rr);
            x.montgomery = true;
        }

        /// Takes a field element out of the Montgomery form.
        pub fn fromMontgomery(self: Self, x: *Fe) RepresentationError!void {
            if (!x.montgomery) {
                return error.UnexpectedRepresentation;
            }
            self.shrink(x) catch unreachable;
            x.* = self.montgomeryMul(x.*, self.one());
            x.montgomery = false;
        }

        /// Reduces an arbitrary `Uint`, converting it to a field element.
        pub fn reduce(self: Self, x: anytype) Fe {
            var out = self.zero;
            var i = x.limbs_count() - 1;
            if (self.limbs_count() >= 2) {
                const start = @min(i, self.limbs_count() - 2);
                var j = start;
                while (true) : (j -= 1) {
                    out.v.limbs.set(j, x.limbs.get(i));
                    i -= 1;
                    if (j == 0) break;
                }
            }
            while (true) : (i -= 1) {
                self.shiftIn(&out, x.limbs.get(i));
                if (i == 0) break;
            }
            return out;
        }

        fn montgomeryLoop(self: Self, d: *Fe, x: Fe, y: Fe) u1 {
            assert(d.limbs_count() == x.limbs_count());
            assert(d.limbs_count() == y.limbs_count());
            assert(d.limbs_count() == self.limbs_count());

            const a_limbs = x.v.limbs.constSlice();
            const b_limbs = y.v.limbs.constSlice();
            const d_limbs = d.v.limbs.slice();
            const m_limbs = self.v.limbs.constSlice();

            var overflow: u1 = 0;
            for (0..self.limbs_count()) |i| {
                var carry: Limb = 0;

                var wide = ct.mulWide(a_limbs[i], b_limbs[0]);
                var z_lo = @addWithOverflow(d_limbs[0], wide.lo);
                const f = @as(TLimb, @truncate(z_lo[0] *% self.m0inv));
                var z_hi = wide.hi +% z_lo[1];
                wide = ct.mulWide(f, m_limbs[0]);
                z_lo = @addWithOverflow(z_lo[0], wide.lo);
                z_hi +%= z_lo[1];
                z_hi +%= wide.hi;
                carry = (z_hi << 1) | (z_lo[0] >> t_bits);

                for (1..self.limbs_count()) |j| {
                    wide = ct.mulWide(a_limbs[i], b_limbs[j]);
                    z_lo = @addWithOverflow(d_limbs[j], wide.lo);
                    z_hi = wide.hi +% z_lo[1];
                    wide = ct.mulWide(f, m_limbs[j]);
                    z_lo = @addWithOverflow(z_lo[0], wide.lo);
                    z_hi +%= z_lo[1];
                    z_hi +%= wide.hi;
                    z_lo = @addWithOverflow(z_lo[0], carry);
                    z_hi +%= z_lo[1];
                    if (j > 0) {
                        d_limbs[j - 1] = @as(TLimb, @truncate(z_lo[0]));
                    }
                    carry = (z_hi << 1) | (z_lo[0] >> t_bits);
                }
                const z = overflow + carry;
                d_limbs[self.limbs_count() - 1] = @as(TLimb, @truncate(z));
                overflow = @as(u1, @truncate(z >> t_bits));
            }
            return overflow;
        }

        // Montgomery multiplication.
        fn montgomeryMul(self: Self, x: Fe, y: Fe) Fe {
            var d = self.zero;
            assert(x.limbs_count() == self.limbs_count());
            assert(y.limbs_count() == self.limbs_count());
            const overflow = self.montgomeryLoop(&d, x, y);
            const underflow = 1 -% @intFromBool(ct.limbsCmpGeq(d.v, self.v));
            const need_sub = ct.eql(overflow, underflow);
            _ = d.v.conditionalSubWithOverflow(need_sub, self.v);
            d.montgomery = x.montgomery == y.montgomery;
            return d;
        }

        // Montgomery squaring.
        fn montgomerySq(self: Self, x: Fe) Fe {
            var d = self.zero;
            assert(x.limbs_count() == self.limbs_count());
            const overflow = self.montgomeryLoop(&d, x, x);
            const underflow = 1 -% @intFromBool(ct.limbsCmpGeq(d.v, self.v));
            const need_sub = ct.eql(overflow, underflow);
            _ = d.v.conditionalSubWithOverflow(need_sub, self.v);
            d.montgomery = true;
            return d;
        }

        /// Multiplies two field elements.
        pub fn mul(self: Self, x: Fe, y: Fe) Fe {
            if (x.montgomery != y.montgomery) {
                return self.montgomeryMul(x, y);
            }
            var a_ = x;
            if (x.montgomery == false) {
                self.toMontgomery(&a_) catch unreachable;
            } else {
                self.fromMontgomery(&a_) catch unreachable;
            }
            return self.montgomeryMul(a_, y);
        }

        /// Squares a field element.
        pub fn sq(self: Self, x: Fe) Fe {
            var out = x;
            if (x.montgomery == true) {
                self.fromMontgomery(&out) catch unreachable;
            }
            out = self.montgomerySq(out);
            out.montgomery = false;
            self.toMontgomery(&out) catch unreachable;
            return out;
        }

        /// Returns x^e (mod m) in constant time.
        pub fn pow(self: Self, x: Fe, e: Fe) NullExponentError!Fe {
            var buf: [Fe.encoded_bytes]u8 = undefined;
            e.toBytes(&buf, native_endian) catch unreachable;
            return self.powWithEncodedExponent(x, &buf, native_endian);
        }

        /// Returns x^e (mod m), assuming that the exponent is public.
        /// The function remains constant time with respect to `x`.
        pub fn powPublic(self: Self, x: Fe, e: Fe) NullExponentError!Fe {
            var e_normalized = Fe{ .v = e.v.normalize() };
            var buf_: [Fe.encoded_bytes]u8 = undefined;
            var buf = buf_[0 .. math.divCeil(usize, e_normalized.v.limbs_count() * t_bits, 8) catch unreachable];
            e_normalized.toBytes(buf, .Little) catch unreachable;
            const leading = @clz(e_normalized.v.limbs.get(e_normalized.v.limbs_count() - carry_bits));
            buf = buf[0 .. buf.len - leading / 8];
            return self.powWithEncodedExponent(x, buf, .Little);
        }

        /// Returns x^e (mod m), assuming that the exponent is public, and provided as a byte string.
        /// Exponents are usually small, so this function is faster than `powPublic` as a field element
        /// doesn't have to be created if a serialized representation is already available.
        pub fn powWithEncodedExponent(self: Self, x: Fe, e: []const u8, endian: builtin.Endian) NullExponentError!Fe {
            var acc: u8 = 0;
            for (e) |b| acc |= b;
            if (acc == 0) return error.NullExponent;

            var pc = [1]Fe{x} ++ [_]Fe{self.zero} ** 14;
            if (x.montgomery == false) {
                self.toMontgomery(&pc[0]) catch unreachable;
            }
            for (1..pc.len) |i| {
                pc[i] = self.montgomeryMul(pc[i - 1], pc[0]);
            }
            var out = self.one();
            self.toMontgomery(&out) catch unreachable;
            var t0 = self.zero;
            var s = switch (endian) {
                .Big => 0,
                .Little => e.len - 1,
            };
            while (true) {
                const b = e[s];
                for ([_]u3{ 4, 0 }) |j| {
                    for (0..4) |_| {
                        out = self.montgomerySq(out);
                    }
                    const k = (b >> j) & 0b1111;
                    if (std.options.side_channels_mitigations == .none) {
                        if (k == 0) continue;
                        t0 = pc[k - 1];
                    } else {
                        for (pc, 0..) |t, i| {
                            t0.v.cmov(ct.eql(k, @as(u8, @truncate(i + 1))), t.v);
                        }
                    }
                    const t1 = self.montgomeryMul(out, t0);
                    out.v.cmov(!ct.eql(k, 0), t1.v);
                }
                switch (endian) {
                    .Big => {
                        s += 1;
                        if (s == e.len) break;
                    },
                    .Little => {
                        if (s == 0) break;
                        s -= 1;
                    },
                }
            }
            self.fromMontgomery(&out) catch unreachable;
            return out;
        }
    };
}

const ct = if (std.options.side_channels_mitigations == .none) ct_unprotected else ct_protected;

const ct_protected = struct {
    // Returns x if on is true, otherwise y.
    fn select(on: bool, x: Limb, y: Limb) Limb {
        const mask = @as(Limb, 0) -% @intFromBool(on);
        return y ^ (mask & (y ^ x));
    }

    // Compares two values in constant time.
    fn eql(x: anytype, y: @TypeOf(x)) bool {
        const c1 = @subWithOverflow(x, y)[1];
        const c2 = @subWithOverflow(y, x)[1];
        return @as(bool, @bitCast(1 - (c1 | c2)));
    }

    // Compares two big integers in constant time, returning true if x < y.
    fn limbsCmpLt(x: anytype, y: @TypeOf(x)) bool {
        assert(x.limbs_count() == y.limbs_count());
        const x_limbs = x.limbs.constSlice();
        const y_limbs = y.limbs.constSlice();

        var c: u1 = 0;
        for (0..x.limbs_count()) |i| {
            c = @as(u1, @truncate((x_limbs[i] -% y_limbs[i] -% c) >> t_bits));
        }
        return @as(bool, @bitCast(c));
    }

    // Compares two big integers in constant time, returning true if x >= y.
    fn limbsCmpGeq(x: anytype, y: @TypeOf(x)) bool {
        return @as(bool, @bitCast(1 - @intFromBool(ct.limbsCmpLt(x, y))));
    }

    // Multiplies two limbs and returns the result as a wide limb.
    fn mulWide(x: Limb, y: Limb) WideLimb {
        const half_bits = @typeInfo(Limb).Int.bits / 2;
        const Half = meta.Int(.unsigned, half_bits);
        const x0 = @as(Half, @truncate(x));
        const x1 = @as(Half, @truncate(x >> half_bits));
        const y0 = @as(Half, @truncate(y));
        const y1 = @as(Half, @truncate(y >> half_bits));
        const w0 = math.mulWide(Half, x0, y0);
        const t = math.mulWide(Half, x1, y0) + (w0 >> half_bits);
        var w1: Limb = @as(Half, @truncate(t));
        const w2 = @as(Half, @truncate(t >> half_bits));
        w1 += math.mulWide(Half, x0, y1);
        const hi = math.mulWide(Half, x1, y1) + w2 + (w1 >> half_bits);
        const lo = x *% y;
        return .{ .hi = hi, .lo = lo };
    }
};

const ct_unprotected = struct {
    // Returns x if on is true, otherwise y.
    fn select(on: bool, x: Limb, y: Limb) Limb {
        return if (on) x else y;
    }

    // Compares two values in constant time.
    fn eql(x: anytype, y: @TypeOf(x)) bool {
        return x == y;
    }

    // Compares two big integers in constant time, returning true if x < y.
    fn limbsCmpLt(x: anytype, y: @TypeOf(x)) bool {
        assert(x.limbs_count() == y.limbs_count());
        const x_limbs = x.limbs.constSlice();
        const y_limbs = y.limbs.constSlice();

        var i = x.limbs_count();
        while (i != 0) {
            i -= 1;
            if (x_limbs[i] != y_limbs[i]) {
                return x_limbs[i] < y_limbs[i];
            }
        }
        return false;
    }

    // Compares two big integers in constant time, returning true if x >= y.
    fn limbsCmpGeq(x: anytype, y: @TypeOf(x)) bool {
        return !ct.limbsCmpLt(x, y);
    }

    // Multiplies two limbs and returns the result as a wide limb.
    fn mulWide(x: Limb, y: Limb) WideLimb {
        const wide = math.mulWide(Limb, x, y);
        return .{
            .hi = @as(Limb, @truncate(wide >> @typeInfo(Limb).Int.bits)),
            .lo = @as(Limb, @truncate(wide)),
        };
    }
};

test {
    if (@import("builtin").zig_backend == .stage2_c) return error.SkipZigTest;

    const M = Modulus(256);
    const m = try M.fromPrimitive(u256, 3429938563481314093726330772853735541133072814650493833233);
    var x = try M.Fe.fromPrimitive(u256, m, 80169837251094269539116136208111827396136208141182357733);
    var y = try M.Fe.fromPrimitive(u256, m, 24620149608466364616251608466389896540098571);

    const x_ = try x.toPrimitive(u256);
    try testing.expect((try M.Fe.fromPrimitive(@TypeOf(x_), m, x_)).eql(x));
    try testing.expectError(error.Overflow, x.toPrimitive(u50));

    const bits = m.bits();
    try testing.expectEqual(bits, 192);

    var x_y = m.mul(x, y);
    try testing.expectEqual(x_y.toPrimitive(u256), 1666576607955767413750776202132407807424848069716933450241);

    try m.toMontgomery(&x);
    x_y = m.mul(x, y);
    try testing.expectEqual(x_y.toPrimitive(u256), 1666576607955767413750776202132407807424848069716933450241);
    try m.fromMontgomery(&x);

    x = m.add(x, y);
    try testing.expectEqual(x.toPrimitive(u256), 80169837251118889688724602572728079004602598037722456304);
    x = m.sub(x, y);
    try testing.expectEqual(x.toPrimitive(u256), 80169837251094269539116136208111827396136208141182357733);

    const big = try Uint(512).fromPrimitive(u495, 77285373554113307281465049383342993856348131409372633077285373554113307281465049383323332333429938563481314093726330772853735541133072814650493833233);
    const reduced = m.reduce(big);
    try testing.expectEqual(reduced.toPrimitive(u495), 858047099884257670294681641776170038885500210968322054970);

    const x_pow_y = try m.powPublic(x, y);
    try testing.expectEqual(x_pow_y.toPrimitive(u256), 1631933139300737762906024873185789093007782131928298618473);
    try m.toMontgomery(&x);
    const x_pow_y2 = try m.powPublic(x, y);
    try m.fromMontgomery(&x);
    try testing.expect(x_pow_y2.eql(x_pow_y));
    try testing.expectError(error.NullExponent, m.powPublic(x, m.zero));

    try testing.expect(!x.isZero());
    try testing.expect(!y.isZero());
    try testing.expect(m.v.isOdd());

    const x_sq = m.sq(x);
    const x_sq2 = m.mul(x, x);
    try testing.expect(x_sq.eql(x_sq2));
    try m.toMontgomery(&x);
    const x_sq3 = m.sq(x);
    const x_sq4 = m.mul(x, x);
    try testing.expect(x_sq.eql(x_sq3));
    try testing.expect(x_sq3.eql(x_sq4));
    try m.fromMontgomery(&x);
}
