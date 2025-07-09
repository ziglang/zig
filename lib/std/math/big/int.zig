const std = @import("../../std.zig");
const builtin = @import("builtin");
const math = std.math;
const Limb = std.math.big.Limb;
const limb_bits = @typeInfo(Limb).int.bits;
const HalfLimb = std.math.big.HalfLimb;
const half_limb_bits = @typeInfo(HalfLimb).int.bits;
const DoubleLimb = std.math.big.DoubleLimb;
const SignedDoubleLimb = std.math.big.SignedDoubleLimb;
const Log2Limb = std.math.big.Log2Limb;
const Allocator = std.mem.Allocator;
const mem = std.mem;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;
const assert = std.debug.assert;
const Endian = std.builtin.Endian;
const Signedness = std.builtin.Signedness;
const native_endian = builtin.cpu.arch.endian();

// values based only on a few tests, could probably be adjusted
// it may also depend on the cpu
const recursive_division_threshold = 100;
const karatsuba_threshold = 40;
// TODO: better number
const tostring_subquadratic_threshold = 12;

// Comptime-computed constants for supported bases (2 - 36)
// all values are set to 0 for bases 0 - 1, to make it possible to
// access a constant for a given base b using `constants.value[b]`
const Constants = struct {
    // big_bases[b] is the biggest power of b that fit in a single Limb
    // i.e. big_bases[b] = b^k < 2^@bitSizeOf(Limb) and b^(k+1) >= 2^@bitSizeOf(Limb)
    big_bases: [37]Limb,
    // digits_per_limb[b] is the value of k used in the previous field
    digits_per_limb: [37]u8,
};
const constants: Constants = blk: {
    @setEvalBranchQuota(2000);
    var digits_per_limb = [_]u8{0} ** 37;
    var bases = [_]Limb{0} ** 37;
    for (2..37) |base| {
        digits_per_limb[base] = @intCast(math.log(Limb, base, math.maxInt(Limb)));
        bases[base] = std.math.pow(Limb, base, digits_per_limb[base]);
    }
    break :blk Constants{ .big_bases = bases, .digits_per_limb = digits_per_limb };
};

/// Returns the number of limbs needed to store `scalar`, which must be a
/// primitive integer or float value.
/// Note: A comptime-known upper bound of this value that may be used
/// instead if `scalar` is not already comptime-known is
/// `calcTwosCompLimbCount(@typeInfo(@TypeOf(scalar)).int.bits)`
pub fn calcLimbLen(scalar: anytype) usize {
    switch (@typeInfo(@TypeOf(scalar))) {
        .int, .comptime_int => {
            if (scalar == 0) return 1;
            const w_value = @abs(scalar);
            return @as(usize, @intCast(@divFloor(@as(Limb, @intCast(math.log2(w_value))), limb_bits) + 1));
        },
        .float => {
            const repr: std.math.FloatRepr(@TypeOf(scalar)) = @bitCast(scalar);
            return switch (repr.exponent) {
                .denormal => 1,
                else => return calcNonZeroTwosCompLimbCount(@as(usize, 2) + @max(repr.exponent.unbias(), 0)),
                .infinite => 0,
            };
        },
        .comptime_float => return calcLimbLen(@as(f128, scalar)),
        else => @compileError("expected float or int, got " ++ @typeName(@TypeOf(scalar))),
    }
}

pub fn calcToStringLimbsBufferLen(a_len: usize, base: u8) usize {
    if (math.isPowerOfTwo(base))
        return 0;
    return a_len + 2 + a_len + calcDivLimbsBufferLen(a_len, 1);
}

pub fn calcDivLimbsBufferLen(a_len: usize, b_len: usize) usize {
    return a_len + b_len + 4;
}

pub fn calcMulLimbsBufferLen(a_len: usize, b_len: usize, aliases: usize) usize {
    return aliases * @max(a_len, b_len);
}

pub fn calcMulWrapLimbsBufferLen(bit_count: usize, a_len: usize, b_len: usize, aliases: usize) usize {
    const req_limbs = calcTwosCompLimbCount(bit_count);
    return aliases * @min(req_limbs, @max(a_len, b_len));
}

pub fn calcSetStringLimbsBufferLen(base: u8, string_len: usize) usize {
    const limb_count = calcSetStringLimbCount(base, string_len);
    return calcMulLimbsBufferLen(limb_count, limb_count, 2);
}

/// Assumes `string_len` doesn't account for minus signs if the number is negative.
pub fn calcSetStringLimbCount(base: u8, string_len: usize) usize {
    const base_f: f32 = @floatFromInt(base);
    const string_len_f: f32 = @floatFromInt(string_len);
    return 1 + @as(usize, @intFromFloat(@ceil(string_len_f * std.math.log2(base_f) / limb_bits)));
}

pub fn calcPowLimbsBufferLen(a_bit_count: usize, y: usize) usize {
    // The 2 accounts for the minimum space requirement for llmulacc
    return 2 + (a_bit_count * y + (limb_bits - 1)) / limb_bits;
}

pub fn calcSqrtLimbsBufferLen(a_bit_count: usize) usize {
    const a_limb_count = (a_bit_count - 1) / limb_bits + 1;
    const shift = (a_bit_count + 1) / 2;
    const u_s_rem_limb_count = 1 + ((shift / limb_bits) + 1);
    return a_limb_count + 3 * u_s_rem_limb_count + calcDivLimbsBufferLen(a_limb_count, u_s_rem_limb_count);
}

/// Compute the number of limbs required to store a 2s-complement number of `bit_count` bits.
pub fn calcNonZeroTwosCompLimbCount(bit_count: usize) usize {
    assert(bit_count != 0);
    return calcTwosCompLimbCount(bit_count);
}

/// Compute the number of limbs required to store a 2s-complement number of `bit_count` bits.
///
/// Special cases `bit_count == 0` to return 1. Zero-bit integers can only store the value zero
/// and this big integer implementation stores zero using one limb.
pub fn calcTwosCompLimbCount(bit_count: usize) usize {
    return @max(std.math.divCeil(usize, bit_count, @bitSizeOf(Limb)) catch unreachable, 1);
}

/// Computes the number of limbs required to store the quotient of the division `a` / `b`
/// `a` and `b` must be normalized.
/// if `a` is zero, than `a_len` must be 1
/// The result is either correct or one more than needed.
///
/// Note that we always have `calcDivQLen(a.len, b.len) >= calcDivQLenExact(a, b)`
pub fn calcDivQLen(a_len: usize, b_len: usize) usize {
    assert(a_len >= b_len);
    assert(b_len >= 1);
    return a_len - b_len + 1;
}

/// Computes the number of limbs required to store the quotient of the division `a` / `b`
/// `a` and `b` must be normalized, and `b` must be non-zero
pub fn calcDivQLenExact(a: []const Limb, b: []const Limb) usize {
    assert(a.len >= b.len);
    assert(b.len >= 1);
    assert(!(b.len == 1 and b[0] == 0)); // b must be non-zero

    const need_one_more = llcmp(a[a.len - b.len ..], b).compare(.gte);
    const needed_len = a.len - b.len + @intFromBool(need_one_more);
    return @max(needed_len, 1);
}

/// a + b * c + *carry, sets carry to the overflow bits
pub fn addMulLimbWithCarry(a: Limb, b: Limb, c: Limb, carry: *Limb) Limb {
    // ov1[0] = a + *carry
    const ov1 = @addWithOverflow(a, carry.*);

    // r2 = b * c
    const bc = @as(DoubleLimb, math.mulWide(Limb, b, c));
    const r2 = @as(Limb, @truncate(bc));
    const c2 = @as(Limb, @truncate(bc >> limb_bits));

    // ov2[0] = ov1[0] + r2
    const ov2 = @addWithOverflow(ov1[0], r2);

    // This never overflows, c1, c3 are either 0 or 1 and if both are 1 then
    // c2 is at least <= maxInt(Limb) - 2.
    carry.* = ov1[1] + c2 + ov2[1];

    return ov2[0];
}

/// a - b * c - *carry, sets carry to the overflow bits
fn subMulLimbWithBorrow(a: Limb, b: Limb, c: Limb, carry: *Limb) Limb {
    // ov1[0] = a - *carry
    const ov1 = @subWithOverflow(a, carry.*);

    // r2 = b * c
    const bc = @as(DoubleLimb, std.math.mulWide(Limb, b, c));
    const r2 = @as(Limb, @truncate(bc));
    const c2 = @as(Limb, @truncate(bc >> limb_bits));

    // ov2[0] = ov1[0] - r2
    const ov2 = @subWithOverflow(ov1[0], r2);
    carry.* = ov1[1] + c2 + ov2[1];

    return ov2[0];
}

/// Used to indicate either limit of a 2s-complement integer.
pub const TwosCompIntLimit = enum {
    // The low limit, either 0x00 (unsigned) or (-)0x80 (signed) for an 8-bit integer.
    min,

    // The high limit, either 0xFF (unsigned) or 0x7F (signed) for an 8-bit integer.
    max,
};

pub const Round = enum {
    /// Round to the nearest representable value, with ties broken by the representation
    /// that ends with a 0 bit.
    nearest_even,
    /// Round away from zero.
    away,
    /// Round towards zero.
    trunc,
    /// Round towards negative infinity.
    floor,
    /// Round towards positive infinity.
    ceil,
};

pub const Exactness = enum { inexact, exact };

/// A arbitrary-precision big integer, with a fixed set of mutable limbs.
pub const Mutable = struct {
    /// Raw digits. These are:
    ///
    /// * Little-endian ordered
    /// * limbs.len >= 1
    /// * Zero is represented as limbs.len == 1 with limbs[0] == 0.
    ///
    /// Accessing limbs directly should be avoided.
    /// These are allocated limbs; the `len` field tells the valid range.
    limbs: []Limb,
    len: usize,
    positive: bool,

    pub fn toConst(self: Mutable) Const {
        return .{
            .limbs = self.limbs[0..self.len],
            .positive = self.positive,
        };
    }

    pub const ConvertError = Const.ConvertError;

    /// Convert `self` to `Int`.
    ///
    /// Returns an error if self cannot be narrowed into the requested type without truncation.
    pub fn toInt(self: Mutable, comptime Int: type) ConvertError!Int {
        return self.toConst().toInt(Int);
    }

    /// Convert `self` to `Float`.
    pub fn toFloat(self: Mutable, comptime Float: type, round: Round) struct { Float, Exactness } {
        return self.toConst().toFloat(Float, round);
    }

    /// Returns true if `a == 0`.
    pub fn eqlZero(self: Mutable) bool {
        return self.toConst().eqlZero();
    }

    /// Asserts that the allocator owns the limbs memory. If this is not the case,
    /// use `toConst().toManaged()`.
    pub fn toManaged(self: Mutable, allocator: Allocator) Managed {
        return .{
            .allocator = allocator,
            .limbs = self.limbs,
            .metadata = if (self.positive)
                self.len & ~Managed.sign_bit
            else
                self.len | Managed.sign_bit,
        };
    }

    /// `value` is a primitive integer type.
    /// Asserts the value fits within the provided `limbs_buffer`.
    /// Note: `calcLimbLen` can be used to figure out how big an array to allocate for `limbs_buffer`.
    pub fn init(limbs_buffer: []Limb, value: anytype) Mutable {
        limbs_buffer[0] = 0;
        var self: Mutable = .{
            .limbs = limbs_buffer,
            .len = 1,
            .positive = true,
        };
        self.set(value);
        return self;
    }

    /// Copies the value of a Const to an existing Mutable so that they both have the same value.
    /// Asserts the value fits in the limbs buffer.
    pub fn copy(self: *Mutable, other: Const) void {
        if (self.limbs.ptr != other.limbs.ptr) {
            @memcpy(self.limbs[0..other.limbs.len], other.limbs[0..other.limbs.len]);
        }
        // Normalize before setting `positive` so the `eqlZero` doesn't need to iterate
        // over the extra zero limbs.
        self.normalize(other.limbs.len);
        self.positive = other.positive or other.eqlZero();
    }

    /// Efficiently swap an Mutable with another. This swaps the limb pointers and a full copy is not
    /// performed. The address of the limbs field will not be the same after this function.
    pub fn swap(self: *Mutable, other: *Mutable) void {
        mem.swap(Mutable, self, other);
    }

    pub fn dump(self: Mutable) void {
        for (self.limbs[0..self.len]) |limb| {
            std.debug.print("{x} ", .{limb});
        }
        std.debug.print("len={} capacity={} positive={}\n", .{ self.len, self.limbs.len, self.positive });
    }

    /// Clones an Mutable and returns a new Mutable with the same value. The new Mutable is a deep copy and
    /// can be modified separately from the original.
    /// Asserts that limbs is big enough to store the value.
    pub fn clone(other: Mutable, limbs: []Limb) Mutable {
        @memcpy(limbs[0..other.len], other.limbs[0..other.len]);
        return .{
            .limbs = limbs,
            .len = other.len,
            .positive = other.positive,
        };
    }

    pub fn negate(self: *Mutable) void {
        self.positive = !self.positive;
    }

    /// Modify to become the absolute value
    pub fn abs(self: *Mutable) void {
        self.positive = true;
    }

    /// Sets the Mutable to value. Value must be an primitive integer type.
    /// Asserts the value fits within the limbs buffer.
    /// Note: `calcLimbLen` can be used to figure out how big the limbs buffer
    /// needs to be to store a specific value.
    pub fn set(self: *Mutable, value: anytype) void {
        const T = @TypeOf(value);
        const needed_limbs = calcLimbLen(value);
        assert(needed_limbs <= self.limbs.len); // value too big

        self.len = needed_limbs;
        self.positive = value >= 0;

        switch (@typeInfo(T)) {
            .int => |info| {
                var w_value = @abs(value);

                if (info.bits <= limb_bits) {
                    self.limbs[0] = w_value;
                } else {
                    var i: usize = 0;
                    while (true) : (i += 1) {
                        self.limbs[i] = @as(Limb, @truncate(w_value));
                        w_value >>= limb_bits;

                        if (w_value == 0) break;
                    }
                }
            },
            .comptime_int => {
                comptime var w_value = @abs(value);

                if (w_value <= maxInt(Limb)) {
                    self.limbs[0] = w_value;
                } else {
                    const mask = (1 << limb_bits) - 1;

                    comptime var i = 0;
                    inline while (true) : (i += 1) {
                        self.limbs[i] = w_value & mask;
                        w_value >>= limb_bits;

                        if (w_value == 0) break;
                    }
                }
            },
            else => @compileError("cannot set Mutable using type " ++ @typeName(T)),
        }
    }

    /// Set self from the string representation `value`.
    ///
    /// `value` must contain only digits <= `base` and is case insensitive.  Base prefixes are
    /// not allowed (e.g. 0x43 should simply be 43).  Underscores in the input string are
    /// ignored and can be used as digit separators.
    ///
    /// There must be enough memory for the value in `self.limbs`. An upper bound on number of limbs can
    /// be determined with `calcSetStringLimbCount`.
    /// Asserts the base is in the range [2, 36].
    ///
    /// Returns an error if the value has invalid digits for the requested base.
    pub fn setString(
        self: *Mutable,
        base: u8,
        value: []const u8,
    ) error{InvalidCharacter}!void {
        assert(base >= 2);
        assert(base <= 36);

        var i: usize = 0;
        var positive = true;
        if (value.len > 0 and value[0] == '-') {
            positive = false;
            i += 1;
        }

        @memset(self.limbs, 0);
        self.len = 1;

        var limb: Limb = 0;
        var j: usize = 0;
        for (value[i..]) |ch| {
            if (ch == '_') {
                continue;
            }
            const d = try std.fmt.charToDigit(ch, base);
            limb *= base;
            limb += d;
            j += 1;

            if (j == constants.digits_per_limb[base]) {
                const len = @min(self.len + 1, self.limbs.len);
                // r = a * b = a + a * (b - 1)
                // we assert to panic if the self.limbs is not large enough to store the number
                assert(!llmulLimb(.add, self.limbs[0..len], self.limbs[0..len], constants.big_bases[base] - 1));
                assert(!llaccum(.add, self.limbs[0..len], &[1]Limb{limb}));

                if (self.limbs.len > self.len and self.limbs[self.len] != 0)
                    self.len += 1;
                j = 0;
                limb = 0;
            }
        }
        if (j > 0) {
            const len = @min(self.len + 1, self.limbs.len);
            // we assert to panic if the self.limbs is not large enough to store the number
            assert(!llmulLimb(.add, self.limbs[0..len], self.limbs[0..len], math.pow(Limb, base, j) - 1));
            assert(!llaccum(.add, self.limbs[0..len], &[1]Limb{limb}));

            if (self.limbs.len > self.len and self.limbs[self.len] != 0)
                self.len += 1;
        }
        self.positive = positive;
    }

    /// Set self to either bound of a 2s-complement integer.
    /// Note: The result is still sign-magnitude, not twos complement! In order to convert the
    /// result to twos complement, it is sufficient to take the absolute value.
    ///
    /// Asserts the result fits in `r`. An upper bound on the number of limbs needed by
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn setTwosCompIntLimit(
        r: *Mutable,
        limit: TwosCompIntLimit,
        signedness: Signedness,
        bit_count: usize,
    ) void {
        // Handle zero-bit types.
        if (bit_count == 0) {
            r.set(0);
            return;
        }

        const req_limbs = calcTwosCompLimbCount(bit_count);
        const bit: Log2Limb = @truncate(bit_count - 1);
        const signmask = @as(Limb, 1) << bit; // 0b0..010..0 where 1 is the sign bit.
        const mask = (signmask << 1) -% 1; // 0b0..011..1 where the leftmost 1 is the sign bit.

        r.positive = true;

        switch (signedness) {
            .signed => switch (limit) {
                .min => {
                    // Negative bound, signed = -0x80.
                    r.len = req_limbs;
                    @memset(r.limbs[0 .. r.len - 1], 0);
                    r.limbs[r.len - 1] = signmask;
                    r.positive = false;
                },
                .max => {
                    // Positive bound, signed = 0x7F
                    // Note, in this branch we need to normalize because the first bit is
                    // supposed to be 0.

                    // Special case for 1-bit integers.
                    if (bit_count == 1) {
                        r.set(0);
                    } else {
                        const new_req_limbs = calcTwosCompLimbCount(bit_count - 1);
                        const msb = @as(Log2Limb, @truncate(bit_count - 2));
                        const new_signmask = @as(Limb, 1) << msb; // 0b0..010..0 where 1 is the sign bit.
                        const new_mask = (new_signmask << 1) -% 1; // 0b0..001..1 where the rightmost 0 is the sign bit.

                        r.len = new_req_limbs;
                        @memset(r.limbs[0 .. r.len - 1], maxInt(Limb));
                        r.limbs[r.len - 1] = new_mask;
                    }
                },
            },
            .unsigned => switch (limit) {
                .min => {
                    // Min bound, unsigned = 0x00
                    r.set(0);
                },
                .max => {
                    // Max bound, unsigned = 0xFF
                    r.len = req_limbs;
                    @memset(r.limbs[0 .. r.len - 1], maxInt(Limb));
                    r.limbs[r.len - 1] = mask;
                },
            },
        }
    }

    /// Sets the Mutable to a float value rounded according to `round`.
    /// Returns whether the conversion was exact (`round` had no effect on the result).
    pub fn setFloat(self: *Mutable, value: anytype, round: Round) Exactness {
        const Float = @TypeOf(value);
        if (Float == comptime_float) return self.setFloat(@as(f128, value), round);
        const abs_value = @abs(value);
        if (abs_value < 1.0) {
            if (abs_value == 0.0) {
                self.set(0);
                return .exact;
            }
            self.set(@as(i2, round: switch (round) {
                .nearest_even => if (abs_value <= 0.5) 0 else continue :round .away,
                .away => if (value < 0.0) -1 else 1,
                .trunc => 0,
                .floor => -@as(i2, @intFromBool(value < 0.0)),
                .ceil => @intFromBool(value > 0.0),
            }));
            return .inexact;
        }
        const Repr = std.math.FloatRepr(Float);
        const repr: Repr = @bitCast(value);
        const exponent = repr.exponent.unbias();
        assert(exponent >= 0);
        const int_bit: Repr.Mantissa = 1 << (@bitSizeOf(Repr.Mantissa) - 1);
        const mantissa = int_bit | repr.mantissa;
        if (exponent >= @bitSizeOf(Repr.Normalized.Fraction)) {
            self.set(mantissa);
            self.shiftLeft(self.toConst(), @intCast(exponent - @bitSizeOf(Repr.Normalized.Fraction)));
            self.positive = repr.sign == .positive;
            return .exact;
        }
        self.set(mantissa >> @intCast(@bitSizeOf(Repr.Normalized.Fraction) - exponent));
        const round_bits: Repr.Normalized.Fraction = @truncate(mantissa << @intCast(exponent));
        if (round_bits == 0) {
            self.positive = repr.sign == .positive;
            return .exact;
        }
        round: switch (round) {
            .nearest_even => {
                const half: Repr.Normalized.Fraction = 1 << (@bitSizeOf(Repr.Normalized.Fraction) - 1);
                if (round_bits >= half) self.addScalar(self.toConst(), 1);
                if (round_bits == half) self.limbs[0] &= ~@as(Limb, 1);
            },
            .away => self.addScalar(self.toConst(), 1),
            .trunc => {},
            .floor => switch (repr.sign) {
                .positive => {},
                .negative => continue :round .away,
            },
            .ceil => switch (repr.sign) {
                .positive => continue :round .away,
                .negative => {},
            },
        }
        self.positive = repr.sign == .positive;
        return .inexact;
    }

    /// r = a + scalar
    ///
    /// r and a may be aliases.
    /// scalar is a primitive integer type.
    ///
    /// Asserts the result fits in `r`. An upper bound on the number of limbs needed by
    /// r is `@max(a.limbs.len, calcLimbLen(scalar)) + 1`.
    pub fn addScalar(r: *Mutable, a: Const, scalar: anytype) void {
        // Normally we could just determine the number of limbs needed with calcLimbLen,
        // but that is not comptime-known when scalar is not a comptime_int.  Instead, we
        // use calcTwosCompLimbCount for a non-comptime_int scalar, which can be pessimistic
        // in the case that scalar happens to be small in magnitude within its type, but it
        // is well worth being able to use the stack and not needing an allocator passed in.
        // Note that Mutable.init still sets len to calcLimbLen(scalar) in any case.
        const limbs_len = comptime switch (@typeInfo(@TypeOf(scalar))) {
            .comptime_int => calcLimbLen(scalar),
            .int => |info| calcTwosCompLimbCount(info.bits),
            else => @compileError("expected scalar to be an int"),
        };
        var limbs: [limbs_len]Limb = undefined;
        const operand = init(&limbs, scalar).toConst();
        return add(r, a, operand);
    }

    /// Base implementation for addition. Adds `@max(a.limbs.len, b.limbs.len)` elements from a and b,
    /// and returns whether any overflow occurred.
    /// r, a and b may be aliases.
    ///
    /// Asserts r has enough elements to hold the result. The upper bound is `@max(a.limbs.len, b.limbs.len)`.
    fn addCarry(r: *Mutable, a: Const, b: Const) bool {
        if (a.eqlZero()) {
            r.copy(b);
            return false;
        } else if (b.eqlZero()) {
            r.copy(a);
            return false;
        } else if (a.positive != b.positive) {
            if (a.positive) {
                // (a) + (-b) => a - b
                return r.subCarry(a, b.abs());
            } else {
                // (-a) + (b) => b - a
                return r.subCarry(b, a.abs());
            }
        } else {
            r.positive = a.positive;
            if (a.limbs.len >= b.limbs.len) {
                const c = lladdcarry(r.limbs, a.limbs, b.limbs);
                r.normalize(a.limbs.len);
                return c != 0;
            } else {
                const c = lladdcarry(r.limbs, b.limbs, a.limbs);
                r.normalize(b.limbs.len);
                return c != 0;
            }
        }
    }

    /// r = a + b
    ///
    /// r, a and b may be aliases.
    ///
    /// Asserts the result fits in `r`. An upper bound on the number of limbs needed by
    /// r is `@max(a.limbs.len, b.limbs.len) + 1`.
    pub fn add(r: *Mutable, a: Const, b: Const) void {
        if (r.addCarry(a, b)) {
            // Fix up the result. Note that addCarry normalizes by a.limbs.len or b.limbs.len,
            // so we need to set the length here.
            const msl = @max(a.limbs.len, b.limbs.len);
            // `[add|sub]Carry` normalizes by `msl`, so we need to fix up the result manually here.
            // Note, the fact that it normalized means that the intermediary limbs are zero here.
            r.len = msl + 1;
            r.limbs[msl] = 1; // If this panics, there wasn't enough space in `r`.
        }
    }

    /// r = a + b with 2s-complement wrapping semantics. Returns whether overflow occurred.
    /// r, a and b may be aliases
    ///
    /// Asserts the result fits in `r`. An upper bound on the number of limbs needed by
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn addWrap(r: *Mutable, a: Const, b: Const, signedness: Signedness, bit_count: usize) bool {
        const req_limbs = calcTwosCompLimbCount(bit_count);

        // Slice of the upper bits if they exist, these will be ignored and allows us to use addCarry to determine
        // if an overflow occurred.
        const x = Const{
            .positive = a.positive,
            .limbs = a.limbs[0..@min(req_limbs, a.limbs.len)],
        };

        const y = Const{
            .positive = b.positive,
            .limbs = b.limbs[0..@min(req_limbs, b.limbs.len)],
        };

        var carry_truncated = false;
        if (r.addCarry(x, y)) {
            // There are two possibilities here:
            // - We overflowed req_limbs. In this case, the carry is ignored, as it would be removed by
            //   truncate anyway.
            // - a and b had less elements than req_limbs, and those were overflowed. This case needs to be handled.
            //   Note: after this we still might need to wrap.
            const msl = @max(a.limbs.len, b.limbs.len);
            if (msl < req_limbs) {
                r.limbs[msl] = 1;
                r.len = req_limbs;
                @memset(r.limbs[msl + 1 .. req_limbs], 0);
            } else {
                carry_truncated = true;
            }
        }

        if (!r.toConst().fitsInTwosComp(signedness, bit_count)) {
            r.truncate(r.toConst(), signedness, bit_count);
            return true;
        }

        return carry_truncated;
    }

    /// r = a + b with 2s-complement saturating semantics.
    /// r, a and b may be aliases.
    ///
    /// Assets the result fits in `r`. Upper bound on the number of limbs needed by
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn addSat(r: *Mutable, a: Const, b: Const, signedness: Signedness, bit_count: usize) void {
        const req_limbs = calcTwosCompLimbCount(bit_count);

        // Slice of the upper bits if they exist, these will be ignored and allows us to use addCarry to determine
        // if an overflow occurred.
        const x = Const{
            .positive = a.positive,
            .limbs = a.limbs[0..@min(req_limbs, a.limbs.len)],
        };

        const y = Const{
            .positive = b.positive,
            .limbs = b.limbs[0..@min(req_limbs, b.limbs.len)],
        };

        if (r.addCarry(x, y)) {
            // There are two possibilities here:
            // - We overflowed req_limbs, in which case we need to saturate.
            // - a and b had less elements than req_limbs, and those were overflowed.
            //   Note: In this case, might _also_ need to saturate.
            const msl = @max(a.limbs.len, b.limbs.len);
            if (msl < req_limbs) {
                r.limbs[msl] = 1;
                r.len = req_limbs;
                // Note: Saturation may still be required if msl == req_limbs - 1
            } else {
                // Overflowed req_limbs, definitely saturate.
                r.setTwosCompIntLimit(if (r.positive) .max else .min, signedness, bit_count);
            }
        }

        // Saturate if the result didn't fit.
        r.saturate(r.toConst(), signedness, bit_count);
    }

    /// Base implementation for subtraction. Subtracts `@max(a.limbs.len, b.limbs.len)` elements from a and b,
    /// and returns whether any overflow occurred.
    /// r, a and b may be aliases.
    ///
    /// Asserts r has enough elements to hold the result. The upper bound is `@max(a.limbs.len, b.limbs.len)`.
    fn subCarry(r: *Mutable, a: Const, b: Const) bool {
        if (a.eqlZero()) {
            r.copy(b);
            r.positive = !b.positive;
            return false;
        } else if (b.eqlZero()) {
            r.copy(a);
            return false;
        } else if (a.positive != b.positive) {
            if (a.positive) {
                // (a) - (-b) => a + b
                return r.addCarry(a, b.abs());
            } else {
                // (-a) - (b) => -a + -b
                return r.addCarry(a, b.negate());
            }
        } else if (a.positive) {
            if (a.order(b) != .lt) {
                // (a) - (b) => a - b
                const c = llsubcarry(r.limbs, a.limbs, b.limbs);
                r.normalize(a.limbs.len);
                r.positive = true;
                return c != 0;
            } else {
                // (a) - (b) => -b + a => -(b - a)
                const c = llsubcarry(r.limbs, b.limbs, a.limbs);
                r.normalize(b.limbs.len);
                r.positive = false;
                return c != 0;
            }
        } else {
            if (a.order(b) == .lt) {
                // (-a) - (-b) => -(a - b)
                const c = llsubcarry(r.limbs, a.limbs, b.limbs);
                r.normalize(a.limbs.len);
                r.positive = false;
                return c != 0;
            } else {
                // (-a) - (-b) => --b + -a => b - a
                const c = llsubcarry(r.limbs, b.limbs, a.limbs);
                r.normalize(b.limbs.len);
                r.positive = true;
                return c != 0;
            }
        }
    }

    /// r = a - b
    ///
    /// r, a and b may be aliases.
    ///
    /// Asserts the result fits in `r`. An upper bound on the number of limbs needed by
    /// r is `@max(a.limbs.len, b.limbs.len) + 1`. The +1 is not needed if both operands are positive.
    pub fn sub(r: *Mutable, a: Const, b: Const) void {
        r.add(a, b.negate());
    }

    /// r = a - b with 2s-complement wrapping semantics. Returns whether any overflow occurred.
    ///
    /// r, a and b may be aliases
    /// Asserts the result fits in `r`. An upper bound on the number of limbs needed by
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn subWrap(r: *Mutable, a: Const, b: Const, signedness: Signedness, bit_count: usize) bool {
        return r.addWrap(a, b.negate(), signedness, bit_count);
    }

    /// r = a - b with 2s-complement saturating semantics.
    /// r, a and b may be aliases.
    ///
    /// Assets the result fits in `r`. Upper bound on the number of limbs needed by
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn subSat(r: *Mutable, a: Const, b: Const, signedness: Signedness, bit_count: usize) void {
        r.addSat(a, b.negate(), signedness, bit_count);
    }

    /// rma = a * b
    ///
    /// `rma` may alias with `a` or `b`.
    /// `a` and `b` may alias with each other.
    ///
    /// Asserts the result fits in `rma`. An upper bound on the number of limbs needed by
    /// rma is given by `a.limbs.len + b.limbs.len`.
    ///
    /// `limbs_buffer` is used for temporary storage. The amount required is given by `calcMulLimbsBufferLen`.
    pub fn mul(rma: *Mutable, a: Const, b: Const, limbs_buffer: []Limb, allocator: ?Allocator) void {
        var buf_index: usize = 0;

        const a_copy = if (rma.limbs.ptr == a.limbs.ptr) blk: {
            const start = buf_index;
            @memcpy(limbs_buffer[buf_index..][0..a.limbs.len], a.limbs);
            buf_index += a.limbs.len;
            break :blk a.toMutable(limbs_buffer[start..buf_index]).toConst();
        } else a;

        const b_copy = if (rma.limbs.ptr == b.limbs.ptr) blk: {
            const start = buf_index;
            @memcpy(limbs_buffer[buf_index..][0..b.limbs.len], b.limbs);
            buf_index += b.limbs.len;
            break :blk b.toMutable(limbs_buffer[start..buf_index]).toConst();
        } else b;

        return rma.mulNoAlias(a_copy, b_copy, allocator);
    }

    /// rma = a * b
    ///
    /// `rma` may not alias with `a` or `b`.
    /// `a` and `b` may alias with each other.
    ///
    /// Asserts the result fits in `rma`. An upper bound on the number of limbs needed by
    /// rma is given by `a.limbs.len + b.limbs.len`.
    ///
    /// If `allocator` is provided, it will be used for temporary storage to improve
    /// multiplication performance. `error.OutOfMemory` is handled with a fallback algorithm.
    pub fn mulNoAlias(rma: *Mutable, a: Const, b: Const, allocator: ?Allocator) void {
        assert(rma.limbs.ptr != a.limbs.ptr); // illegal aliasing
        assert(rma.limbs.ptr != b.limbs.ptr); // illegal aliasing

        if (a.limbs.len == 1 and b.limbs.len == 1) {
            const ov = @mulWithOverflow(a.limbs[0], b.limbs[0]);
            rma.limbs[0] = ov[0];
            if (ov[1] == 0) {
                rma.len = 1;
                rma.positive = (a.positive == b.positive);
                return;
            }
        }

        @memset(rma.limbs[0 .. a.limbs.len + b.limbs.len], 0);

        _ = llmulacc(.add, allocator, rma.limbs, a.limbs, b.limbs);

        rma.normalize(a.limbs.len + b.limbs.len);
        rma.positive = (a.positive == b.positive);
    }

    /// rma = a * b with 2s-complement wrapping semantics.
    ///
    /// `rma` may alias with `a` or `b`.
    /// `a` and `b` may alias with each other.
    ///
    /// Asserts the result fits in `rma`. An upper bound on the number of limbs needed by
    /// rma is given by `a.limbs.len + b.limbs.len`.
    ///
    /// `limbs_buffer` is used for temporary storage. The amount required is given by `calcMulWrapLimbsBufferLen`.
    pub fn mulWrap(
        rma: *Mutable,
        a: Const,
        b: Const,
        signedness: Signedness,
        bit_count: usize,
        limbs_buffer: []Limb,
        allocator: ?Allocator,
    ) void {
        var buf_index: usize = 0;
        const req_limbs = calcTwosCompLimbCount(bit_count);

        const a_copy = if (rma.limbs.ptr == a.limbs.ptr) blk: {
            const start = buf_index;
            const a_len = @min(req_limbs, a.limbs.len);
            @memcpy(limbs_buffer[buf_index..][0..a_len], a.limbs[0..a_len]);
            buf_index += a_len;
            break :blk a.toMutable(limbs_buffer[start..buf_index]).toConst();
        } else a;

        const b_copy = if (rma.limbs.ptr == b.limbs.ptr) blk: {
            const start = buf_index;
            const b_len = @min(req_limbs, b.limbs.len);
            @memcpy(limbs_buffer[buf_index..][0..b_len], b.limbs[0..b_len]);
            buf_index += b_len;
            break :blk a.toMutable(limbs_buffer[start..buf_index]).toConst();
        } else b;

        return rma.mulWrapNoAlias(a_copy, b_copy, signedness, bit_count, allocator);
    }

    /// rma = a * b with 2s-complement wrapping semantics.
    ///
    /// `rma` may not alias with `a` or `b`.
    /// `a` and `b` may alias with each other.
    ///
    /// Asserts the result fits in `rma`. An upper bound on the number of limbs needed by
    /// rma is given by `a.limbs.len + b.limbs.len`.
    ///
    /// If `allocator` is provided, it will be used for temporary storage to improve
    /// multiplication performance. `error.OutOfMemory` is handled with a fallback algorithm.
    pub fn mulWrapNoAlias(
        rma: *Mutable,
        a: Const,
        b: Const,
        signedness: Signedness,
        bit_count: usize,
        allocator: ?Allocator,
    ) void {
        assert(rma.limbs.ptr != a.limbs.ptr); // illegal aliasing
        assert(rma.limbs.ptr != b.limbs.ptr); // illegal aliasing

        const req_limbs = calcTwosCompLimbCount(bit_count);

        // We can ignore the upper bits here, those results will be discarded anyway.
        const a_limbs = a.limbs[0..@min(req_limbs, a.limbs.len)];
        const b_limbs = b.limbs[0..@min(req_limbs, b.limbs.len)];

        @memset(rma.limbs[0..req_limbs], 0);

        _ = llmulacc(.add, allocator, rma.limbs[0..req_limbs], a_limbs, b_limbs);
        rma.normalize(@min(req_limbs, a.limbs.len + b.limbs.len));
        rma.positive = (a.positive == b.positive);
        rma.truncate(rma.toConst(), signedness, bit_count);
    }

    /// r = @bitReverse(a) with 2s-complement semantics.
    /// r and a may be aliases.
    ///
    /// Asserts the result fits in `r`. Upper bound on the number of limbs needed by
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn bitReverse(r: *Mutable, a: Const, signedness: Signedness, bit_count: usize) void {
        if (bit_count == 0) return;

        r.copy(a);

        const limbs_required = calcTwosCompLimbCount(bit_count);

        if (!a.positive) {
            r.positive = true; // Negate.
            r.bitNotWrap(r.toConst(), .unsigned, bit_count); // Bitwise NOT.
            r.addScalar(r.toConst(), 1); // Add one.
        } else if (limbs_required > a.limbs.len) {
            // Zero-extend to our output length
            for (r.limbs[a.limbs.len..limbs_required]) |*limb| {
                limb.* = 0;
            }
            r.len = limbs_required;
        }

        // 0b0..01..1000 with @log2(@sizeOf(Limb)) consecutive ones
        const endian_mask: usize = (@sizeOf(Limb) - 1) << 3;

        const bytes = std.mem.sliceAsBytes(r.limbs);

        var k: usize = 0;
        while (k < ((bit_count + 1) / 2)) : (k += 1) {
            var i = k;
            var rev_i = bit_count - i - 1;

            // This "endian mask" remaps a low (LE) byte to the corresponding high
            // (BE) byte in the Limb, without changing which limbs we are indexing
            if (native_endian == .big) {
                i ^= endian_mask;
                rev_i ^= endian_mask;
            }

            const bit_i = std.mem.readPackedInt(u1, bytes, i, .little);
            const bit_rev_i = std.mem.readPackedInt(u1, bytes, rev_i, .little);
            std.mem.writePackedInt(u1, bytes, i, bit_rev_i, .little);
            std.mem.writePackedInt(u1, bytes, rev_i, bit_i, .little);
        }

        // Calculate signed-magnitude representation for output
        if (signedness == .signed) {
            const last_bit = switch (native_endian) {
                .little => std.mem.readPackedInt(u1, bytes, bit_count - 1, .little),
                .big => std.mem.readPackedInt(u1, bytes, (bit_count - 1) ^ endian_mask, .little),
            };
            if (last_bit == 1) {
                r.bitNotWrap(r.toConst(), .unsigned, bit_count); // Bitwise NOT.
                r.addScalar(r.toConst(), 1); // Add one.
                r.positive = false; // Negate.
            }
        }
        r.normalize(r.len);
    }

    /// r = @byteSwap(a) with 2s-complement semantics.
    /// r and a may be aliases.
    ///
    /// Asserts the result fits in `r`. Upper bound on the number of limbs needed by
    /// r is `calcTwosCompLimbCount(8*byte_count)`.
    pub fn byteSwap(r: *Mutable, a: Const, signedness: Signedness, byte_count: usize) void {
        if (byte_count == 0) return;

        r.copy(a);
        const limbs_required = calcTwosCompLimbCount(8 * byte_count);

        if (!a.positive) {
            r.positive = true; // Negate.
            r.bitNotWrap(r.toConst(), .unsigned, 8 * byte_count); // Bitwise NOT.
            r.addScalar(r.toConst(), 1); // Add one.
        } else if (limbs_required > a.limbs.len) {
            // Zero-extend to our output length
            for (r.limbs[a.limbs.len..limbs_required]) |*limb| {
                limb.* = 0;
            }
            r.len = limbs_required;
        }

        // 0b0..01..1 with @log2(@sizeOf(Limb)) trailing ones
        const endian_mask: usize = @sizeOf(Limb) - 1;

        var bytes = std.mem.sliceAsBytes(r.limbs);
        assert(bytes.len >= byte_count);

        var k: usize = 0;
        while (k < (byte_count + 1) / 2) : (k += 1) {
            var i = k;
            var rev_i = byte_count - k - 1;

            // This "endian mask" remaps a low (LE) byte to the corresponding high
            // (BE) byte in the Limb, without changing which limbs we are indexing
            if (native_endian == .big) {
                i ^= endian_mask;
                rev_i ^= endian_mask;
            }

            const byte_i = bytes[i];
            const byte_rev_i = bytes[rev_i];
            bytes[rev_i] = byte_i;
            bytes[i] = byte_rev_i;
        }

        // Calculate signed-magnitude representation for output
        if (signedness == .signed) {
            const last_byte = switch (native_endian) {
                .little => bytes[byte_count - 1],
                .big => bytes[(byte_count - 1) ^ endian_mask],
            };

            if (last_byte & (1 << 7) != 0) { // Check sign bit of last byte
                r.bitNotWrap(r.toConst(), .unsigned, 8 * byte_count); // Bitwise NOT.
                r.addScalar(r.toConst(), 1); // Add one.
                r.positive = false; // Negate.
            }
        }
        r.normalize(r.len);
    }

    /// r = @popCount(a) with 2s-complement semantics.
    /// r and a may be aliases.
    ///
    /// Assets the result fits in `r`. Upper bound on the number of limbs needed by
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn popCount(r: *Mutable, a: Const, bit_count: usize) void {
        r.copy(a);

        if (!a.positive) {
            r.positive = true; // Negate.
            r.bitNotWrap(r.toConst(), .unsigned, bit_count); // Bitwise NOT.
            r.addScalar(r.toConst(), 1); // Add one.
        }

        var sum: Limb = 0;
        for (r.limbs[0..r.len]) |limb| {
            sum += @popCount(limb);
        }
        r.set(sum);
    }

    /// rma = a * a
    ///
    /// `rma` may not alias with `a`.
    ///
    /// Asserts the result fits in `rma`. An upper bound on the number of limbs needed by
    /// rma is given by `2 * a.limbs.len + 1`.
    ///
    /// If `allocator` is provided, it will be used for temporary storage to improve
    /// multiplication performance. `error.OutOfMemory` is handled with a fallback algorithm.
    pub fn sqrNoAlias(rma: *Mutable, a: Const, opt_allocator: ?Allocator) void {
        _ = opt_allocator;
        assert(rma.limbs.ptr != a.limbs.ptr); // illegal aliasing

        @memset(rma.limbs, 0);

        llsquareBasecase(rma.limbs, a.limbs);

        rma.normalize(2 * a.limbs.len + 1);
        rma.positive = true;
    }

    /// q = a / b (rem r)
    ///
    /// a / b are floored (rounded towards 0).
    /// q may alias with a or b.
    ///
    /// Asserts there is enough memory to store q and r.
    /// The upper bound for r limb count is `b.limbs.len`.
    /// The upper bound for q limb count is given by `a.limbs`.
    ///
    /// `limbs_buffer` is used for temporary storage. The amount required is given by `calcDivLimbsBufferLen`.
    pub fn divFloor(q: *Mutable, r: *Mutable, a: Const, b: Const, limbs_buffer: []Limb, opt_allocator: ?Allocator) void {
        const sep = a.limbs.len + 2;
        const x = a.toMutable(limbs_buffer[0..sep]);
        const y = b.toMutable(limbs_buffer[sep..]);

        div(q, r, x, y, opt_allocator);

        // Note, `div` performs truncating division, which satisfies
        // @divTrunc(a, b) * b + @rem(a, b) = a
        // so r = a - @divTrunc(a, b) * b
        // Note,  @rem(a, -b) = @rem(-b, a) = -@rem(a, b) = -@rem(-a, -b)
        // For divTrunc, we want to perform
        // @divFloor(a, b) * b + @mod(a, b) = a
        // Note:
        // @divFloor(-a, b)
        // = @divFloor(a, -b)
        // = -@divCeil(a, b)
        // = -@divFloor(a + b - 1, b)
        // = -@divTrunc(a + b - 1, b)

        // Note (1):
        // @divTrunc(a + b - 1, b) * b + @rem(a + b - 1, b) = a + b - 1
        // = @divTrunc(a + b - 1, b) * b + @rem(a - 1, b) = a + b - 1
        // = @divTrunc(a + b - 1, b) * b + @rem(a - 1, b) - b + 1 = a

        if (a.positive and b.positive) {
            // Positive-positive case, don't need to do anything.
        } else if (a.positive and !b.positive) {
            // a/-b -> q is negative, and so we need to fix flooring.
            // Subtract one to make the division flooring.

            // @divFloor(a, -b) * -b + @mod(a, -b) = a
            // If b divides a exactly, we have @divFloor(a, -b) * -b = a
            // Else, we have @divFloor(a, -b) * -b > a, so @mod(a, -b) becomes negative

            // We have:
            // @divFloor(a, -b) * -b + @mod(a, -b) = a
            // = -@divTrunc(a + b - 1, b) * -b + @mod(a, -b) = a
            // = @divTrunc(a + b - 1, b) * b + @mod(a, -b) = a

            // Substitute a for (1):
            // @divTrunc(a + b - 1, b) * b + @rem(a - 1, b) - b + 1 = @divTrunc(a + b - 1, b) * b + @mod(a, -b)
            // Yields:
            // @mod(a, -b) = @rem(a - 1, b) - b + 1
            // Note that `r` holds @rem(a, b) at this point.
            //
            // If @rem(a, b) is not 0:
            //   @rem(a - 1, b) = @rem(a, b) - 1
            //   => @mod(a, -b) = @rem(a, b) - 1 - b + 1 = @rem(a, b) - b
            // Else:
            //   @rem(a - 1, b) = @rem(a + b - 1, b) = @rem(b - 1, b) = b - 1
            //   => @mod(a, -b) = b - 1 - b + 1 = 0
            if (!r.eqlZero()) {
                q.addScalar(q.toConst(), -1);
                r.positive = true;
                r.sub(r.toConst(), y.toConst().abs());
            }
        } else if (!a.positive and b.positive) {
            // -a/b -> q is negative, and so we need to fix flooring.
            // Subtract one to make the division flooring.

            // @divFloor(-a, b) * b + @mod(-a, b) = a
            // If b divides a exactly, we have @divFloor(-a, b) * b = -a
            // Else, we have @divFloor(-a, b) * b < -a, so @mod(-a, b) becomes positive

            // We have:
            // @divFloor(-a, b) * b + @mod(-a, b) = -a
            // = -@divTrunc(a + b - 1, b) * b + @mod(-a, b) = -a
            // = @divTrunc(a + b - 1, b) * b - @mod(-a, b) = a

            // Substitute a for (1):
            // @divTrunc(a + b - 1, b) * b + @rem(a - 1, b) - b + 1 = @divTrunc(a + b - 1, b) * b - @mod(-a, b)
            // Yields:
            // @rem(a - 1, b) - b + 1 = -@mod(-a, b)
            // => -@mod(-a, b) = @rem(a - 1, b) - b + 1
            // => @mod(-a, b) = -(@rem(a - 1, b) - b + 1) = -@rem(a - 1, b) + b - 1
            //
            // If @rem(a, b) is not 0:
            //   @rem(a - 1, b) = @rem(a, b) - 1
            //   => @mod(-a, b) = -(@rem(a, b) - 1) + b - 1 = -@rem(a, b) + 1 + b - 1 = -@rem(a, b) + b
            // Else :
            //   @rem(a - 1, b) = b - 1
            //   => @mod(-a, b) = -(b - 1) + b - 1 = 0
            if (!r.eqlZero()) {
                q.addScalar(q.toConst(), -1);
                r.positive = false;
                r.add(r.toConst(), y.toConst().abs());
            }
        } else if (!a.positive and !b.positive) {
            // a/b -> q is positive, don't need to do anything to fix flooring.

            // @divFloor(-a, -b) * -b + @mod(-a, -b) = -a
            // If b divides a exactly, we have @divFloor(-a, -b) * -b = -a
            // Else, we have @divFloor(-a, -b) * -b > -a, so @mod(-a, -b) becomes negative

            // We have:
            // @divFloor(-a, -b) * -b + @mod(-a, -b) = -a
            // = @divTrunc(a, b) * -b + @mod(-a, -b) = -a
            // = @divTrunc(a, b) * b - @mod(-a, -b) = a

            // We also have:
            // @divTrunc(a, b) * b + @rem(a, b) = a

            // Substitute a:
            // @divTrunc(a, b) * b + @rem(a, b) = @divTrunc(a, b) * b - @mod(-a, -b)
            // => @rem(a, b) = -@mod(-a, -b)
            // => @mod(-a, -b) = -@rem(a, b)
            r.positive = false;
        }
    }

    /// q = a / b (rem r)
    ///
    /// a / b are truncated (rounded towards -inf).
    /// q may alias with a or b.
    ///
    /// Asserts there is enough memory to store q and r.
    /// The upper bound for r limb count is `b.limbs.len`.
    /// The upper bound for q limb count is given by `a.limbs.len`.
    ///
    /// `limbs_buffer` is used for temporary storage. The amount required is given by `calcDivLimbsBufferLen`.
    pub fn divTrunc(q: *Mutable, r: *Mutable, a: Const, b: Const, limbs_buffer: []Limb, opt_allocator: ?Allocator) void {
        const sep = a.limbs.len + 2;
        const x = a.toMutable(limbs_buffer[0..sep]);
        const y = b.toMutable(limbs_buffer[sep..]);

        div(q, r, x, y, opt_allocator);
    }

    /// r = a << shift, in other words, r = a * 2^shift
    ///
    /// r and a may alias.
    ///
    /// Asserts there is enough memory to fit the result. The upper bound Limb count is
    /// `a.limbs.len + (shift / (@sizeOf(Limb) * 8))`.
    pub fn shiftLeft(r: *Mutable, a: Const, shift: usize) void {
        const new_len = llshl(r.limbs, a.limbs, shift);
        r.normalize(new_len);
        r.positive = a.positive;
    }

    /// r = a <<| shift with 2s-complement saturating semantics.
    ///
    /// r and a may alias.
    ///
    /// Asserts there is enough memory to fit the result. The upper bound Limb count is
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn shiftLeftSat(r: *Mutable, a: Const, shift: usize, signedness: Signedness, bit_count: usize) void {
        // Special case: When the argument is negative, but the result is supposed to be unsigned,
        // return 0 in all cases.
        if (!a.positive and signedness == .unsigned) {
            r.set(0);
            return;
        }

        // Check whether the shift is going to overflow. This is the case
        // when (in 2s complement) any bit above `bit_count - shift` is set in the unshifted value.
        // Note, the sign bit is not counted here.

        // Handle shifts larger than the target type. This also deals with
        // 0-bit integers.
        if (bit_count <= shift) {
            // In this case, there is only no overflow if `a` is zero.
            if (a.eqlZero()) {
                r.set(0);
            } else {
                r.setTwosCompIntLimit(if (a.positive) .max else .min, signedness, bit_count);
            }
            return;
        }

        const checkbit = bit_count - shift - @intFromBool(signedness == .signed);
        // If `checkbit` and more significant bits are zero, no overflow will take place.

        if (checkbit >= a.limbs.len * limb_bits) {
            // `checkbit` is outside the range of a, so definitely no overflow will take place. We
            // can defer to a normal shift.
            // Note that if `a` is normalized (which we assume), this checks for set bits in the upper limbs.

            // Note, in this case r should already have enough limbs required to perform the normal shift.
            // In this case the shift of the most significant limb may still overflow.
            r.shiftLeft(a, shift);
            return;
        } else if (checkbit < (a.limbs.len - 1) * limb_bits) {
            // `checkbit` is not in the most significant limb. If `a` is normalized the most significant
            // limb will not be zero, so in this case we need to saturate. Note that `a.limbs.len` must be
            // at least one according to normalization rules.

            r.setTwosCompIntLimit(if (a.positive) .max else .min, signedness, bit_count);
            return;
        }

        // Generate a mask with the bits to check in the most significant limb. We'll need to check
        // all bits with equal or more significance than checkbit.
        // const msb = @truncate(Log2Limb, checkbit);
        // const checkmask = (@as(Limb, 1) << msb) -% 1;

        if (a.limbs[a.limbs.len - 1] >> @as(Log2Limb, @truncate(checkbit)) != 0) {
            // Need to saturate.
            r.setTwosCompIntLimit(if (a.positive) .max else .min, signedness, bit_count);
            return;
        }

        // This shift should not be able to overflow, so invoke llshl and normalize manually
        // to avoid the extra required limb.
        const new_len = llshl(r.limbs, a.limbs, shift);
        r.normalize(new_len);
        r.positive = a.positive;
    }

    /// r = a >> shift
    /// r and a may alias.
    ///
    /// Asserts there is enough memory to fit the result. The upper bound Limb count is
    /// `a.limbs.len - (shift / (@bitSizeOf(Limb)))`.
    pub fn shiftRight(r: *Mutable, a: Const, shift: usize) void {
        const full_limbs_shifted_out = shift / limb_bits;
        const remaining_bits_shifted_out = shift % limb_bits;
        if (a.limbs.len <= full_limbs_shifted_out) {
            // Shifting negative numbers converges to -1 instead of 0
            if (a.positive) {
                r.len = 1;
                r.positive = true;
                r.limbs[0] = 0;
            } else {
                r.len = 1;
                r.positive = false;
                r.limbs[0] = 1;
            }
            return;
        }
        const nonzero_negative_shiftout = if (a.positive) false else nonzero: {
            for (a.limbs[0..full_limbs_shifted_out]) |x| {
                if (x != 0)
                    break :nonzero true;
            }
            if (remaining_bits_shifted_out == 0)
                break :nonzero false;
            const not_covered: Log2Limb = @intCast(limb_bits - remaining_bits_shifted_out);
            break :nonzero a.limbs[full_limbs_shifted_out] << not_covered != 0;
        };

        const new_len = llshr(r.limbs, a.limbs, shift);

        r.len = new_len;
        r.positive = a.positive;
        if (nonzero_negative_shiftout) r.addScalar(r.toConst(), -1);
        r.normalize(r.len);
    }

    /// r = ~a under 2s complement wrapping semantics.
    /// r may alias with a.
    ///
    /// Assets that r has enough limbs to store the result. The upper bound Limb count is
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn bitNotWrap(r: *Mutable, a: Const, signedness: Signedness, bit_count: usize) void {
        r.copy(a.negate());
        const negative_one = Const{ .limbs = &.{1}, .positive = false };
        _ = r.addWrap(r.toConst(), negative_one, signedness, bit_count);
    }

    /// r = a | b under 2s complement semantics.
    /// r may alias with a or b.
    ///
    /// a and b are zero-extended to the longer of a or b.
    ///
    /// Asserts that r has enough limbs to store the result. Upper bound is `@max(a.limbs.len, b.limbs.len)`.
    pub fn bitOr(r: *Mutable, a: Const, b: Const) void {
        // Trivial cases, llsignedor does not support zero.
        if (a.eqlZero()) {
            r.copy(b);
            return;
        } else if (b.eqlZero()) {
            r.copy(a);
            return;
        }

        if (a.limbs.len >= b.limbs.len) {
            r.positive = llsignedor(r.limbs, a.limbs, a.positive, b.limbs, b.positive);
            r.normalize(if (b.positive) a.limbs.len else b.limbs.len);
        } else {
            r.positive = llsignedor(r.limbs, b.limbs, b.positive, a.limbs, a.positive);
            r.normalize(if (a.positive) b.limbs.len else a.limbs.len);
        }
    }

    /// r = a & b under 2s complement semantics.
    /// r may alias with a or b.
    ///
    /// Asserts that r has enough limbs to store the result.
    /// If only a is positive, the upper bound is `a.limbs.len`.
    /// If only b is positive, the upper bound is `b.limbs.len`.
    /// If a and b are positive, the upper bound is `@min(a.limbs.len, b.limbs.len)`.
    /// If a and b are negative, the upper bound is `@max(a.limbs.len, b.limbs.len) + 1`.
    pub fn bitAnd(r: *Mutable, a: Const, b: Const) void {
        // Trivial cases, llsignedand does not support zero.
        if (a.eqlZero()) {
            r.copy(a);
            return;
        } else if (b.eqlZero()) {
            r.copy(b);
            return;
        }

        if (a.limbs.len >= b.limbs.len) {
            r.positive = llsignedand(r.limbs, a.limbs, a.positive, b.limbs, b.positive);
            r.normalize(if (b.positive) b.limbs.len else if (a.positive) a.limbs.len else a.limbs.len + 1);
        } else {
            r.positive = llsignedand(r.limbs, b.limbs, b.positive, a.limbs, a.positive);
            r.normalize(if (a.positive) a.limbs.len else if (b.positive) b.limbs.len else b.limbs.len + 1);
        }
    }

    /// r = a ^ b under 2s complement semantics.
    /// r may alias with a or b.
    ///
    /// Asserts that r has enough limbs to store the result. If a and b share the same signedness, the
    /// upper bound is `@max(a.limbs.len, b.limbs.len)`. Otherwise, if either a or b is negative
    /// but not both, the upper bound is `@max(a.limbs.len, b.limbs.len) + 1`.
    pub fn bitXor(r: *Mutable, a: Const, b: Const) void {
        // Trivial cases, because llsignedxor does not support negative zero.
        if (a.eqlZero()) {
            r.copy(b);
            return;
        } else if (b.eqlZero()) {
            r.copy(a);
            return;
        }

        if (a.limbs.len > b.limbs.len) {
            r.positive = llsignedxor(r.limbs, a.limbs, a.positive, b.limbs, b.positive);
            r.normalize(a.limbs.len + @intFromBool(a.positive != b.positive));
        } else {
            r.positive = llsignedxor(r.limbs, b.limbs, b.positive, a.limbs, a.positive);
            r.normalize(b.limbs.len + @intFromBool(a.positive != b.positive));
        }
    }

    /// rma may alias x or y.
    /// x and y may alias each other.
    /// Asserts that `rma` has enough limbs to store the result. Upper bound is
    /// `@min(x.limbs.len, y.limbs.len)`.
    ///
    /// `limbs_buffer` is used for temporary storage during the operation. When this function returns,
    /// it will have the same length as it had when the function was called.
    pub fn gcd(rma: *Mutable, x: Const, y: Const, limbs_buffer: *std.ArrayList(Limb)) !void {
        const prev_len = limbs_buffer.items.len;
        defer limbs_buffer.shrinkRetainingCapacity(prev_len);
        const x_copy = if (rma.limbs.ptr == x.limbs.ptr) blk: {
            const start = limbs_buffer.items.len;
            try limbs_buffer.appendSlice(x.limbs);
            break :blk x.toMutable(limbs_buffer.items[start..]).toConst();
        } else x;
        const y_copy = if (rma.limbs.ptr == y.limbs.ptr) blk: {
            const start = limbs_buffer.items.len;
            try limbs_buffer.appendSlice(y.limbs);
            break :blk y.toMutable(limbs_buffer.items[start..]).toConst();
        } else y;

        return gcdLehmer(rma, x_copy, y_copy, limbs_buffer);
    }

    /// q = a ^ b
    ///
    /// r may not alias a.
    ///
    /// Asserts that `r` has enough limbs to store the result. Upper bound is
    /// `calcPowLimbsBufferLen(a.bitCountAbs(), b)`.
    ///
    /// `limbs_buffer` is used for temporary storage.
    /// The amount required is given by `calcPowLimbsBufferLen`.
    pub fn pow(r: *Mutable, a: Const, b: u32, limbs_buffer: []Limb) void {
        assert(r.limbs.ptr != a.limbs.ptr); // illegal aliasing

        // Handle all the trivial cases first
        switch (b) {
            0 => {
                // a^0 = 1
                return r.set(1);
            },
            1 => {
                // a^1 = a
                return r.copy(a);
            },
            else => {},
        }

        if (a.eqlZero()) {
            // 0^b = 0
            return r.set(0);
        } else if (a.limbs.len == 1 and a.limbs[0] == 1) {
            // 1^b = 1 and -1^b = ±1
            r.set(1);
            r.positive = a.positive or (b & 1) == 0;
            return;
        }

        // Here a>1 and b>1
        const needed_limbs = calcPowLimbsBufferLen(a.bitCountAbs(), b);
        assert(r.limbs.len >= needed_limbs);
        assert(limbs_buffer.len >= needed_limbs);

        llpow(r.limbs, a.limbs, b, limbs_buffer);

        r.normalize(needed_limbs);
        r.positive = a.positive or (b & 1) == 0;
    }

    /// r = ⌊√a⌋
    ///
    /// r may alias a.
    ///
    /// Asserts that `r` has enough limbs to store the result. Upper bound is
    /// `(a.limbs.len - 1) / 2 + 1`.
    ///
    /// `limbs_buffer` is used for temporary storage.
    /// The amount required is given by `calcSqrtLimbsBufferLen`.
    pub fn sqrt(
        r: *Mutable,
        a: Const,
        limbs_buffer: []Limb,
    ) void {
        // Brent and Zimmermann, Modern Computer Arithmetic, Algorithm 1.13 SqrtInt
        // https://members.loria.fr/PZimmermann/mca/pub226.html
        var buf_index: usize = 0;
        var t = b: {
            const start = buf_index;
            buf_index += a.limbs.len;
            break :b Mutable.init(limbs_buffer[start..buf_index], 0);
        };
        var u = b: {
            const start = buf_index;
            const shift = (a.bitCountAbs() + 1) / 2;
            buf_index += 1 + ((shift / limb_bits) + 1);
            var m = Mutable.init(limbs_buffer[start..buf_index], 1);
            m.shiftLeft(m.toConst(), shift); // u must be >= ⌊√a⌋, and should be as small as possible for efficiency
            break :b m;
        };
        var s = b: {
            const start = buf_index;
            buf_index += u.limbs.len;
            break :b u.toConst().toMutable(limbs_buffer[start..buf_index]);
        };
        var rem = b: {
            const start = buf_index;
            buf_index += s.limbs.len;
            break :b Mutable.init(limbs_buffer[start..buf_index], 0);
        };

        while (true) {
            // TODO: pass an allocator or remove the need for it in the division
            t.divFloor(&rem, a, s.toConst(), limbs_buffer[buf_index..], null);
            t.add(t.toConst(), s.toConst());
            u.shiftRight(t.toConst(), 1);

            if (u.toConst().order(s.toConst()).compare(.gte)) {
                r.copy(s.toConst());
                return;
            }

            // Avoid copying u to s by swapping u and s
            const tmp_s = s;
            s = u;
            u = tmp_s;
        }
    }

    /// rma may not alias x or y.
    /// x and y may alias each other.
    /// Asserts that `rma` has enough limbs to store the result. Upper bound is given by `calcGcdNoAliasLimbLen`.
    ///
    /// `limbs_buffer` is used for temporary storage during the operation.
    pub fn gcdNoAlias(rma: *Mutable, x: Const, y: Const, limbs_buffer: *std.ArrayList(Limb)) !void {
        assert(rma.limbs.ptr != x.limbs.ptr); // illegal aliasing
        assert(rma.limbs.ptr != y.limbs.ptr); // illegal aliasing
        return gcdLehmer(rma, x, y, limbs_buffer);
    }

    fn gcdLehmer(result: *Mutable, xa: Const, ya: Const, limbs_buffer: *std.ArrayList(Limb)) !void {
        var x = try xa.toManaged(limbs_buffer.allocator);
        defer x.deinit();
        x.abs();

        var y = try ya.toManaged(limbs_buffer.allocator);
        defer y.deinit();
        y.abs();

        if (x.toConst().order(y.toConst()) == .lt) {
            x.swap(&y);
        }

        var t_big = try Managed.init(limbs_buffer.allocator);
        defer t_big.deinit();

        var r = try Managed.init(limbs_buffer.allocator);
        defer r.deinit();

        var tmp_x = try Managed.init(limbs_buffer.allocator);
        defer tmp_x.deinit();

        while (y.len() > 1 and !y.eqlZero()) {
            assert(x.isPositive() and y.isPositive());
            assert(x.len() >= y.len());

            var xh: SignedDoubleLimb = x.limbs[x.len() - 1];
            var yh: SignedDoubleLimb = if (x.len() > y.len()) 0 else y.limbs[x.len() - 1];

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
                // t_big = x % y, r is unused
                try r.divTrunc(&t_big, &x, &y);
                assert(t_big.isPositive());

                x.swap(&y);
                y.swap(&t_big);
            } else {
                var storage: [8]Limb = undefined;
                const Ap = fixedIntFromSignedDoubleLimb(A, storage[0..2]).toManaged(limbs_buffer.allocator);
                const Bp = fixedIntFromSignedDoubleLimb(B, storage[2..4]).toManaged(limbs_buffer.allocator);
                const Cp = fixedIntFromSignedDoubleLimb(C, storage[4..6]).toManaged(limbs_buffer.allocator);
                const Dp = fixedIntFromSignedDoubleLimb(D, storage[6..8]).toManaged(limbs_buffer.allocator);

                // t_big = Ax + By
                try r.mul(&x, &Ap);
                try t_big.mul(&y, &Bp);
                try t_big.add(&r, &t_big);

                // u = Cx + Dy, r as u
                try tmp_x.copy(x.toConst());
                try x.mul(&tmp_x, &Cp);
                try r.mul(&y, &Dp);
                try r.add(&x, &r);

                x.swap(&t_big);
                y.swap(&r);
            }
        }

        // euclidean algorithm
        assert(x.toConst().order(y.toConst()) != .lt);

        while (!y.toConst().eqlZero()) {
            try t_big.divTrunc(&r, &x, &y);
            x.swap(&y);
            y.swap(&r);
        }

        result.copy(x.toConst());
    }

    // Truncates by default.
    // Requires no aliasing between all variables
    // a must have the capacity to store a one limb shift
    fn div(q: *Mutable, r: *Mutable, a: Mutable, b: Mutable, opt_allocator: ?Allocator) void {
        if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
            assert(!b.eqlZero()); // division by zero
            assert(q != r); // illegal aliasing
            assert(r.limbs.len >= b.len);
            assert(!slicesOverlap(q.limbs, a.limbs));
        }

        const q_positive = (a.positive == b.positive);
        const r_positive = a.positive;

        const order = a.toConst().orderAbs(b.toConst());
        if (order == .lt) {
            r.copy(a.toConst());
            r.positive = r_positive;

            q.set(0);
            return;
        }
        if (order == .eq) {
            @branchHint(.unlikely);

            r.set(0);
            q.set(1);
            q.positive = q_positive;

            return;
        }

        // normalize `b`
        const norm_shift = @clz(b.limbs[b.len - 1]);
        const a_len = a.len + @intFromBool(norm_shift > @clz(a.limbs[a.len - 1]));

        // a must have the capacity to store the left shift
        const a_limbs = a.limbs[0..a_len];
        const b_limbs = b.limbs[0..b.len];

        // note, in theory, `b` doesn't need to be allocated by the caller since it is untouched at the end,
        // but `divFloor` and `divTrunc` take a `Const` so we can't shift `b` in place
        _ = llshl(a_limbs, a.limbs[0..a.len], norm_shift);
        _ = llshl(b_limbs, b_limbs, norm_shift);
        defer _ = llshr(b.limbs, b.limbs[0..b.len], norm_shift);

        if (b.len == 1)
            a_limbs[0] = lldiv1(q.limbs, a_limbs, b_limbs[0])
        else if (a_len == 2) {
            assert(q.limbs.len >= 1);
            // TODO: better algo without computing the reciprocal ?
            const reciprocal = reciprocalWord3by2(b_limbs[1], b_limbs[0]);
            const result = div3by2(0, a_limbs[1], a_limbs[0], b.limbs[1], b.limbs[0], reciprocal);

            q.limbs[0] = result.q;
            // result.r[0] is the high part of r and result.r[1] its low part
            a_limbs[1] = result.r[0];
            a_limbs[0] = result.r[1];
        } else {
            // Currently, an allocator is required to use karatsuba.
            // Recursive division is only faster than the basecase division thanks to better
            // multiplication algorithms. Without them, it is worse due to overhead, so we just
            // default to the basecase
            if (opt_allocator) |allocator| {
                // if `B.limbs.len` < `recursive_division_threshold`, the recursiveDivRem calls from unbalancedDivision
                // will always immediatly default to basecaseDivRem, so just using the basecase is faster
                if (b_limbs.len < recursive_division_threshold)
                    basecaseDivRem(q.limbs, a_limbs, b_limbs)
                else
                    unbalancedDivision(q.limbs, a_limbs, b_limbs, allocator);
            } else {
                basecaseDivRem(q.limbs, a_limbs, b_limbs);
            }
        }

        // we have r < b, so there is at most b.len() limbs
        const r_limbs = a_limbs[0..b.len];
        const r_len = llshr(r.limbs, r_limbs, norm_shift);

        r.normalize(r_len);
        q.normalize(@min(q.limbs.len, calcDivQLen(a.len, b.len)));
        r.positive = r_positive;
        q.positive = q_positive;
    }

    /// Truncate an integer to a number of bits, following 2s-complement semantics.
    /// `r` may alias `a`.
    ///
    /// Asserts `r` has enough storage to compute the result.
    /// The upper bound is `calcTwosCompLimbCount(a.len)`.
    pub fn truncate(r: *Mutable, a: Const, signedness: Signedness, bit_count: usize) void {
        // Handle 0-bit integers.
        if (bit_count == 0) {
            @branchHint(.unlikely);
            r.set(0);
            return;
        }

        const max_limbs = calcTwosCompLimbCount(bit_count);
        const sign_bit = @as(Limb, 1) << @truncate(bit_count - 1);
        const mask = @as(Limb, maxInt(Limb)) >> @truncate(-%bit_count);

        // Guess whether the result will have the same sign as `a`.
        //  * If the result will be signed zero, the guess is `true`.
        //  * If the result will be the minimum signed integer, the guess is `false`.
        //  * If the result will be unsigned zero, the guess is `a.positive`.
        //  * Otherwise the guess is correct.
        const same_sign_guess = switch (signedness) {
            .signed => max_limbs > a.limbs.len or a.limbs[max_limbs - 1] & sign_bit == 0,
            .unsigned => a.positive,
        };

        const abs_trunc_a: Const = .{
            .positive = true,
            .limbs = a.limbs[0..llnormalize(a.limbs[0..@min(a.limbs.len, max_limbs)])],
        };
        if (same_sign_guess or abs_trunc_a.eqlZero()) {
            // One of the following is true:
            //  * The result is zero.
            //  * The result is non-zero and has the same sign as `a`.
            r.copy(abs_trunc_a);
            if (max_limbs <= r.len) r.limbs[max_limbs - 1] &= mask;
            r.normalize(r.len);
            r.positive = a.positive or r.eqlZero();
        } else {
            // One of the following is true:
            //  * The result is the minimum signed integer.
            //  * The result is unsigned zero.
            //  * The result is non-zero and has the opposite sign as `a`.
            r.addScalar(abs_trunc_a, -1);
            llnot(r.limbs[0..r.len]);
            @memset(r.limbs[r.len..max_limbs], maxInt(Limb));
            r.limbs[max_limbs - 1] &= mask;
            r.normalize(max_limbs);
            r.positive = switch (signedness) {
                // The only value with the sign bit still set is the minimum signed integer.
                .signed => !a.positive and r.limbs[max_limbs - 1] & sign_bit == 0,
                .unsigned => !a.positive or r.eqlZero(),
            };
        }
    }

    /// Saturate an integer to a number of bits, following 2s-complement semantics.
    /// r may alias a.
    ///
    /// Asserts `r` has enough storage to store the result.
    /// The upper bound is `calcTwosCompLimbCount(a.len)`.
    pub fn saturate(r: *Mutable, a: Const, signedness: Signedness, bit_count: usize) void {
        if (!a.fitsInTwosComp(signedness, bit_count)) {
            r.setTwosCompIntLimit(if (r.positive) .max else .min, signedness, bit_count);
        }
    }

    /// Read the value of `x` from `buffer`.
    /// Asserts that `buffer` is large enough to contain a value of bit-size `bit_count`.
    ///
    /// The contents of `buffer` are interpreted as if they were the contents of
    /// @ptrCast(*[buffer.len]const u8, &x). Byte ordering is determined by `endian`
    /// and any required padding bits are expected on the MSB end.
    pub fn readTwosComplement(
        x: *Mutable,
        buffer: []const u8,
        bit_count: usize,
        endian: Endian,
        signedness: Signedness,
    ) void {
        return readPackedTwosComplement(x, buffer, 0, bit_count, endian, signedness);
    }

    /// Read the value of `x` from a packed memory `buffer`.
    /// Asserts that `buffer` is large enough to contain a value of bit-size `bit_count`
    /// at offset `bit_offset`.
    ///
    /// This is equivalent to loading the value of an integer with `bit_count` bits as
    /// if it were a field in packed memory at the provided bit offset.
    pub fn readPackedTwosComplement(
        x: *Mutable,
        buffer: []const u8,
        bit_offset: usize,
        bit_count: usize,
        endian: Endian,
        signedness: Signedness,
    ) void {
        if (bit_count == 0) {
            x.limbs[0] = 0;
            x.len = 1;
            x.positive = true;
            return;
        }

        // Check whether the input is negative
        var positive = true;
        if (signedness == .signed) {
            const total_bits = bit_offset + bit_count;
            const last_byte = switch (endian) {
                .little => ((total_bits + 7) / 8) - 1,
                .big => buffer.len - ((total_bits + 7) / 8),
            };

            const sign_bit = @as(u8, 1) << @as(u3, @intCast((total_bits - 1) % 8));
            positive = ((buffer[last_byte] & sign_bit) == 0);
        }

        // Copy all complete limbs
        var carry: u1 = 1;
        var limb_index: usize = 0;
        var bit_index: usize = 0;
        while (limb_index < bit_count / @bitSizeOf(Limb)) : (limb_index += 1) {
            // Read one Limb of bits
            var limb = mem.readPackedInt(Limb, buffer, bit_index + bit_offset, endian);
            bit_index += @bitSizeOf(Limb);

            // 2's complement (bitwise not, then add carry bit)
            if (!positive) {
                const ov = @addWithOverflow(~limb, carry);
                limb = ov[0];
                carry = ov[1];
            }
            x.limbs[limb_index] = limb;
        }

        // Copy the remaining bits
        if (bit_count != bit_index) {
            // Read all remaining bits
            var limb = switch (signedness) {
                .unsigned => mem.readVarPackedInt(Limb, buffer, bit_index + bit_offset, bit_count - bit_index, endian, .unsigned),
                .signed => b: {
                    const SLimb = std.meta.Int(.signed, @bitSizeOf(Limb));
                    const limb = mem.readVarPackedInt(SLimb, buffer, bit_index + bit_offset, bit_count - bit_index, endian, .signed);
                    break :b @as(Limb, @bitCast(limb));
                },
            };

            // 2's complement (bitwise not, then add carry bit)
            if (!positive) {
                const ov = @addWithOverflow(~limb, carry);
                assert(ov[1] == 0);
                limb = ov[0];
            }
            x.limbs[limb_index] = limb;

            limb_index += 1;
        }

        x.positive = positive;
        x.len = limb_index;
        x.normalize(x.len);
    }

    /// Normalize a possible sequence of leading zeros.
    ///
    /// [1, 2, 3, 4, 0] -> [1, 2, 3, 4]
    /// [1, 2, 0, 0, 0] -> [1, 2]
    /// [0, 0, 0, 0, 0] -> [0]
    pub fn normalize(r: *Mutable, length: usize) void {
        r.len = llnormalize(r.limbs[0..length]);
    }
};

/// A arbitrary-precision big integer, with a fixed set of immutable limbs.
pub const Const = struct {
    /// Raw digits. These are:
    ///
    /// * Little-endian ordered
    /// * limbs.len >= 1
    /// * Zero is represented as limbs.len == 1 with limbs[0] == 0.
    ///
    /// Accessing limbs directly should be avoided.
    limbs: []const Limb,
    positive: bool,

    /// The result is an independent resource which is managed by the caller.
    pub fn toManaged(self: Const, allocator: Allocator) Allocator.Error!Managed {
        const limbs = try allocator.alloc(Limb, @max(Managed.default_capacity, self.limbs.len));
        @memcpy(limbs[0..self.limbs.len], self.limbs);
        return Managed{
            .allocator = allocator,
            .limbs = limbs,
            .metadata = if (self.positive)
                self.limbs.len & ~Managed.sign_bit
            else
                self.limbs.len | Managed.sign_bit,
        };
    }

    /// Asserts `limbs` is big enough to store the value.
    pub fn toMutable(self: Const, limbs: []Limb) Mutable {
        @memcpy(limbs[0..self.limbs.len], self.limbs[0..self.limbs.len]);
        return .{
            .limbs = limbs,
            .positive = self.positive,
            .len = self.limbs.len,
        };
    }

    pub fn dump(self: Const) void {
        for (self.limbs[0..self.limbs.len]) |limb| {
            std.debug.print("{x} ", .{limb});
        }
        std.debug.print("len={} positive={}\n", .{ self.limbs.len, self.positive });
    }

    pub fn abs(self: Const) Const {
        return .{
            .limbs = self.limbs,
            .positive = true,
        };
    }

    pub fn negate(self: Const) Const {
        return .{
            .limbs = self.limbs,
            .positive = !self.positive,
        };
    }

    pub fn isOdd(self: Const) bool {
        return self.limbs[0] & 1 != 0;
    }

    pub fn isEven(self: Const) bool {
        return !self.isOdd();
    }

    /// Returns the number of bits required to represent the absolute value of an integer.
    pub fn bitCountAbs(self: Const) usize {
        return (self.limbs.len - 1) * limb_bits + (limb_bits - @clz(self.limbs[self.limbs.len - 1]));
    }

    /// Returns the number of bits required to represent the integer in twos-complement form.
    ///
    /// If the integer is negative the value returned is the number of bits needed by a signed
    /// integer to represent the value. If positive the value is the number of bits for an
    /// unsigned integer. Any unsigned integer will fit in the signed integer with bitcount
    /// one greater than the returned value.
    ///
    /// e.g. -127 returns 8 as it will fit in an i8. 127 returns 7 since it fits in a u7.
    pub fn bitCountTwosComp(self: Const) usize {
        var bits = self.bitCountAbs();

        // If the entire value has only one bit set (e.g. 0b100000000) then the negation in twos
        // complement requires one less bit.
        if (!self.positive) block: {
            bits += 1;

            if (@popCount(self.limbs[self.limbs.len - 1]) == 1) {
                for (self.limbs[0 .. self.limbs.len - 1]) |limb| {
                    if (@popCount(limb) != 0) {
                        break :block;
                    }
                }

                bits -= 1;
            }
        }

        return bits;
    }

    /// Returns the number of bits required to represent the integer in twos-complement form
    /// with the given signedness.
    pub fn bitCountTwosCompForSignedness(self: Const, signedness: std.builtin.Signedness) usize {
        return self.bitCountTwosComp() + @intFromBool(self.positive and signedness == .signed);
    }

    /// @popCount with two's complement semantics.
    ///
    /// This returns the number of 1 bits set when the value would be represented in
    /// two's complement with the given integer width (bit_count).
    /// This includes the leading sign bit, which will be set for negative values.
    ///
    /// Asserts that bit_count is enough to represent value in two's compliment
    /// and that the final result fits in a usize.
    /// Asserts that there are no trailing empty limbs on the most significant end,
    /// i.e. that limb count matches `calcLimbLen()` and zero is not negative.
    pub fn popCount(self: Const, bit_count: usize) usize {
        var sum: usize = 0;
        if (self.positive) {
            for (self.limbs) |limb| {
                sum += @popCount(limb);
            }
        } else {
            assert(self.fitsInTwosComp(.signed, bit_count));
            assert(self.limbs[self.limbs.len - 1] != 0);

            var remaining_bits = bit_count;
            var carry: u1 = 1;
            var add_res: Limb = undefined;

            // All but the most significant limb.
            for (self.limbs[0 .. self.limbs.len - 1]) |limb| {
                const ov = @addWithOverflow(~limb, carry);
                add_res = ov[0];
                carry = ov[1];
                sum += @popCount(add_res);
                remaining_bits -= limb_bits; // Asserted not to underflow by fitsInTwosComp
            }

            // The most significant limb may have fewer than @bitSizeOf(Limb) meaningful bits,
            // which we can detect with @clz().
            // There may also be fewer limbs than needed to fill bit_count.
            const limb = self.limbs[self.limbs.len - 1];
            const leading_zeroes = @clz(limb);
            // The most significant limb is asserted not to be all 0s (above),
            // so ~limb cannot be all 1s, and ~limb + 1 cannot overflow.
            sum += @popCount(~limb + carry);
            sum -= leading_zeroes; // All leading zeroes were flipped and added to sum, so undo those
            const remaining_ones = remaining_bits - (limb_bits - leading_zeroes); // All bits not covered by limbs
            sum += remaining_ones;
        }
        return sum;
    }

    pub fn fitsInTwosComp(self: Const, signedness: Signedness, bit_count: usize) bool {
        if (self.eqlZero()) {
            return true;
        }
        if (signedness == .unsigned and !self.positive) {
            return false;
        }
        return bit_count >= self.bitCountTwosCompForSignedness(signedness);
    }

    /// Returns whether self can fit into an integer of the requested type.
    pub fn fits(self: Const, comptime T: type) bool {
        const info = @typeInfo(T).int;
        return self.fitsInTwosComp(info.signedness, info.bits);
    }

    /// Returns the approximate size of the integer in the given base. Negative values accommodate for
    /// the minus sign. This is used for determining the number of characters needed to print the
    /// value. It is either correct or one too large.
    pub fn sizeInBaseUpperBound(self: Const, base: usize) usize {
        // floor(self.bitCountAbs() / log2(base)) + 1
        // is either correct or one too large, does not account for the minus sign
        const digit_count = @as(usize, @intFromFloat(@as(f32, @floatFromInt(self.bitCountAbs())) / math.log2(@as(f32, @floatFromInt(base))))) + 1;
        return @intFromBool(!self.positive) // minus sign
        + digit_count;
    }

    pub const ConvertError = error{
        NegativeIntoUnsigned,
        TargetTooSmall,
    };

    /// Deprecated; use `toInt`.
    pub const to = toInt;

    /// Convert `self` to `Int`.
    ///
    /// Returns an error if self cannot be narrowed into the requested type without truncation.
    pub fn toInt(self: Const, comptime Int: type) ConvertError!Int {
        switch (@typeInfo(Int)) {
            .int => |info| {
                // Make sure -0 is handled correctly.
                if (self.eqlZero()) return 0;

                const Unsigned = std.meta.Int(.unsigned, info.bits);

                if (!self.fitsInTwosComp(info.signedness, info.bits)) {
                    return error.TargetTooSmall;
                }

                var r: Unsigned = 0;

                if (@sizeOf(Unsigned) <= @sizeOf(Limb)) {
                    r = @intCast(self.limbs[0]);
                } else {
                    for (self.limbs[0..self.limbs.len], 0..) |_, ri| {
                        const limb = self.limbs[self.limbs.len - ri - 1];
                        r <<= limb_bits;
                        r |= limb;
                    }
                }

                if (info.signedness == .unsigned) {
                    return if (self.positive) @intCast(r) else error.NegativeIntoUnsigned;
                } else {
                    if (self.positive) {
                        return @intCast(r);
                    } else {
                        if (math.cast(Int, r)) |ok| {
                            return -ok;
                        } else {
                            return minInt(Int);
                        }
                    }
                }
            },
            else => @compileError("expected int type, found '" ++ @typeName(Int) ++ "'"),
        }
    }

    /// Convert self to `Float`.
    pub fn toFloat(self: Const, comptime Float: type, round: Round) struct { Float, Exactness } {
        if (Float == comptime_float) return self.toFloat(f128, round);
        const normalized_abs: Const = .{
            .limbs = self.limbs[0..llnormalize(self.limbs)],
            .positive = true,
        };
        if (normalized_abs.eqlZero()) return .{ if (self.positive) 0.0 else -0.0, .exact };

        const Repr = std.math.FloatRepr(Float);
        var mantissa_limbs: [calcNonZeroTwosCompLimbCount(1 + @bitSizeOf(Repr.Mantissa))]Limb = undefined;
        var mantissa: Mutable = .{
            .limbs = &mantissa_limbs,
            .positive = undefined,
            .len = undefined,
        };
        var exponent = normalized_abs.bitCountAbs() - 1;
        const exactness: Exactness = exactness: {
            if (exponent <= @bitSizeOf(Repr.Normalized.Fraction)) {
                mantissa.shiftLeft(normalized_abs, @intCast(@bitSizeOf(Repr.Normalized.Fraction) - exponent));
                break :exactness .exact;
            }
            const shift: usize = @intCast(exponent - @bitSizeOf(Repr.Normalized.Fraction));
            mantissa.shiftRight(normalized_abs, shift);
            const final_limb_index = (shift - 1) / limb_bits;
            const round_bits = normalized_abs.limbs[final_limb_index] << @truncate(-%shift) |
                @intFromBool(!std.mem.allEqual(Limb, normalized_abs.limbs[0..final_limb_index], 0));
            if (round_bits == 0) break :exactness .exact;
            round: switch (round) {
                .nearest_even => {
                    const half: Limb = 1 << (limb_bits - 1);
                    if (round_bits >= half) mantissa.addScalar(mantissa.toConst(), 1);
                    if (round_bits == half) mantissa.limbs[0] &= ~@as(Limb, 1);
                },
                .away => mantissa.addScalar(mantissa.toConst(), 1),
                .trunc => {},
                .floor => if (!self.positive) continue :round .away,
                .ceil => if (self.positive) continue :round .away,
            }
            break :exactness .inexact;
        };
        const normalized_res: Repr.Normalized = .{
            .fraction = @truncate(mantissa.toInt(Repr.Mantissa) catch |err| switch (err) {
                error.NegativeIntoUnsigned => unreachable,
                error.TargetTooSmall => fraction: {
                    assert(mantissa.toConst().orderAgainstScalar(1 << @bitSizeOf(Repr.Mantissa)).compare(.eq));
                    exponent += 1;
                    break :fraction 1 << (@bitSizeOf(Repr.Mantissa) - 1);
                },
            }),
            .exponent = std.math.lossyCast(Repr.Normalized.Exponent, exponent),
        };
        return .{ normalized_res.reconstruct(if (self.positive) .positive else .negative), exactness };
    }

    /// To allow `std.fmt.format` to work with this type.
    /// If the absolute value of integer is greater than or equal to `pow(2, 64 * @sizeOf(usize) * 8)`,
    /// this function will fail to print the string, printing "(BigInt)" instead of a number.
    /// This is because the rendering algorithm requires reversing a string, which requires O(N) memory.
    /// See `toString` and `toStringAlloc` for a way to print big integers without failure.
    pub fn format(
        self: Const,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        _ = options;
        comptime var base = 10;
        comptime var case: std.fmt.Case = .lower;

        if (fmt.len == 0 or comptime mem.eql(u8, fmt, "d")) {
            base = 10;
            case = .lower;
        } else if (comptime mem.eql(u8, fmt, "b")) {
            base = 2;
            case = .lower;
        } else if (comptime mem.eql(u8, fmt, "x")) {
            base = 16;
            case = .lower;
        } else if (comptime mem.eql(u8, fmt, "X")) {
            base = 16;
            case = .upper;
        } else {
            std.fmt.invalidFmtError(fmt, self);
        }

        const available_len = 64;
        if (self.limbs.len > available_len)
            return out_stream.writeAll("(BigInt)");

        var limbs: [available_len]Limb = undefined;

        const biggest: Const = .{
            .limbs = &([1]Limb{comptime math.maxInt(Limb)} ** available_len),
            .positive = false,
        };
        var buf: [biggest.sizeInBaseUpperBound(base)]u8 = undefined;
        const len = self.toString(&buf, base, case, null, &limbs) catch unreachable;
        return out_stream.writeAll(buf[0..len]);
    }

    /// Converts self to a string in the requested base.
    /// Caller owns returned memory.
    /// Asserts that `base` is in the range [2, 36].
    /// See also `toString`, a lower level function than this.
    pub fn toStringAlloc(self: Const, allocator: Allocator, base: u8, case: std.fmt.Case) Allocator.Error![]u8 {
        assert(base >= 2);
        assert(base <= 36);

        if (self.eqlZero()) {
            return allocator.dupe(u8, "0");
        }
        var string = try allocator.alloc(u8, self.sizeInBaseUpperBound(base));
        errdefer allocator.free(string);

        const string_len = try self.toString(string, base, case, allocator, null);

        if (!allocator.resize(string, string_len))
            string = try allocator.realloc(string, string_len)
        else
            string = string[0..string_len];

        return string;
    }

    /// Converts self to a string in the requested base.
    /// Asserts that `base` is in the range [2, 36].
    /// `string` is a caller-provided slice of at least `sizeInBaseUpperBound` bytes,
    /// where the result is written to.
    /// Returns the length of the string.
    ///
    /// Either an allocator or a `limbs_buffer` must be caller-provided.
    /// If provided with no allocator, `limbs_buffer` must have a length of at least `self.limbs.len`.
    /// Providing an allocator is required to enable the use of faster base conversion algorithm if
    /// the number is large enough.
    ///
    /// If an allocation fails, this function tries to fallback onto the slower algorithm.
    /// In that case, if `limbs_buffer` is provided, it will be used. Otherwise, it will try to
    /// allocate it.
    ///
    /// If a `limbs_buffer` is provided (with or without an allocator), this function will not fail.
    ///
    /// In the case of power-of-two base, `limbs_buffer` is ignored.
    /// See also `toStringAlloc`, a higher level function than this.
    pub fn toString(self: Const, string: []u8, base: u8, case: std.fmt.Case, allocator: ?Allocator, limbs_buffer: ?[]Limb) Allocator.Error!usize {
        assert(base >= 2);
        assert(base <= constants.big_bases.len);
        assert(allocator != null or limbs_buffer != null);
        assert(string.len >= sizeInBaseUpperBound(self, base));

        @memset(string, 0);

        if (self.eqlZero()) {
            string[0] = '0';
            return 1;
        }

        // Power of two: can do a single pass and use masks to extract digits.
        if (math.isPowerOfTwo(base)) {
            var digits_len: usize = string.len;
            const base_shift = math.log2_int(Limb, base);

            outer: for (self.limbs[0..self.limbs.len]) |limb| {
                var shift: usize = 0;
                while (shift < limb_bits) : (shift += base_shift) {
                    const r = @as(u8, @intCast((limb >> @as(Log2Limb, @intCast(shift))) & @as(Limb, base - 1)));
                    string[digits_len - 1] = r;
                    digits_len -= 1;
                    // If we hit the end, it must be all zeroes from here.
                    if (digits_len == 0) break :outer;
                }
            }

            // Always will have a non-zero digit somewhere.
            while (string[digits_len] == '0') {
                string[digits_len] = 0;
                digits_len += 1;
            }
        } else if (allocator == null or self.limbs.len <= tostring_subquadratic_threshold) {
            const buffer = limbs_buffer orelse try allocator.?.alloc(Limb, self.limbs.len);
            defer if (limbs_buffer == null) allocator.?.free(buffer);

            assert(buffer.len >= self.limbs.len);

            const num = buffer[0..self.limbs.len];
            @memcpy(num, self.limbs);

            toStringBasecase(num, string, base);
        } else {
            var arena = std.heap.ArenaAllocator.init(allocator.?);
            defer arena.deinit();
            const arena_allocator = arena.allocator();

            // Subquadratic algorithm, using divide and conquer
            // We compute a list of bases of the form B^(2^k) with B = big_bases[base]
            //
            // The last base we compute (noted `last_B`) verifies self > `last_B` >= sqrt(self)
            //
            // The algorithm is explained above the definition of `toStringSubquadratic`
            var base_list = std.ArrayList(Mutable).init(arena_allocator);
            {
                var b = Managed.initSet(arena_allocator, constants.big_bases[base]) catch return self.toStringFallback(string, base, case, allocator.?, limbs_buffer);
                base_list.append(b.toMutable()) catch return self.toStringFallback(string, base, case, allocator.?, limbs_buffer);

                // if base.len() > a.len() / 2 + 1, then we have base > sqrt(a)
                while (b.toConst().order(self) == .lt and b.len() <= self.limbs.len / 2 + 1) {
                    // we make sure the list growing is not the last allocation,
                    // so if we need to deallocate the last computed base,
                    // the arena will be able to reuse the memory
                    base_list.ensureTotalCapacity(base_list.items.len + 1) catch return self.toStringFallback(string, base, case, allocator.?, limbs_buffer);
                    // TODO: why does the std thinks it needs + 1 ???
                    var next_b = Managed.initCapacity(arena_allocator, b.len() * 2 + 1) catch return self.toStringFallback(string, base, case, allocator.?, limbs_buffer);

                    // TODO: switch to sqr once it is faster than mul
                    next_b.mul(&b, &b) catch unreachable;
                    base_list.appendAssumeCapacity(next_b.toMutable());

                    b = next_b;
                }
                // If the last one is greater than a, then the previous is greater than sqrt(a).
                // While it is possible to ignore it as the recursive function will ignore it,
                // freeing its memory is useful since we use an arena.
                if (b.toConst().order(self) != .lt) {
                    const popped = base_list.pop();
                    arena_allocator.free(popped.?.limbs);
                }
            }

            // we allocate one more Limb as the division may need to shift the number
            const buffer = arena_allocator.alloc(Limb, self.limbs.len + 1) catch return self.toStringFallback(string, base, case, allocator.?, limbs_buffer);
            @memcpy(buffer[0..self.limbs.len], self.limbs[0..self.limbs.len]);
            buffer[self.limbs.len] = 0;

            toStringSubquadratic(arena_allocator, buffer, string, base, base_list.items) catch return self.toStringFallback(string, base, case, allocator.?, limbs_buffer);
        }

        var i: usize = 0;
        while (string[i] == 0) : (i += 1) {}

        if (!self.positive) {
            string[i - 1] = '-';
            i -= 1;
        }

        // same as `copyForwards` and then converting the digits' value to character
        if (!self.positive)
            string[0] = string[i]
        else
            string[0] = std.fmt.digitToChar(string[i], case);

        for (1..string.len - i) |k|
            string[k] = std.fmt.digitToChar(string[k + i], case);

        return string.len - i;
    }

    /// Fallback function in case an allocation fails in `toString`
    /// Must only be called by `toString` on failure
    fn toStringFallback(self: Const, string: []u8, base: u8, case: std.fmt.Case, allocator: Allocator, limbs_buffer: ?[]Limb) Allocator.Error!usize {
        @memset(string, 0);

        // We do not pass the allocator to avoid an infinite loop
        if (limbs_buffer) |buffer| {
            return self.toString(string, base, case, null, buffer);
        } else {
            const buffer = try allocator.alloc(Limb, self.limbs.len);
            defer allocator.free(buffer);

            return self.toString(string, base, case, null, buffer);
        }
    }

    /// Write the value of `x` into `buffer`
    /// Asserts that `buffer` is large enough to store the value.
    ///
    /// `buffer` is filled so that its contents match what would be observed via
    /// @ptrCast(*[buffer.len]const u8, &x). Byte ordering is determined by `endian`,
    /// and any required padding bits are added on the MSB end.
    pub fn writeTwosComplement(x: Const, buffer: []u8, endian: Endian) void {
        return writePackedTwosComplement(x, buffer, 0, 8 * buffer.len, endian);
    }

    /// Write the value of `x` to a packed memory `buffer`.
    /// Asserts that `buffer` is large enough to contain a value of bit-size `bit_count`
    /// at offset `bit_offset`.
    ///
    /// This is equivalent to storing the value of an integer with `bit_count` bits as
    /// if it were a field in packed memory at the provided bit offset.
    pub fn writePackedTwosComplement(x: Const, buffer: []u8, bit_offset: usize, bit_count: usize, endian: Endian) void {
        assert(x.fitsInTwosComp(if (x.positive) .unsigned else .signed, bit_count));

        // Copy all complete limbs
        var carry: u1 = 1;
        var limb_index: usize = 0;
        var bit_index: usize = 0;
        while (limb_index < bit_count / @bitSizeOf(Limb)) : (limb_index += 1) {
            var limb: Limb = if (limb_index < x.limbs.len) x.limbs[limb_index] else 0;

            // 2's complement (bitwise not, then add carry bit)
            if (!x.positive) {
                const ov = @addWithOverflow(~limb, carry);
                limb = ov[0];
                carry = ov[1];
            }

            // Write one Limb of bits
            mem.writePackedInt(Limb, buffer, bit_index + bit_offset, limb, endian);
            bit_index += @bitSizeOf(Limb);
        }

        // Copy the remaining bits
        if (bit_count != bit_index) {
            var limb: Limb = if (limb_index < x.limbs.len) x.limbs[limb_index] else 0;

            // 2's complement (bitwise not, then add carry bit)
            if (!x.positive) limb = ~limb +% carry;

            // Write all remaining bits
            mem.writeVarPackedInt(buffer, bit_index + bit_offset, bit_count - bit_index, limb, endian);
        }
    }

    /// Returns `math.Order.lt`, `math.Order.eq`, `math.Order.gt` if
    /// `|a| < |b|`, `|a| == |b|`, or `|a| > |b|` respectively.
    pub fn orderAbs(a: Const, b: Const) math.Order {
        return llcmp(a.limbs, b.limbs);
    }

    /// Returns `math.Order.lt`, `math.Order.eq`, `math.Order.gt` if `a < b`, `a == b` or `a > b` respectively.
    pub fn order(a: Const, b: Const) math.Order {
        if (a.positive != b.positive) {
            if (eqlZero(a) and eqlZero(b)) {
                return .eq;
            } else {
                return if (a.positive) .gt else .lt;
            }
        } else {
            const r = orderAbs(a, b);
            return if (a.positive) r else switch (r) {
                .lt => math.Order.gt,
                .eq => math.Order.eq,
                .gt => math.Order.lt,
            };
        }
    }

    /// Same as `order` but the right-hand operand is a primitive integer.
    pub fn orderAgainstScalar(lhs: Const, scalar: anytype) math.Order {
        // Normally we could just determine the number of limbs needed with calcLimbLen,
        // but that is not comptime-known when scalar is not a comptime_int.  Instead, we
        // use calcTwosCompLimbCount for a non-comptime_int scalar, which can be pessimistic
        // in the case that scalar happens to be small in magnitude within its type, but it
        // is well worth being able to use the stack and not needing an allocator passed in.
        // Note that Mutable.init still sets len to calcLimbLen(scalar) in any case.
        const limbs_len = comptime switch (@typeInfo(@TypeOf(scalar))) {
            .comptime_int => calcLimbLen(scalar),
            .int => |info| calcTwosCompLimbCount(info.bits),
            else => @compileError("expected scalar to be an int"),
        };
        var limbs: [limbs_len]Limb = undefined;
        const rhs = Mutable.init(&limbs, scalar);
        return order(lhs, rhs.toConst());
    }

    /// Returns true if `a == 0`.
    pub fn eqlZero(a: Const) bool {
        var d: Limb = 0;
        for (a.limbs) |limb| d |= limb;
        return d == 0;
    }

    /// Returns true if `|a| == |b|`.
    pub fn eqlAbs(a: Const, b: Const) bool {
        return orderAbs(a, b) == .eq;
    }

    /// Returns true if `a == b`.
    pub fn eql(a: Const, b: Const) bool {
        return order(a, b) == .eq;
    }

    /// Returns the number of leading zeros in twos-complement form.
    pub fn clz(a: Const, bits: Limb) Limb {
        // Limbs are stored in little-endian order but we need to iterate big-endian.
        if (!a.positive and !a.eqlZero()) return 0;
        var total_limb_lz: Limb = 0;
        var i: usize = a.limbs.len;
        const bits_per_limb = @bitSizeOf(Limb);
        while (i != 0) {
            i -= 1;
            const this_limb_lz = @clz(a.limbs[i]);
            total_limb_lz += this_limb_lz;
            if (this_limb_lz != bits_per_limb) break;
        }
        const total_limb_bits = a.limbs.len * bits_per_limb;
        return total_limb_lz + bits - total_limb_bits;
    }

    /// Returns the number of trailing zeros in twos-complement form.
    pub fn ctz(a: Const, bits: Limb) Limb {
        // Limbs are stored in little-endian order. Converting a negative number to twos-complement
        // flips all bits above the lowest set bit, which does not affect the trailing zero count.
        if (a.eqlZero()) return bits;
        var result: Limb = 0;
        for (a.limbs) |limb| {
            const limb_tz = @ctz(limb);
            result += limb_tz;
            if (limb_tz != @bitSizeOf(Limb)) break;
        }
        return @min(result, bits);
    }
};

/// An arbitrary-precision big integer along with an allocator which manages the memory.
///
/// Memory is allocated as needed to ensure operations never overflow. The range
/// is bounded only by available memory.
pub const Managed = struct {
    pub const sign_bit: usize = 1 << (@typeInfo(usize).int.bits - 1);

    /// Default number of limbs to allocate on creation of a `Managed`.
    pub const default_capacity = 4;

    /// Allocator used by the Managed when requesting memory.
    allocator: Allocator,

    /// Raw digits. These are:
    ///
    /// * Little-endian ordered
    /// * limbs.len >= 1
    /// * Zero is represent as Managed.len() == 1 with limbs[0] == 0.
    ///
    /// Accessing limbs directly should be avoided.
    limbs: []Limb,

    /// High bit is the sign bit. If set, Managed is negative, else Managed is positive.
    /// The remaining bits represent the number of limbs used by Managed.
    metadata: usize,

    /// Creates a new `Managed`. `default_capacity` limbs will be allocated immediately.
    /// The integer value after initializing is `0`.
    pub fn init(allocator: Allocator) !Managed {
        return initCapacity(allocator, default_capacity);
    }

    pub fn toMutable(self: Managed) Mutable {
        return .{
            .limbs = self.limbs,
            .positive = self.isPositive(),
            .len = self.len(),
        };
    }

    pub fn toConst(self: Managed) Const {
        return .{
            .limbs = self.limbs[0..self.len()],
            .positive = self.isPositive(),
        };
    }

    /// Creates a new `Managed` with value `value`.
    ///
    /// This is identical to an `init`, followed by a `set`.
    pub fn initSet(allocator: Allocator, value: anytype) !Managed {
        var s = try Managed.init(allocator);
        errdefer s.deinit();
        try s.set(value);
        return s;
    }

    /// Creates a new Managed with a specific capacity. If capacity < default_capacity then the
    /// default capacity will be used instead.
    /// The integer value after initializing is `0`.
    pub fn initCapacity(allocator: Allocator, capacity: usize) !Managed {
        return Managed{
            .allocator = allocator,
            .metadata = 1,
            .limbs = block: {
                const limbs = try allocator.alloc(Limb, @max(default_capacity, capacity));
                limbs[0] = 0;
                break :block limbs;
            },
        };
    }

    /// Returns the number of limbs currently in use.
    pub fn len(self: Managed) usize {
        return self.metadata & ~sign_bit;
    }

    /// Returns whether an Managed is positive.
    pub fn isPositive(self: Managed) bool {
        return self.metadata & sign_bit == 0;
    }

    /// Sets the sign of an Managed.
    pub fn setSign(self: *Managed, positive: bool) void {
        if (positive) {
            self.metadata &= ~sign_bit;
        } else {
            self.metadata |= sign_bit;
        }
    }

    /// Sets the length of an Managed.
    ///
    /// If setLen is used, then the Managed must be normalized to suit.
    pub fn setLen(self: *Managed, new_len: usize) void {
        self.metadata &= sign_bit;
        self.metadata |= new_len;
    }

    pub fn setMetadata(self: *Managed, positive: bool, length: usize) void {
        self.metadata = if (positive) length & ~sign_bit else length | sign_bit;
    }

    /// Ensures an Managed has enough space allocated for capacity limbs. If the Managed does not have
    /// sufficient capacity, the exact amount will be allocated. This occurs even if the requested
    /// capacity is only greater than the current capacity by one limb.
    pub fn ensureCapacity(self: *Managed, capacity: usize) !void {
        if (capacity <= self.limbs.len) {
            return;
        }
        self.limbs = try self.allocator.realloc(self.limbs, capacity);
    }

    /// Frees all associated memory.
    pub fn deinit(self: *Managed) void {
        self.allocator.free(self.limbs);
        self.* = undefined;
    }

    /// Returns a `Managed` with the same value. The returned `Managed` is a deep copy and
    /// can be modified separately from the original, and its resources are managed
    /// separately from the original.
    pub fn clone(other: Managed) !Managed {
        return other.cloneWithDifferentAllocator(other.allocator);
    }

    pub fn cloneWithDifferentAllocator(other: Managed, allocator: Allocator) !Managed {
        return Managed{
            .allocator = allocator,
            .metadata = other.metadata,
            .limbs = block: {
                const limbs = try allocator.alloc(Limb, other.len());
                @memcpy(limbs, other.limbs[0..other.len()]);
                break :block limbs;
            },
        };
    }

    /// Copies the value of the integer to an existing `Managed` so that they both have the same value.
    /// Extra memory will be allocated if the receiver does not have enough capacity.
    pub fn copy(self: *Managed, other: Const) !void {
        if (self.limbs.ptr == other.limbs.ptr) return;

        try self.ensureCapacity(other.limbs.len);
        @memcpy(self.limbs[0..other.limbs.len], other.limbs[0..other.limbs.len]);
        self.setMetadata(other.positive, other.limbs.len);
    }

    /// Efficiently swap a `Managed` with another. This swaps the limb pointers and a full copy is not
    /// performed. The address of the limbs field will not be the same after this function.
    pub fn swap(self: *Managed, other: *Managed) void {
        mem.swap(Managed, self, other);
    }

    /// Debugging tool: prints the state to stderr.
    pub fn dump(self: Managed) void {
        for (self.limbs[0..self.len()]) |limb| {
            std.debug.print("{x} ", .{limb});
        }
        std.debug.print("len={} capacity={} positive={}\n", .{ self.len(), self.limbs.len, self.isPositive() });
    }

    /// Negate the sign.
    pub fn negate(self: *Managed) void {
        self.metadata ^= sign_bit;
    }

    /// Make positive.
    pub fn abs(self: *Managed) void {
        self.metadata &= ~sign_bit;
    }

    pub fn isOdd(self: Managed) bool {
        return self.limbs[0] & 1 != 0;
    }

    pub fn isEven(self: Managed) bool {
        return !self.isOdd();
    }

    /// Returns the number of bits required to represent the absolute value of an integer.
    pub fn bitCountAbs(self: Managed) usize {
        return self.toConst().bitCountAbs();
    }

    /// Returns the number of bits required to represent the integer in twos-complement form.
    ///
    /// If the integer is negative the value returned is the number of bits needed by a signed
    /// integer to represent the value. If positive the value is the number of bits for an
    /// unsigned integer. Any unsigned integer will fit in the signed integer with bitcount
    /// one greater than the returned value.
    ///
    /// e.g. -127 returns 8 as it will fit in an i8. 127 returns 7 since it fits in a u7.
    pub fn bitCountTwosComp(self: Managed) usize {
        return self.toConst().bitCountTwosComp();
    }

    pub fn fitsInTwosComp(self: Managed, signedness: Signedness, bit_count: usize) bool {
        return self.toConst().fitsInTwosComp(signedness, bit_count);
    }

    /// Returns whether self can fit into an integer of the requested type.
    pub fn fits(self: Managed, comptime T: type) bool {
        return self.toConst().fits(T);
    }

    /// Returns the approximate size of the integer in the given base. Negative values accommodate for
    /// the minus sign. This is used for determining the number of characters needed to print the
    /// value. It is inexact and may exceed the given value by ~1-2 bytes.
    pub fn sizeInBaseUpperBound(self: Managed, base: usize) usize {
        return self.toConst().sizeInBaseUpperBound(base);
    }

    /// Sets an Managed to value. Value must be an primitive integer type.
    pub fn set(self: *Managed, value: anytype) Allocator.Error!void {
        try self.ensureCapacity(calcLimbLen(value));
        var m = self.toMutable();
        m.set(value);
        self.setMetadata(m.positive, m.len);
    }

    pub const ConvertError = Const.ConvertError;

    /// Deprecated; use `toInt`.
    pub const to = toInt;

    /// Convert `self` to `Int`.
    ///
    /// Returns an error if self cannot be narrowed into the requested type without truncation.
    pub fn toInt(self: Managed, comptime Int: type) ConvertError!Int {
        return self.toConst().toInt(Int);
    }

    /// Convert `self` to `Float`.
    pub fn toFloat(self: Managed, comptime Float: type, round: Round) struct { Float, Exactness } {
        return self.toConst().toFloat(Float, round);
    }

    /// Set self from the string representation `value`.
    ///
    /// `value` must contain only digits <= `base` and is case insensitive.  Base prefixes are
    /// not allowed (e.g. 0x43 should simply be 43).  Underscores in the input string are
    /// ignored and can be used as digit separators.
    ///
    /// Returns an error if memory could not be allocated or `value` has invalid digits for the
    /// requested base.
    ///
    /// self's allocator is used for temporary storage to boost multiplication performance.
    pub fn setString(self: *Managed, base: u8, value: []const u8) !void {
        if (base < 2 or base > 36) return error.InvalidBase;
        try self.ensureCapacity(calcSetStringLimbCount(base, value.len));
        var m = self.toMutable();
        try m.setString(base, value);
        self.setMetadata(m.positive, m.len);
    }

    /// Set self to either bound of a 2s-complement integer.
    /// Note: The result is still sign-magnitude, not twos complement! In order to convert the
    /// result to twos complement, it is sufficient to take the absolute value.
    pub fn setTwosCompIntLimit(
        r: *Managed,
        limit: TwosCompIntLimit,
        signedness: Signedness,
        bit_count: usize,
    ) !void {
        try r.ensureCapacity(calcTwosCompLimbCount(bit_count));
        var m = r.toMutable();
        m.setTwosCompIntLimit(limit, signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// Converts self to a string in the requested base. Memory is allocated from the provided
    /// allocator and not the one present in self.
    pub fn toString(self: Managed, allocator: Allocator, base: u8, case: std.fmt.Case) ![]u8 {
        if (base < 2 or base > 36) return error.InvalidBase;
        return self.toConst().toStringAlloc(allocator, base, case);
    }

    /// To allow `std.fmt.format` to work with `Managed`.
    /// If the absolute value of integer is greater than or equal to `pow(2, 64 * @sizeOf(usize) * 8)`,
    /// this function will fail to print the string, printing "(BigInt)" instead of a number.
    /// This is because the rendering algorithm requires reversing a string, which requires O(N) memory.
    /// See `toString` and `toStringAlloc` for a way to print big integers without failure.
    pub fn format(
        self: Managed,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        return self.toConst().format(fmt, options, out_stream);
    }

    /// Returns math.Order.lt, math.Order.eq, math.Order.gt if |a| < |b|, |a| ==
    /// |b| or |a| > |b| respectively.
    pub fn orderAbs(a: Managed, b: Managed) math.Order {
        return a.toConst().orderAbs(b.toConst());
    }

    /// Returns math.Order.lt, math.Order.eq, math.Order.gt if a < b, a == b or a > b
    /// respectively.
    pub fn order(a: Managed, b: Managed) math.Order {
        return a.toConst().order(b.toConst());
    }

    /// Returns true if a == 0.
    pub fn eqlZero(a: Managed) bool {
        return a.toConst().eqlZero();
    }

    /// Returns true if |a| == |b|.
    pub fn eqlAbs(a: Managed, b: Managed) bool {
        return a.toConst().eqlAbs(b.toConst());
    }

    /// Returns true if a == b.
    pub fn eql(a: Managed, b: Managed) bool {
        return a.toConst().eql(b.toConst());
    }

    /// Normalize a possible sequence of leading zeros.
    ///
    /// [1, 2, 3, 4, 0] -> [1, 2, 3, 4]
    /// [1, 2, 0, 0, 0] -> [1, 2]
    /// [0, 0, 0, 0, 0] -> [0]
    pub fn normalize(r: *Managed, length: usize) void {
        assert(length > 0);
        assert(length <= r.limbs.len);

        var j = length;
        while (j > 0) : (j -= 1) {
            if (r.limbs[j - 1] != 0) {
                break;
            }
        }

        // Handle zero
        r.setLen(if (j != 0) j else 1);
    }

    /// r = a + scalar
    ///
    /// r and a may be aliases.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn addScalar(r: *Managed, a: *const Managed, scalar: anytype) Allocator.Error!void {
        try r.ensureAddScalarCapacity(a.toConst(), scalar);
        var m = r.toMutable();
        m.addScalar(a.toConst(), scalar);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a + b
    ///
    /// r, a and b may be aliases.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn add(r: *Managed, a: *const Managed, b: *const Managed) Allocator.Error!void {
        try r.ensureAddCapacity(a.toConst(), b.toConst());
        var m = r.toMutable();
        m.add(a.toConst(), b.toConst());
        r.setMetadata(m.positive, m.len);
    }

    /// r = a + b with 2s-complement wrapping semantics. Returns whether any overflow occurred.
    ///
    /// r, a and b may be aliases.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn addWrap(
        r: *Managed,
        a: *const Managed,
        b: *const Managed,
        signedness: Signedness,
        bit_count: usize,
    ) Allocator.Error!bool {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        const wrapped = m.addWrap(a.toConst(), b.toConst(), signedness, bit_count);
        r.setMetadata(m.positive, m.len);
        return wrapped;
    }

    /// r = a + b with 2s-complement saturating semantics.
    ///
    /// r, a and b may be aliases.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn addSat(r: *Managed, a: *const Managed, b: *const Managed, signedness: Signedness, bit_count: usize) Allocator.Error!void {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        m.addSat(a.toConst(), b.toConst(), signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a - b
    ///
    /// r, a and b may be aliases.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn sub(r: *Managed, a: *const Managed, b: *const Managed) !void {
        try r.ensureCapacity(@max(a.len(), b.len()) + 1);
        var m = r.toMutable();
        m.sub(a.toConst(), b.toConst());
        r.setMetadata(m.positive, m.len);
    }

    /// r = a - b with 2s-complement wrapping semantics. Returns whether any overflow occurred.
    ///
    /// r, a and b may be aliases.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn subWrap(
        r: *Managed,
        a: *const Managed,
        b: *const Managed,
        signedness: Signedness,
        bit_count: usize,
    ) Allocator.Error!bool {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        const wrapped = m.subWrap(a.toConst(), b.toConst(), signedness, bit_count);
        r.setMetadata(m.positive, m.len);
        return wrapped;
    }

    /// r = a - b with 2s-complement saturating semantics.
    ///
    /// r, a and b may be aliases.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn subSat(
        r: *Managed,
        a: *const Managed,
        b: *const Managed,
        signedness: Signedness,
        bit_count: usize,
    ) Allocator.Error!void {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        m.subSat(a.toConst(), b.toConst(), signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// rma = a * b
    ///
    /// rma, a and b may be aliases. However, it is more efficient if rma does not alias a or b.
    ///
    /// Returns an error if memory could not be allocated.
    ///
    /// rma's allocator is used for temporary storage to speed up the multiplication.
    pub fn mul(rma: *Managed, a: *const Managed, b: *const Managed) !void {
        var alias_count: usize = 0;
        if (rma.limbs.ptr == a.limbs.ptr)
            alias_count += 1;
        if (rma.limbs.ptr == b.limbs.ptr)
            alias_count += 1;
        try rma.ensureMulCapacity(a.toConst(), b.toConst());
        var m = rma.toMutable();
        if (alias_count == 0) {
            m.mulNoAlias(a.toConst(), b.toConst(), rma.allocator);
        } else {
            const limb_count = calcMulLimbsBufferLen(a.len(), b.len(), alias_count);
            const limbs_buffer = try rma.allocator.alloc(Limb, limb_count);
            defer rma.allocator.free(limbs_buffer);
            m.mul(a.toConst(), b.toConst(), limbs_buffer, rma.allocator);
        }
        rma.setMetadata(m.positive, m.len);
    }

    /// rma = a * b with 2s-complement wrapping semantics.
    ///
    /// rma, a and b may be aliases. However, it is more efficient if rma does not alias a or b.
    ///
    /// Returns an error if memory could not be allocated.
    ///
    /// rma's allocator is used for temporary storage to speed up the multiplication.
    pub fn mulWrap(
        rma: *Managed,
        a: *const Managed,
        b: *const Managed,
        signedness: Signedness,
        bit_count: usize,
    ) !void {
        var alias_count: usize = 0;
        if (rma.limbs.ptr == a.limbs.ptr)
            alias_count += 1;
        if (rma.limbs.ptr == b.limbs.ptr)
            alias_count += 1;

        try rma.ensureTwosCompCapacity(bit_count);
        var m = rma.toMutable();
        if (alias_count == 0) {
            m.mulWrapNoAlias(a.toConst(), b.toConst(), signedness, bit_count, rma.allocator);
        } else {
            const limb_count = calcMulWrapLimbsBufferLen(bit_count, a.len(), b.len(), alias_count);
            const limbs_buffer = try rma.allocator.alloc(Limb, limb_count);
            defer rma.allocator.free(limbs_buffer);
            m.mulWrap(a.toConst(), b.toConst(), signedness, bit_count, limbs_buffer, rma.allocator);
        }
        rma.setMetadata(m.positive, m.len);
    }

    pub fn ensureTwosCompCapacity(r: *Managed, bit_count: usize) !void {
        try r.ensureCapacity(calcTwosCompLimbCount(bit_count));
    }

    pub fn ensureAddScalarCapacity(r: *Managed, a: Const, scalar: anytype) !void {
        try r.ensureCapacity(@max(a.limbs.len, calcLimbLen(scalar)) + 1);
    }

    pub fn ensureAddCapacity(r: *Managed, a: Const, b: Const) !void {
        try r.ensureCapacity(@max(a.limbs.len, b.limbs.len) + 1);
    }

    pub fn ensureMulCapacity(rma: *Managed, a: Const, b: Const) !void {
        try rma.ensureCapacity(a.limbs.len + b.limbs.len + 1);
    }

    /// q = a / b (rem r)
    ///
    /// a / b are floored (rounded towards 0).
    ///
    /// Returns an error if memory could not be allocated.
    pub fn divFloor(q: *Managed, r: *Managed, a: *const Managed, b: *const Managed) !void {
        try q.ensureCapacity(a.len());
        try r.ensureCapacity(b.len());
        var mq = q.toMutable();
        var mr = r.toMutable();
        const limbs_buffer = try q.allocator.alloc(Limb, calcDivLimbsBufferLen(a.len(), b.len()));
        defer q.allocator.free(limbs_buffer);
        mq.divFloor(&mr, a.toConst(), b.toConst(), limbs_buffer, q.allocator);
        q.setMetadata(mq.positive, mq.len);
        r.setMetadata(mr.positive, mr.len);
    }

    /// q = a / b (rem r)
    ///
    /// a / b are truncated (rounded towards -inf).
    ///
    /// Returns an error if memory could not be allocated.
    pub fn divTrunc(q: *Managed, r: *Managed, a: *const Managed, b: *const Managed) !void {
        try q.ensureCapacity(a.len());
        try r.ensureCapacity(b.len());
        var mq = q.toMutable();
        var mr = r.toMutable();
        const limbs_buffer = try q.allocator.alloc(Limb, calcDivLimbsBufferLen(a.len(), b.len()));
        defer q.allocator.free(limbs_buffer);
        mq.divTrunc(&mr, a.toConst(), b.toConst(), limbs_buffer, q.allocator);
        q.setMetadata(mq.positive, mq.len);
        r.setMetadata(mr.positive, mr.len);
    }

    /// r = a << shift, in other words, r = a * 2^shift
    /// r and a may alias.
    pub fn shiftLeft(r: *Managed, a: *const Managed, shift: usize) !void {
        try r.ensureCapacity(a.len() + (shift / limb_bits) + 1);
        var m = r.toMutable();
        m.shiftLeft(a.toConst(), shift);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a <<| shift with 2s-complement saturating semantics.
    /// r and a may alias.
    pub fn shiftLeftSat(r: *Managed, a: *const Managed, shift: usize, signedness: Signedness, bit_count: usize) !void {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        m.shiftLeftSat(a.toConst(), shift, signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a >> shift
    /// r and a may alias.
    pub fn shiftRight(r: *Managed, a: *const Managed, shift: usize) !void {
        if (a.len() <= shift / limb_bits) {
            // Shifting negative numbers converges to -1 instead of 0
            if (a.isPositive()) {
                r.metadata = 1;
                r.limbs[0] = 0;
            } else {
                r.metadata = 1;
                r.setSign(false);
                r.limbs[0] = 1;
            }
            return;
        }

        try r.ensureCapacity(a.len() - (shift / limb_bits));
        var m = r.toMutable();
        m.shiftRight(a.toConst(), shift);
        r.setMetadata(m.positive, m.len);
    }

    /// r = ~a under 2s-complement wrapping semantics.
    /// r and a may alias.
    pub fn bitNotWrap(r: *Managed, a: *const Managed, signedness: Signedness, bit_count: usize) !void {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        m.bitNotWrap(a.toConst(), signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a | b
    ///
    /// a and b are zero-extended to the longer of a or b.
    pub fn bitOr(r: *Managed, a: *const Managed, b: *const Managed) !void {
        try r.ensureCapacity(@max(a.len(), b.len()));
        var m = r.toMutable();
        m.bitOr(a.toConst(), b.toConst());
        r.setMetadata(m.positive, m.len);
    }

    /// r = a & b
    pub fn bitAnd(r: *Managed, a: *const Managed, b: *const Managed) !void {
        const cap = if (a.len() >= b.len())
            if (b.isPositive()) b.len() else if (a.isPositive()) a.len() else a.len() + 1
        else if (a.isPositive()) a.len() else if (b.isPositive()) b.len() else b.len() + 1;

        try r.ensureCapacity(cap);
        var m = r.toMutable();
        m.bitAnd(a.toConst(), b.toConst());
        r.setMetadata(m.positive, m.len);
    }

    /// r = a ^ b
    pub fn bitXor(r: *Managed, a: *const Managed, b: *const Managed) !void {
        const cap = @max(a.len(), b.len()) + @intFromBool(a.isPositive() != b.isPositive());
        try r.ensureCapacity(cap);

        var m = r.toMutable();
        m.bitXor(a.toConst(), b.toConst());
        r.setMetadata(m.positive, m.len);
    }

    /// rma may alias x or y.
    /// x and y may alias each other.
    ///
    /// rma's allocator is used for temporary storage to boost multiplication performance.
    pub fn gcd(rma: *Managed, x: *const Managed, y: *const Managed) !void {
        try rma.ensureCapacity(@min(x.len(), y.len()));
        var m = rma.toMutable();
        var limbs_buffer = std.ArrayList(Limb).init(rma.allocator);
        defer limbs_buffer.deinit();
        try m.gcd(x.toConst(), y.toConst(), &limbs_buffer);
        rma.setMetadata(m.positive, m.len);
    }

    /// r = a * a
    pub fn sqr(rma: *Managed, a: *const Managed) !void {
        const needed_limbs = 2 * a.len() + 1;

        if (rma.limbs.ptr == a.limbs.ptr) {
            var m = try Managed.initCapacity(rma.allocator, needed_limbs);
            errdefer m.deinit();
            var m_mut = m.toMutable();
            m_mut.sqrNoAlias(a.toConst(), rma.allocator);
            m.setMetadata(m_mut.positive, m_mut.len);

            rma.deinit();
            rma.swap(&m);
        } else {
            try rma.ensureCapacity(needed_limbs);
            var rma_mut = rma.toMutable();
            rma_mut.sqrNoAlias(a.toConst(), rma.allocator);
            rma.setMetadata(rma_mut.positive, rma_mut.len);
        }
    }

    pub fn pow(rma: *Managed, a: *const Managed, b: u32) !void {
        const needed_limbs = calcPowLimbsBufferLen(a.bitCountAbs(), b);

        const limbs_buffer = try rma.allocator.alloc(Limb, needed_limbs);
        defer rma.allocator.free(limbs_buffer);

        if (rma.limbs.ptr == a.limbs.ptr) {
            var m = try Managed.initCapacity(rma.allocator, needed_limbs);
            errdefer m.deinit();
            var m_mut = m.toMutable();
            m_mut.pow(a.toConst(), b, limbs_buffer);
            m.setMetadata(m_mut.positive, m_mut.len);

            rma.deinit();
            rma.swap(&m);
        } else {
            try rma.ensureCapacity(needed_limbs);
            var rma_mut = rma.toMutable();
            rma_mut.pow(a.toConst(), b, limbs_buffer);
            rma.setMetadata(rma_mut.positive, rma_mut.len);
        }
    }

    /// r = ⌊√a⌋
    pub fn sqrt(rma: *Managed, a: *const Managed) !void {
        const bit_count = a.bitCountAbs();

        if (bit_count == 0) {
            try rma.set(0);
            rma.setMetadata(a.isPositive(), rma.len());
            return;
        }

        if (!a.isPositive()) {
            return error.SqrtOfNegativeNumber;
        }

        const needed_limbs = calcSqrtLimbsBufferLen(bit_count);
        const limbs_buffer = try rma.allocator.alloc(Limb, needed_limbs);
        defer rma.allocator.free(limbs_buffer);

        try rma.ensureCapacity((a.len() - 1) / 2 + 1);
        var m = rma.toMutable();
        m.sqrt(a.toConst(), limbs_buffer);
        rma.setMetadata(m.positive, m.len);
    }

    /// r = truncate(Int(signedness, bit_count), a)
    pub fn truncate(r: *Managed, a: *const Managed, signedness: Signedness, bit_count: usize) !void {
        try r.ensureCapacity(calcTwosCompLimbCount(bit_count));
        var m = r.toMutable();
        m.truncate(a.toConst(), signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// r = saturate(Int(signedness, bit_count), a)
    pub fn saturate(r: *Managed, a: *const Managed, signedness: Signedness, bit_count: usize) !void {
        try r.ensureCapacity(calcTwosCompLimbCount(bit_count));
        var m = r.toMutable();
        m.saturate(a.toConst(), signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// r = @popCount(a) with 2s-complement semantics.
    /// r and a may be aliases.
    pub fn popCount(r: *Managed, a: *const Managed, bit_count: usize) !void {
        try r.ensureCapacity(calcTwosCompLimbCount(bit_count));
        var m = r.toMutable();
        m.popCount(a.toConst(), bit_count);
        r.setMetadata(m.positive, m.len);
    }
};

/// Different operators which can be used in accumulation style functions
/// (llmulacc, llmulaccKaratsuba, llmulaccLong, llmulLimb). In all these functions,
/// a computed value is accumulated with an existing result.
const AccOp = enum {
    /// The computed value is added to the result.
    add,

    /// The computed value is subtracted from the result.
    sub,

    pub fn neg(self: AccOp) AccOp {
        return switch (self) {
            .add => .sub,
            .sub => .add,
        };
    }
};

/// Knuth 4.3.1, Algorithm M.
///
/// r = r (op) a * b
/// r MUST NOT alias any of a or b.
///
/// Returns whether the operation overflowed
/// The result is computed modulo `r.len`.
fn llmulacc(comptime op: AccOp, opt_allocator: ?Allocator, r: []Limb, a: []const Limb, b: []const Limb) bool {
    assert(r.len >= a.len);
    assert(r.len >= b.len);
    assert(!slicesOverlap(r, a));
    assert(!slicesOverlap(r, b));

    // Order greatest first.
    var x = a;
    var y = b;
    if (a.len < b.len) {
        x = b;
        y = a;
    }

    k_mul: {
        if (y.len > karatsuba_threshold) {
            if (opt_allocator) |allocator| {
                const ov = llmulaccKaratsuba(op, allocator, r, x, y) catch |err| switch (err) {
                    error.OutOfMemory => break :k_mul, // handled below
                };
                return ov;
            }
        }
    }

    return llmulaccLong(op, r, x, y);
}

/// Karatsuba multiplication
/// Implementation of algorithm KaratsubaMultiply from "Modern Computer Arithmetic" by Richard P. Brent and Paul Zimmermann
fn llmulaccKaratsuba(comptime op: AccOp, allocator: std.mem.Allocator, C: []Limb, A: []const Limb, B: []const Limb) error{OutOfMemory}!bool {
    const n = A.len;
    const m = B.len;

    assert(C.len >= n);
    assert(n >= m);
    assert(!slicesOverlap(C, A));
    assert(!slicesOverlap(C, B));

    if (m <= karatsuba_threshold) {
        return llmulaccLong(op, C, A, B);
    }

    // tracks the number of time operations overflow
    var carry: i8 = 0;

    // balance the multiplication
    // with b = (2^@bitSizeOf(Limb))^m
    // A = A1 * b + A2    (A2 < b)
    //
    // therefore:
    // A*B = A2 * B  +  (A1 * B) * b
    if (n > m) {
        carry += @intFromBool(try llmulaccKaratsuba(op, allocator, C, A[0..m], B));
        carry += @intFromBool(if (n >= 2 * m)
            try llmulaccKaratsuba(op, allocator, C[m..], A[m..], B)
        else
            try llmulaccKaratsuba(op, allocator, C[m..], B, A[m..]));
        return carry != 0;
    }
    const k = std.math.divCeil(usize, m, 2) catch unreachable;

    const buffer = try allocator.alloc(Limb, 2 * k);
    defer allocator.free(buffer);

    const A0 = A[0..k];
    const A1 = A[k..];
    const B0 = B[0..k];
    const B1 = B[k..];

    const sA: i2 = switch (std.math.big.int.llcmp(A0, A1)) {
        .eq => 0,
        .gt => 1,
        .lt => -1,
    };
    const sB: i2 = switch (std.math.big.int.llcmp(B0, B1)) {
        .eq => 0,
        .gt => 1,
        .lt => -1,
    };
    const prod = sA * sB;

    @memset(buffer, 0);
    _ = try llmulaccKaratsuba(.add, allocator, buffer, A0, B0);
    carry += @intFromBool(llaccum(op, C, buffer));
    carry += @intFromBool(llaccum(op, C[k..], buffer));

    @memset(buffer, 0);
    _ = try llmulaccKaratsuba(.add, allocator, buffer, A1, B1);
    carry += @intFromBool(llaccum(op, C[k..], buffer[0 .. A1.len + B1.len]));
    carry += @intFromBool(llaccum(op, C[2 * k ..], buffer[0 .. A1.len + B1.len]));

    if (prod == 0)
        return carry != 0;

    const Asub = buffer[0..k];
    const Bsub = buffer[k..];

    // currently, llsubcarry is slower than llaccum since it doesn't use
    // inline assembly, so this is a workaround
    if (sA == 1) {
        @memcpy(Asub, A0);
        _ = llaccum(.sub, Asub, A1);
    } else {
        @memcpy(Asub[0..A1.len], A1);
        @memset(Asub[A1.len..], 0);
        _ = llaccum(.sub, Asub, A0);
    }
    if (sB == 1) {
        @memcpy(Bsub, B0);
        _ = llaccum(.sub, Bsub, B1);
    } else {
        @memcpy(Bsub[0..B1.len], B1);
        @memset(Bsub[B1.len..], 0);
        _ = llaccum(.sub, Bsub, B0);
    }

    const ov = if (prod == 1)
        try llmulaccKaratsuba(op.neg(), allocator, C[k..], Asub, Bsub)
    else
        try llmulaccKaratsuba(op, allocator, C[k..], Asub, Bsub);

    if (prod == 1)
        carry -= @intFromBool(ov)
    else
        carry += @intFromBool(ov);

    return carry != 0;
}

// Provides assembly for `llaccum` for x86_64
fn getllaccumAsm(comptime op: AccOp) []const u8 {
    assert(builtin.target.cpu.arch == .x86_64 and @sizeOf(Limb) == 8 and builtin.target.ofmt != .macho);
    @setEvalBranchQuota(3000);

    const addsub_small =
        // also clears CF
        \\ xor %%rbx, %%rbx
        \\ loop%=:
        \\   mov (%[a], %%rbx, 8), %%r9
        \\   $op %%r9, (%[r], %%rbx, 8)
        \\
        \\   inc %%rbx
        \\   dec %[n]
        \\   jnz loop%=
        \\
        \\ carry%=:
        \\   mov %[n2], %[n]
        \\ carryloop%=:
        \\   jnc end%=
        \\   dec %[n]
        \\   js end%=
        \\   $opq $0, (%[r], %%rbx, 8)
        \\
        \\   inc %%rbx
        \\   jmp carryloop%=
        \\
        \\ end%=:
        \\  setc %[carry]
    ;

    const addsub =
        \\ movb %[n:b], %%dl
        \\ xor %%rbx, %%rbx
        \\ and $3, %%dl
        \\ shr $2, %[n]
        \\ clc
        \\ jz unrolled%=
        \\ loop%=:
        \\   mov 0*8(%[a], %%rbx, 8), %%r9
        \\   $op %%r9, 0*8(%[r], %%rbx, 8)
        \\   mov 1*8(%[a], %%rbx, 8), %%r9
        \\   $op %%r9, 1*8(%[r], %%rbx, 8)
        \\   mov 2*8(%[a], %%rbx, 8), %%r9
        \\   $op %%r9, 2*8(%[r], %%rbx, 8)
        \\   mov 3*8(%[a], %%rbx, 8), %%r9
        \\   $op %%r9, 3*8(%[r], %%rbx, 8)
        \\
        \\   lea 4(%%rbx), %%rbx
        \\   dec %[n]
        \\   jnz loop%=
        \\
        \\ unrolled%=:
        \\   movb %%dl, %[n:b]
        \\   dec %[n]
        \\   js carry%=
        \\
        \\   mov (%[a], %%rbx, 8), %%r9
        \\   $op %%r9, (%[r], %%rbx, 8)
        \\   lea 1(%%rbx), %%rbx
        \\
        \\   dec %[n]
        \\   js carry%=
        \\
        \\   mov (%[a], %%rbx, 8), %%r9
        \\   $op %%r9, (%[r], %%rbx, 8)
        \\   lea 1(%%rbx), %%rbx
        \\
        \\   dec %[n]
        \\   js carry%=
        \\
        \\   mov (%[a], %%rbx, 8), %%r9
        \\   $op %%r9, (%[r], %%rbx, 8)
        \\   lea 1(%%rbx), %%rbx
        \\
        \\ carry%=:
        \\   mov %[n2], %[n]
        \\ carryloop%=:
        \\   jnc end%=
        \\   dec %[n]
        \\   js end%=
        // "$opq" => adcq or sbbq in AT&T syntax
        \\   $opq $0, (%[r], %%rbx, 8)
        \\
        \\   lea 1(%%rbx), %%rbx
        \\   jmp carryloop%=
        \\
        \\ end%=:
        \\  setc %[carry]
    ;

    const opcode = switch (op) {
        .add => "adc",
        .sub => "sbb",
    };
    const code = if (builtin.mode == .ReleaseSmall) addsub_small else addsub;
    var buffer: [code.len]u8 = undefined;
    @memcpy(&buffer, code);

    for (0..buffer.len) |i| {
        if (std.mem.startsWith(u8, buffer[i..], "$op"))
            @memcpy(buffer[i..][0..3], opcode);
    }

    return &buffer;
}

fn getllmulLimbAsm(comptime op: AccOp) []const u8 {
    assert(builtin.target.cpu.arch == .x86_64 and @sizeOf(Limb) == 8 and builtin.target.ofmt != .macho);
    @setEvalBranchQuota(10000);

    const mullimb =
        \\ mov %[n], %%rcx
        \\ and $3, %[n]
        \\ shr $2, %%rcx
        \\ lea (,%[n]), %%rbx
        \\ xor %r10, %r10
        // TODO: more effecient way to handle this ?
        \\ not     %[n:b]
        // clears CF
        \\ test    $3, %[n:b]
        \\ je      unrolled.3.%=
        \\ not     %[n:b]
        \\ shl     $6, %[n:b]
        \\ sar     $6, %[n:b]
        // clears CF
        \\ test    %[n:b], %[n:b]
        \\ js      unrolled.2.%=
        \\ jne     unrolled.1.%=
        \\ jmp     unrolled.0.%=
        \\ unrolled.3.%=:
        \\   mulx -3*8(%[y], %%rbx, 8), %%r11, %[carry]
        \\   adc %%r10, %%r11
        \\   adc $0, %[carry]
        \\   $op %%r11, -3*8(%[acc], %%rbx, 8)
        \\
        \\ unrolled.2.%=:
        \\   mulx -2*8(%[y], %%rbx, 8), %%r9, %%r10
        \\   adc %[carry], %%r9
        \\   adc $0, %%r10
        \\   $op %%r9, -2*8(%[acc], %%rbx, 8)
        \\
        \\ unrolled.1.%=:
        \\   mulx -1*8(%[y], %%rbx, 8), %%r11, %[carry]
        \\   adc %%r10, %%r11
        \\   adc $0, %[carry]
        \\   $op %%r11, -1*8(%[acc], %%rbx, 8)
        \\
        \\ unrolled.0.%=:
        \\   jrcxz end%=
        \\
        \\ loop%=:
        \\   mulx 0*8(%[y], %%rbx, 8), %%r9, %%r10
        \\   adc %[carry], %%r9
        \\   adc $0, %%r10
        \\   $op %%r9, 0*8(%[acc], %%rbx, 8)
        \\
        \\   mulx 1*8(%[y], %%rbx, 8), %%r11, %[carry]
        \\   adc %%r10, %%r11
        \\   adc $0, %[carry]
        \\   $op %%r11, 1*8(%[acc], %%rbx, 8)
        \\
        \\   mulx 2*8(%[y], %%rbx, 8), %%r9, %%r10
        \\   adc %[carry], %%r9
        \\   adc $0, %%r10
        \\   $op %%r9, 2*8(%[acc], %%rbx, 8)
        \\
        \\   mulx 3*8(%[y], %%rbx, 8), %%r11, %[carry]
        \\   adc %%r10, %%r11
        \\   adc $0, %[carry]
        \\   $op %%r11, 3*8(%[acc], %%rbx, 8)
        \\
        \\
        \\   lea 4(%%rbx), %%rbx
        \\   dec %%rcx
        \\   jnz loop%=
        \\
        \\ end%=:
        \\   adc $0, %[carry]
    ;
    const mullimb_small =
        \\ mov %[n], %%rcx
        // also clears CF and OF
        \\ xor %%rbx, %%rbx
        \\
        \\ loop%=:
        \\   mulx (%[y], %%rbx, 8), %%r9, %%r10
        \\   adc %[carry], %%r9
        \\   adc $0, %%r10
        \\   $op %%r9, (%[acc], %%rbx, 8)
        \\
        \\   mov %%r10, %[carry]
        \\   lea 1(%%rbx), %%rbx
        \\   dec %%rcx
        \\   jnz loop%=
        \\
        \\ end%=:
        \\   adc $0, %[carry]
    ;

    const mullimb_adx =
        \\ mov %[n], %%rcx
        \\ and $3, %[n]
        \\ shr $2, %%rcx
        \\ lea (,%[n]), %%rbx
        \\
        \\ xor %r10, %r10
        // TODO: more effecient way to handle this ?
        \\ not     %[n:b]
        // clears CF and OF
        \\ test    $3, %[n:b]
        \\ je      unrolled.3.%=
        \\ not     %[n:b]
        \\ shl     $6, %[n:b]
        \\ sar     $6, %[n:b]
        // clears CF and OF
        \\ test    %[n:b], %[n:b]
        \\ js      unrolled.2.%=
        \\ jne     unrolled.1.%=
        \\ jmp     unrolled.0.%=
        \\
        \\ unrolled.3.%=:
        \\   mulx -3*8(%[y], %%rbx, 8), %%r11, %[carry]
        \\   adcx %%r10, %%r11
        \\   adox -3*8(%[acc], %%rbx, 8), %%r11
        \\   mov %%r11, -3*8(%[acc], %%rbx, 8)
        \\
        \\ unrolled.2.%=:
        \\   mulx -2*8(%[y], %%rbx, 8), %%r9, %%r10
        \\   adcx %[carry], %%r9
        \\   adox -2*8(%[acc], %%rbx, 8), %%r9
        \\   mov %%r9, -2*8(%[acc], %%rbx, 8)
        \\
        \\ unrolled.1.%=:
        \\   mulx -1*8(%[y], %%rbx, 8), %%r11, %[carry]
        \\   adcx %%r10, %%r11
        \\   adox -1*8(%[acc], %%rbx, 8), %%r11
        \\   mov %%r11, -1*8(%[acc], %%rbx, 8)
        \\
        \\ unrolled.0.%=:
        \\  jrcxz end%=
        \\
        \\ loop%=:
        \\   mulx 0*8(%[y], %%rbx, 8), %%r9, %%r10
        \\   adcx %[carry], %%r9
        \\   adox 0*8(%[acc], %%rbx, 8), %%r9
        \\   mov %%r9, 0*8(%[acc], %%rbx, 8)
        \\
        \\
        \\   mulx 1*8(%[y], %%rbx, 8), %%r11, %[carry]
        \\   adcx %%r10, %%r11
        \\   adox 1*8(%[acc], %%rbx, 8), %%r11
        \\   mov %%r11, 1*8(%[acc], %%rbx, 8)
        \\
        \\
        \\   mulx 2*8(%[y], %%rbx, 8), %%r9, %%r10
        \\   adcx %[carry], %%r9
        \\   adox 2*8(%[acc], %%rbx, 8), %%r9
        \\   mov %%r9, 2*8(%[acc], %%rbx, 8)
        \\
        \\
        \\   mulx 3*8(%[y], %%rbx, 8), %%r11, %[carry]
        \\   adcx %%r10, %%r11
        \\   adox 3*8(%[acc], %%rbx, 8), %%r11
        \\   mov %%r11, 3*8(%[acc], %%rbx, 8)
        \\
        \\   lea 4(%%rbx), %%rbx
        \\   lea -1(%%rcx), %%rcx
        \\   jrcxz end%=
        \\   jmp loop%=
        \\
        \\ end%=:
        // rcx is 0
        \\   adcx %%rcx, %[carry]
        \\   adox %%rcx, %[carry]
    ;
    const mullimb_adx_small =
        \\ mov %[n], %%rcx
        // clears CF and OF
        \\ xor %%rbx, %%rbx
        \\
        \\ loop%=:
        \\   mulx (%[y], %%rbx, 8), %%r9, %%r10
        \\   adcx %[carry], %%r9
        \\   adox (%[acc], %%rbx, 8), %%r9
        \\   mov %%r9, (%[acc], %%rbx, 8)
        \\
        \\   mov %%r10, %[carry]
        \\   lea 1(%%rbx), %%rbx
        \\   lea -1(%%rcx), %%rcx
        \\   jrcxz end%=
        \\   jmp loop%=
        \\
        \\ end%=:
        // rcx is 0
        \\   adcx %%rcx, %[carry]
        \\   adox %%rcx, %[carry]
    ;
    const code = blk: {
        if (op == .add and std.Target.x86.featureSetHas(builtin.cpu.features, .adx)) {
            break :blk if (builtin.mode == .ReleaseSmall) mullimb_adx_small else mullimb_adx;
        }
        break :blk if (builtin.mode == .ReleaseSmall) mullimb_small else mullimb;
    };

    if (mem.indexOf(u8, code, "$op") == null) return code;

    const opcode = switch (op) {
        .add => "add",
        .sub => "sub",
    };

    var buffer: [code.len]u8 = undefined;
    @memcpy(&buffer, code);

    for (0..buffer.len) |i| {
        if (std.mem.startsWith(u8, buffer[i..], "$op"))
            @memcpy(buffer[i..][0..3], opcode);
    }
    return &buffer;
}

/// r = r (op) a.
/// The result is computed modulo `r.len`.
fn llaccum(comptime op: AccOp, r: []Limb, a: []const Limb) bool {
    assert(!slicesOverlap(r, a) or @intFromPtr(r.ptr) <= @intFromPtr(a.ptr));

    if (a.len == 0) return false;

    if (builtin.target.cpu.arch == .x86_64 and builtin.zig_backend != .stage2_x86_64 and builtin.zig_backend != .stage2_c and @sizeOf(Limb) == 8 and builtin.target.ofmt != .macho) {
        var carry: bool = false;
        // since we use `n` as a counter, this variable will be modified by the
        // assembly. Putting it as an output avoid the need to restore it at the end
        // (inputs are assumed to not change)
        var tmp = @min(r.len, a.len);

        asm volatile (getllaccumAsm(op)
            : [carry] "=&{dl}" (carry),
              [n] "+r" (tmp),
            : [n2] "r" (if (r.len >= a.len) r.len - a.len else 0),
              [r] "r" (@intFromPtr(r.ptr)),
              [a] "r" (@intFromPtr(a.ptr)),
            : "rbx", "r9", "cc", "memory"
        );

        return carry;
    }

    return llaccumGeneric(op, r, a);
}

fn llaccumGeneric(comptime op: AccOp, r: []Limb, a: []const Limb) bool {
    if (r.len < a.len) return llaccumGeneric(op, r, a[0..r.len]);
    if (a.len == 0) return false;
    if (op == .sub)
        return llsubcarry(r, r, a) != 0;

    var i: usize = 0;
    var carry: Limb = 0;

    while (i < a.len) : (i += 1) {
        const ov1 = @addWithOverflow(r[i], a[i]);
        r[i] = ov1[0];
        const ov2 = @addWithOverflow(r[i], carry);
        r[i] = ov2[0];
        carry = @as(Limb, ov1[1]) + ov2[1];
    }

    while ((carry != 0) and i < r.len) : (i += 1) {
        const ov = @addWithOverflow(r[i], carry);
        r[i] = ov[0];
        carry = ov[1];
    }

    return carry != 0;
}

/// Returns .lt, .eq, .gt if |a| < |b|, |a| == |b| or |a| > |b| respectively for limbs.
pub fn llcmp(a: []const Limb, b: []const Limb) math.Order {
    const a_len = llnormalize(a);
    const b_len = llnormalize(b);
    if (a_len < b_len) {
        return .lt;
    }
    if (a_len > b_len) {
        return .gt;
    }

    var i: usize = a_len - 1;
    while (i != 0) : (i -= 1) {
        if (a[i] != b[i]) {
            break;
        }
    }

    if (a[i] < b[i]) {
        return .lt;
    } else if (a[i] > b[i]) {
        return .gt;
    } else {
        return .eq;
    }
}

/// r = r (op) y * xi
/// returns whether the operation overflowed
/// The result is computed modulo `r.len`.
fn llmulaccLong(comptime op: AccOp, r: []Limb, a: []const Limb, b: []const Limb) bool {
    assert(r.len >= a.len);
    assert(a.len >= b.len);

    var i: usize = 0;
    var overflows = false;
    while (i < b.len) : (i += 1) {
        overflows = llmulLimb(op, r[i..], a, b[i]) or overflows;
    }

    return overflows;
}

/// r = r (op) y * xi
/// Returns whether the operation overflowed.
/// If y.len > acc.len, it assumes some of the remaining limbs are non-zero and always overflows
//
// usually, if y.len > acc.len, the caller wants a modular operation, and therefore does not care
// about the overflow anyway
fn llmulLimb(comptime op: AccOp, acc: []Limb, y: []const Limb, xi: Limb) bool {
    assert(!slicesOverlap(acc, y) or @intFromPtr(acc.ptr) <= @intFromPtr(y.ptr));

    if (y.len == 0) return false;
    if (xi == 0) return false;

    if (builtin.target.cpu.arch == .x86_64 and builtin.zig_backend != .stage2_x86_64 and builtin.zig_backend != .stage2_c and @sizeOf(Limb) == 8 and builtin.target.ofmt != .macho) {
        var carry: Limb = 0;
        // since we use `n` as a counter, this variable will be modified by the
        // assembly. Putting it as an output avoid the need to restore it at the end
        // (inputs are assumed to not change)
        var tmp = @min(acc.len, y.len);

        asm volatile (getllmulLimbAsm(op)
            : [carry] "+r" (carry),
              [n] "+r" (tmp),
              // rdx is necessary for mulx
            : [xi] "{rdx}" (xi),
              [acc] "r" (@intFromPtr(acc.ptr)),
              [y] "r" (@intFromPtr(y.ptr)),
            : "rcx", "rbx", "r9", "r10", "r11", "cc", "memory"
        );

        if (carry != 0 and acc.len > y.len)
            carry = @intFromBool(llaccum(op, acc[y.len..], &.{carry}));

        return carry != 0 or y.len > acc.len;
    }

    return llmulLimbGeneric(op, acc, y, xi);
}

fn llmulLimbGeneric(comptime op: AccOp, acc: []Limb, y: []const Limb, xi: Limb) bool {
    if (xi == 0) {
        return false;
    }

    const split = @min(y.len, acc.len);
    var a_lo = acc[0..split];
    var a_hi = acc[split..];

    switch (op) {
        .add => {
            var carry: Limb = 0;
            var j: usize = 0;

            while (j < a_lo.len) : (j += 1) {
                const mul = math.mulWide(Limb, xi, y[j]) + carry;
                const mul_lo: Limb = @truncate(mul);
                const mul_hi: Limb = @truncate(mul >> @bitSizeOf(Limb));

                const overflows: u1 = @intFromBool(a_lo[j] > math.maxInt(Limb) - mul_lo);

                a_lo[j] +%= mul_lo;
                carry = mul_hi + overflows;
            }

            j = 0;
            while ((carry != 0) and (j < a_hi.len)) : (j += 1) {
                const ov = @intFromBool(carry > math.maxInt(Limb) - a_hi[j]);
                a_hi[j] +%= carry;
                carry = ov;
            }

            return carry != 0;
        },
        .sub => {
            var borrow: Limb = 0;
            var j: usize = 0;

            while (j < a_lo.len) : (j += 1) {
                const mul = math.mulWide(Limb, xi, y[j]) + borrow;
                const mul_lo: Limb = @truncate(mul);
                const mul_hi: Limb = @truncate(mul >> @bitSizeOf(Limb));

                const overflows: u1 = @intFromBool(mul_lo > a_lo[j]);

                a_lo[j] -%= mul_lo;
                borrow = mul_hi + overflows;
            }

            j = 0;
            while ((borrow != 0) and (j < a_hi.len)) : (j += 1) {
                const ov = @intFromBool(borrow > a_hi[j]);
                a_hi[j] -%= borrow;
                borrow = ov;
            }

            return borrow != 0;
        },
    }
}

/// returns the min length the limb could be.
fn llnormalize(a: []const Limb) usize {
    var j = a.len;
    while (j > 0) : (j -= 1) {
        if (a[j - 1] != 0) {
            break;
        }
    }

    // Handle zero
    return if (j != 0) j else 1;
}

/// Knuth 4.3.1, Algorithm S.
fn llsubcarry(r: []Limb, a: []const Limb, b: []const Limb) Limb {
    assert(a.len != 0 and b.len != 0);
    assert(a.len >= b.len);
    assert(r.len >= a.len);
    assert(!slicesOverlap(r, a) or @intFromPtr(r.ptr) <= @intFromPtr(a.ptr));
    assert(!slicesOverlap(r, b) or @intFromPtr(r.ptr) <= @intFromPtr(b.ptr));

    var i: usize = 0;
    var borrow: Limb = 0;

    while (i < b.len) : (i += 1) {
        const ov1 = @subWithOverflow(a[i], b[i]);
        r[i] = ov1[0];
        const ov2 = @subWithOverflow(r[i], borrow);
        r[i] = ov2[0];
        borrow = @as(Limb, ov1[1]) + ov2[1];
    }

    while (i < a.len) : (i += 1) {
        const ov = @subWithOverflow(a[i], borrow);
        r[i] = ov[0];
        borrow = ov[1];
    }

    return borrow;
}

fn llsub(r: []Limb, a: []const Limb, b: []const Limb) void {
    assert(a.len > b.len or (a.len == b.len and a[a.len - 1] >= b[b.len - 1]));
    assert(llsubcarry(r, a, b) == 0);
}

/// Knuth 4.3.1, Algorithm A.
fn lladdcarry(r: []Limb, a: []const Limb, b: []const Limb) Limb {
    assert(a.len != 0 and b.len != 0);
    assert(a.len >= b.len);
    assert(r.len >= a.len);
    assert(!slicesOverlap(r, a) or @intFromPtr(r.ptr) <= @intFromPtr(a.ptr));
    assert(!slicesOverlap(r, b) or @intFromPtr(r.ptr) <= @intFromPtr(b.ptr));

    var i: usize = 0;
    var carry: Limb = 0;

    while (i < b.len) : (i += 1) {
        const ov1 = @addWithOverflow(a[i], b[i]);
        r[i] = ov1[0];
        const ov2 = @addWithOverflow(r[i], carry);
        r[i] = ov2[0];
        carry = @as(Limb, ov1[1]) + ov2[1];
    }

    while (i < a.len) : (i += 1) {
        const ov = @addWithOverflow(a[i], carry);
        r[i] = ov[0];
        carry = ov[1];
    }

    return carry;
}

fn lladd(r: []Limb, a: []const Limb, b: []const Limb) void {
    assert(r.len >= a.len + 1);
    r[a.len] = lladdcarry(r, a, b);
}

/// Algorithm UnbalancedDivision from "Modern Computer Arithmetic" by Richard P. Brent and Paul Zimmermann
///
/// `q` = `a` / `b` rem `r`
///
/// Normalization and unnormalization steps are handled by the caller.
/// `r` is written in `a[0..b.len]` (`a[b.len..]` is NOT zeroed out).
/// The most significant limbs of `a` (input) can be zeroes.
///
/// requires:
/// - `b.len` >= 2
/// - `a.len` >= 3
/// - `a.len` >= `b.len`
/// - `b` must be normalized (most significant bit of `b[b.len - 1]` must be set)
/// - `q.len >= calcDivQLenExact(a, b)` (the quotient must be able to fit in `q`)
///   a valid bound for q can be obtained more cheaply using `calcDivQLen`
/// - no overlap between q, a and b
fn unbalancedDivision(q: []Limb, a: []Limb, b: []const Limb, allocator: std.mem.Allocator) void {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        assert(!slicesOverlap(q, a));
        assert(!slicesOverlap(q, b));
        assert(!slicesOverlap(a, b));
        assert(b.len >= 2);
        assert(a.len >= 3);
        assert(a.len >= b.len);
        assert(q.len >= calcDivQLenExact(a, b));
        // b must be normalized
        assert(@clz(b[b.len - 1]) == 0);
    }
    const n = b.len;
    var m = a.len - b.len;

    // We slightly deviate from the paper, by allowing `m <= n`, and, instead of doing a division after
    // the loop, we do it before, in case the quotient takes up m - n + 1 Limbs.
    // For the next loops, the quotient is always guaranteed to fit in n Limbs.
    //
    // `q.len` may be only m limbs instead of m + 1 if the caller know the result will fit
    // (which has already been asserted).
    const k = m % n;
    balance: {
        // balance the first division step

        const Q = q[m - k .. @min(m + 1, q.len)];
        const A = a[m - k .. m + n];
        const M = A.len - n;

        if (M < recursive_division_threshold)
            break :balance basecaseDivRem(Q, A, b);

        // we compute an approximation of q using the 2*M most significant limbs of a
        // and the M most significant limbs of b, and we then correct q
        // we do this because recursiveDivRem can be extremely inefficient when
        // a and b are about the same size, and is most efficient when a.len = 2*b.len

        recursiveDivRem(Q, A[A.len - 2 * M ..], b[b.len - M ..], allocator);

        var a_is_negative = llmulacc(.sub, allocator, A, Q, b[0 .. b.len - M]);

        while (a_is_negative) {
            _ = llaccum(.sub, Q, &.{1});
            a_is_negative = !llaccum(.add, A, b);
        }
    }
    m -= k;

    while (m > 0) {
        // At each loop, we divide <r, a[m - n .. m]> by `b`, with r = a[m .. m + n],
        // the remainder from the previous loop. This is effectively a 2 word by 1 word division,
        // except each word is n Limbs long. The process is analogous to `lldiv1`.
        //
        // The quotient is guaranteed to fit in `n` Limbs since r < b (from the previous iteration).
        recursiveDivRem(q[m - n .. m], a[m - n .. m + n], b, allocator);
        m -= n;
    }
}

/// Algorithm RecursiveDivRem from "Modern Computer Arithmetic" by Richard P. Brent and Paul Zimmermann
///
/// `q` = `a` / `b` rem `r`
///
/// Normalization and unnormalization steps are handled by the caller.
/// `r` is written in `a[0..b.len]` (`a[b.len..]` is NOT zeroed out).
/// The most significant limbs of `a` (input) can be zeroes.
///
/// requires:
/// - `b.len` >= 2
/// - `a.len` >= 3
/// - `a.len` >= `b.len` and 2 * `b.len` >= `a.len`
/// - `b` must be normalized (most significant bit of `b[b.len - 1]` must be set)
/// - `q.len >= calcDivQLenExact(a, b)` (the quotient must be able to fit in `q`)
///   a valid bound for q can be obtained more cheaply using `calcDivQLen`
/// - no overlap between q, a and b
///
/// This function can be extremely inefficient when a and b are about the same size,
/// and is most efficient when a.len = 2*b.len. If this is not the case, balancing the
/// division (as done in unbalancedDivision before the loop) is advised.
fn recursiveDivRem(q: []Limb, a: []Limb, b: []const Limb, allocator: std.mem.Allocator) void {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        assert(!slicesOverlap(q, a));
        assert(!slicesOverlap(q, b));
        assert(!slicesOverlap(a, b));
        assert(b.len >= 2);
        assert(a.len >= 3);
        assert(a.len >= b.len);
        // n >= m
        assert(2 * b.len >= a.len);
        assert(q.len >= std.math.big.int.calcDivQLenExact(a, b));
        // b must be normalized
        assert(@clz(b[b.len - 1]) == 0);
        assert(recursive_division_threshold > 2);
    }

    const n = b.len;
    const m = a.len - n;

    if (m < recursive_division_threshold) return basecaseDivRem(q, a, b);

    const k = m / 2;

    const b0 = b[0..k];
    const b1 = b[k..];
    const q1 = q[k..@min(q.len, m + 1)];
    const q0 = q[0..k];

    // It is possible to reduce the probability of `a_is_negative`
    // by adding a Limb to a[2*k..] and b[k..]. In practice, I did not
    // see any meaningful speed difference
    recursiveDivRem(q1, a[2 * k ..], b1, allocator);

    // Step 4:
    // - A mod B^2k is just a[0..2*k], which is left untouched after the recursive call
    // - R1 B^2k is already written into a[2*k..] by the recursive call
    // we only need to subtract Q1 B0 B^k

    // we have i <= m + 1 + k = a.len - n + k + 1
    // and k + 1 < m <= n since m >= recursive_division_threshold > 2
    // therefore k + 1 - n < 0, so i < a.len
    const i = q1.len + b0.len + k;
    var a_is_negative = llmulacc(.sub, allocator, a[k .. i + 1], q1, b0);

    while (a_is_negative) {
        _ = llaccum(.sub, q1, &.{1});
        a_is_negative = !llaccum(.add, a[k .. i + 1], b);
    }

    recursiveDivRem(q0, a[k..][0..n], b1, allocator);

    // Step 7.
    a_is_negative = llmulacc(.sub, allocator, a[0 .. 2 * k + 1], q0, b0);

    while (a_is_negative) {
        _ = llaccum(.sub, q0, &.{1});
        a_is_negative = !llaccum(.add, a[0 .. 2 * k + 1], b);
    }
}

/// Algorithm BasecaseDivRem from "Modern Computer Arithmetic" by Richard P. Brent and Paul Zimmermann
/// modified to use Algorithm 5 from "Improved division by invariant integers"
/// by Niels Möller and Torbjörn Granlund
///
/// `q` = `a` / `b` rem `r`
///
/// Normalization and unnormalization steps are handled by the caller.
/// `r` is written in `a[0..b.len]` (`a[b.len..]` is NOT zeroed out).
/// `q` is written in `q[0..a.len - b.len + 1]`, but may needs to be normalized afterwards using `llnormalize`.
/// The most significant limbs of `a` (input) can be zeroes.
///
/// requires:
/// - `b.len` >= 2
/// - `a.len` >= 3
/// - `b` must be normalized (most significant bit of `b[b.len - 1]` must be set)
/// - `q.len >= calcDivQLenExact(a, b)` (the quotient must be able to fit in `q`)
///   a valid bound for q can be obtained more cheaply using `calcDivQLen`
/// - no overlap between q, a and b
// note: it is probably possible to make a and q overlap, by having q = a[m..a.len+1]
// but not sure if it is worth it
fn basecaseDivRem(q: []Limb, a: []Limb, b: []const Limb) void {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        assert(!slicesOverlap(q, a));
        assert(!slicesOverlap(q, b));
        assert(!slicesOverlap(a, b));
        assert(b.len >= 2);
        assert(a.len >= 3);
        assert(q.len >= calcDivQLenExact(a, b));
        assert(a.len >= b.len);
        // b must be normalized
        assert(@clz(b[b.len - 1]) == 0);
    }

    const n = b.len;
    const m = a.len - n;

    // Step 1.
    if (llcmp(a[m..], b).compare(.gte)) {
        q[m] = 1;
        _ = llaccum(.sub, a[m..], b);
    } else {
        if (q.len >= m + 1)
            q[m] = 0;
    }

    // reciprocal of the two highest limbs of b
    // used for fast division
    const binv = reciprocalWord3by2(b[n - 1], b[n - 2]);

    for (0..m) |i| {
        const j = m - 1 - i;

        // `div3by2` requires the quotient `q` to fit in a single Limb
        // this requires <a[n+j], a[n+j-1]>  <  <b[n-1], b[n-2]>
        // (with <x, y> = (x << limb_bits) + y)
        // but at each loop iteration, we only have <a[n+j], a[n+j-1]>  <=  <b[n-1], b[n-2]>
        // therefore, a special case must be made in case of equality
        //
        // note that having <a[n+j], a[n+j-1]>  >  <b[n-1], b[n-2]> is impossible since it would mean
        // q[j+1] (from the last iteration, or from Step 1.) is incorrect (as it would be at least 1 too small)
        if (a[n + j] == b[n - 1] and a[n + j - 1] == b[n - 2]) {
            @branchHint(.unlikely);
            q[j] = maxInt(Limb);
            const underflows = llmulLimb(.sub, a[j .. j + n + 1], b, q[j]);

            assert(!underflows);

            continue;
        }

        // Step 3.
        // modified to divide 3 words by 2 words
        // q is therefore at most one off, with low probability
        q[j] = div3by2(a[n + j], a[n + j - 1], a[n + j - 2], b[n - 1], b[n - 2], binv).q;

        // Step 5.
        // note: It is possible to avoid 2 iteration from this function by using the remainder from Step 3.
        const a_is_negative = llmulLimb(.sub, a[j .. j + n + 1], b, q[j]);

        // Step 6.
        if (a_is_negative) {
            @branchHint(.unlikely);
            q[j] -= 1;
            const overflows = llaccum(.add, a[j .. j + n + 1], b);

            assert(overflows);
        }
    }
}

/// Algorithm 7 from "Improved division by invariant integers"
/// by Niels Möller and Torbjörn Granlund
///
/// Performs `q` = `a` / `b` rem `r`   with `b` a single word
/// `r` is returned
/// `q` may overlap `a`
///
/// Requires:
/// - b to be normalized (its most significant bit must be set)
/// - the quotient must be able to fit in `q`
fn lldiv1(q: []Limb, a: []Limb, b: Limb) Limb {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        assert(q.len >= calcDivQLenExact(a, &.{b}));
        // b must be normalized
        assert(@clz(b) == 0);
        assert(!slicesOverlap(q, a) or @intFromPtr(q.ptr) >= @intFromPtr(a.ptr));
    }

    const n = a.len;

    const v = reciprocalWord(b);
    var r: Limb = 0;

    // in the event where q has exactly the required len
    // and the first iteration of the loop returns 0, q cannot fit that 0
    // the first iteration of the loop is therefore done beforehand,
    // with a bound check on q
    {
        const result = div2by1(r, a[n - 1], b, v);

        // q has already been asserted to be large enough if result.q is non-zero
        if (q.len >= a.len)
            q[n - 1] = result.q;
        r = result.r;
    }

    for (0..n - 1) |i| {
        const j = n - 2 - i;
        const result = div2by1(r, a[j], b, v);

        q[j] = result.q;
        r = result.r;
    }
    return r;
}

/// Algorithm 2 of "Improved division by invariant integers"
/// by Niels Möller and Torbjörn Granlund
///
/// Computes `q` and `r` verifying `U = q*d + r` (`q` = `U` / `d` and `r` = `U` % `d`)
/// with `d` = <`d1`, `d0`> (`d1` being the most significant part of `d`)
/// and similarly `U` = <`U2`, `U1`, `U0`>
///
/// `d` must be normalized (most significant bit set)
/// `v` is computed from `d` using `reciprocal_word_3by2`
///
/// `r` is returned in big endian (`r[0]` is the high part of `r` and `r[1]` is its low one)
fn div3by2(U2: Limb, U1: Limb, U0: Limb, d1: Limb, d0: Limb, v: Limb) struct { q: Limb, r: [2]Limb } {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        assert(@clz(d1) == 0);
        assert(order2(U2, U1, d1, d0) == .lt);
        assert(v == reciprocalWord3by2(d1, d0));
    }

    var q1, var q0 = umul(v, U2);
    q1, q0 = add2(q1, q0, U2, U1);
    var r1 = U1 -% q1 *% d1;

    const t1, const t0 = umul(d0, q1);
    r1, var r0 = sub2(r1, U0, d1, d0);
    r1, r0 = sub2(r1, r0, t1, t0);

    q1 +%= 1;

    // branch free, as advised by the paper
    // not sure if it is necessary / worth it
    const gt: u1 = @intFromBool(r1 >= q0);
    q1 -%= gt;
    r1, r0 = add2(r1, r0, d1 * gt, d0 * gt);

    if (order2(r1, r0, d1, d0).compare(.gte)) {
        @branchHint(.unlikely);
        q1 +%= 1;
        r1, r0 = sub2(r1, r0, d1, d0);
    }

    return .{ .q = q1, .r = [2]Limb{ r1, r0 } };
}

/// Algorithm 4 of "Improved division by invariant integers"
/// by Niels Möller and Torbjörn Granlund
///
/// Performs `q` = <`U1`, `U0`> / `d` rem `r`
/// (with <U1, U0> = (U1 << @bitSizeOf(T)) + U0)
///
/// `v` is the precomputed reciprocal of `d` (obtained with `reciprocalWord`)
/// `q` must fit in a single word (therefore `U1` < `d`)
fn div2by1(U1: Limb, U0: Limb, d: Limb, v: Limb) struct { q: Limb, r: Limb } {
    if (builtin.mode == .Debug or builtin.mode == .ReleaseSafe) {
        assert(U1 < d);
        // d is must be normalized
        assert(@clz(d) == 0);
        assert(v == reciprocalWord(d));
    }

    var q1, var q0 = umul(v, U1);
    q1, q0 = add2(q1, q0, U1, U0);

    q1 +%= 1;
    var r = U0 -% q1 *% d;

    const cond: u1 = @intFromBool(r > q0);
    q1 -%= cond;
    r +%= d * cond;

    if (r >= d) {
        @branchHint(.unlikely);
        q1 += 1;
        r -= d;
    }

    return .{ .q = q1, .r = r };
}

// returns as big endian
fn umul(a: Limb, b: Limb) [2]Limb {
    const r = math.mulWide(Limb, a, b);
    return [2]Limb{ @truncate(r >> @bitSizeOf(Limb)), @truncate(r) };
}

// returns as big endian
fn add2(ahi: Limb, alo: Limb, bhi: Limb, blo: Limb) [2]Limb {
    const rlo = @addWithOverflow(alo, blo);
    const rhi = @addWithOverflow(ahi, rlo[1]);
    return [2]Limb{ rhi[0] +% bhi, rlo[0] };
}

// returns as big endian
fn sub2(ahi: Limb, alo: Limb, bhi: Limb, blo: Limb) [2]Limb {
    const rlo = @subWithOverflow(alo, blo);
    const rhi = @subWithOverflow(ahi, rlo[1]);
    return [2]Limb{ rhi[0] -% bhi, rlo[0] };
}

fn order2(ahi: Limb, alo: Limb, bhi: Limb, blo: Limb) math.Order {
    const ord1 = math.order(ahi, bhi);
    if (ord1 != .eq)
        return ord1;
    return math.order(alo, blo);
}

/// Algorithm 6 of "Improved division by invariant integers"
/// by Niels Möller and Torbjörn Granlund
///
/// Computes (B^3 - 1) / d - B, with B = 2^@bitSizeOf(T) and d = d1 * B + d0
/// `d` (therefore `d1`) must be normalized
fn reciprocalWord3by2(d1: Limb, d0: Limb) Limb {
    assert(@clz(d1) == 0);

    var v = reciprocalWord(d1);
    var p = d1 *% v;
    p +%= d0;
    if (p < d0) {
        v -%= 1;
        if (p >= d1) {
            v -%= 1;
            p -%= d1;
        }
        p -%= d1;
    }
    const t1, const t0 = umul(v, d0);
    p +%= t1;
    if (p < t1) {
        v -%= 1;
        if (order2(p, t0, d1, d0).compare(.gte)) {
            v -%= 1;
        }
    }

    return v;
}

/// Computes (B^2 - 1) / d - B, with B = 2^@bitSizeOf(T)
/// d must be normalized (most significant bit set)
fn reciprocalWord(d: Limb) Limb {
    assert(@clz(d) == 0);
    // same as computing <B - 1 - d, B - 1> / d
    // which is the same as <~d, B - 1> / d
    if (@import("builtin").cpu.arch == .x86_64 and @sizeOf(Limb) == 8) {
        var rem: Limb = undefined;
        // we avoid calling __udivti3
        return asm (
            \\divq %[v]
            : [_] "={rax}" (-> Limb),
              [_] "={rdx}" (rem),
            : [v] "r" (d),
              [_] "{rax}" (maxInt(Limb)),
              [_] "{rdx}" (~d),
        );
    }

    return @truncate(((@as(DoubleLimb, ~d) << @bitSizeOf(Limb)) | maxInt(Limb)) / d);
}

/// Performs r = a << shift and returns the amount of limbs affected
///
/// if a and r overlaps, then r.ptr >= a.ptr is asserted
/// r must have the capacity to store a << shift
fn llshl(r: []Limb, a: []const Limb, shift: usize) usize {
    assert(a.len >= 1);
    assert(!slicesOverlap(a, r) or @intFromPtr(r.ptr) >= @intFromPtr(a.ptr));

    if (shift == 0) {
        if (a.ptr != r.ptr)
            std.mem.copyBackwards(Limb, r[0..a.len], a);
        return a.len;
    }
    if (shift >= limb_bits) {
        const limb_shift = shift / limb_bits;

        const affected = llshl(r[limb_shift..], a, shift % limb_bits);
        @memset(r[0..limb_shift], 0);

        return limb_shift + affected;
    }

    // shift is guaranteed to be < limb_bits
    const bit_shift: Log2Limb = @truncate(shift);
    const opposite_bit_shift: Log2Limb = @truncate(limb_bits - bit_shift);

    // We only need the extra limb if the shift of the last element overflows.
    // This is useful for the implementation of `shiftLeftSat`.
    const overflows = a[a.len - 1] >> opposite_bit_shift != 0;
    if (overflows) {
        std.debug.assert(r.len >= a.len + 1);
    } else {
        std.debug.assert(r.len >= a.len);
    }

    var i: usize = a.len;
    if (overflows) {
        // r is asserted to be large enough above
        r[a.len] = a[a.len - 1] >> opposite_bit_shift;
    }
    while (i > 1) {
        i -= 1;
        r[i] = (a[i - 1] >> opposite_bit_shift) | (a[i] << bit_shift);
    }
    r[0] = a[0] << bit_shift;

    return a.len + @intFromBool(overflows);
}

/// Performs r = a >> shift and returns the amount of limbs affected
///
/// if a and r overlaps, then r.ptr <= a.ptr is asserted
/// r must have the capacity to store a >> shift
///
/// See tests below for examples of behaviour
fn llshr(r: []Limb, a: []const Limb, shift: usize) usize {
    assert(!slicesOverlap(a, r) or @intFromPtr(r.ptr) <= @intFromPtr(a.ptr));

    if (a.len == 0) return 0;

    if (shift == 0) {
        std.debug.assert(r.len >= a.len);

        if (a.ptr != r.ptr)
            std.mem.copyForwards(Limb, r[0..a.len], a);
        return a.len;
    }
    if (shift >= limb_bits) {
        if (shift / limb_bits >= a.len) {
            r[0] = 0;
            return 1;
        }
        return llshr(r, a[shift / limb_bits ..], shift % limb_bits);
    }

    // shift is guaranteed to be < limb_bits
    const bit_shift: Log2Limb = @truncate(shift);
    const opposite_bit_shift: Log2Limb = @truncate(limb_bits - bit_shift);

    // special case, where there is a risk to set r to 0
    if (a.len == 1) {
        r[0] = a[0] >> bit_shift;
        return 1;
    }
    if (a.len == 0) {
        r[0] = 0;
        return 1;
    }

    // if the most significant limb becomes 0 after the shift
    const shrink = a[a.len - 1] >> bit_shift == 0;
    std.debug.assert(r.len >= a.len - @intFromBool(shrink));

    var i: usize = 0;
    while (i < a.len - 1) : (i += 1) {
        r[i] = (a[i] >> bit_shift) | (a[i + 1] << opposite_bit_shift);
    }

    if (!shrink)
        r[i] = a[i] >> bit_shift;

    return a.len - @intFromBool(shrink);
}

// r = ~r
fn llnot(r: []Limb) void {
    for (r) |*elem| {
        elem.* = ~elem.*;
    }
}

// r = a | b with 2s complement semantics.
// r may alias.
// a and b must not be 0.
// Returns `true` when the result is positive.
// When b is positive, r requires at least `a.len` limbs of storage.
// When b is negative, r requires at least `b.len` limbs of storage.
fn llsignedor(r: []Limb, a: []const Limb, a_positive: bool, b: []const Limb, b_positive: bool) bool {
    assert(r.len >= a.len);
    assert(a.len >= b.len);

    if (a_positive and b_positive) {
        // Trivial case, result is positive.
        var i: usize = 0;
        while (i < b.len) : (i += 1) {
            r[i] = a[i] | b[i];
        }
        while (i < a.len) : (i += 1) {
            r[i] = a[i];
        }

        return true;
    } else if (!a_positive and b_positive) {
        // Result is negative.
        // r = (--a) | b
        //   = ~(-a - 1) | b
        //   = ~(-a - 1) | ~~b
        //   = ~((-a - 1) & ~b)
        //   = -(((-a - 1) & ~b) + 1)

        var i: usize = 0;
        var a_borrow: u1 = 1;
        var r_carry: u1 = 1;

        while (i < b.len) : (i += 1) {
            const ov1 = @subWithOverflow(a[i], a_borrow);
            a_borrow = ov1[1];
            const ov2 = @addWithOverflow(ov1[0] & ~b[i], r_carry);
            r[i] = ov2[0];
            r_carry = ov2[1];
        }

        // In order for r_carry to be nonzero at this point, ~b[i] would need to be
        // all ones, which would require b[i] to be zero. This cannot be when
        // b is normalized, so there cannot be a carry here.
        // Also, x & ~b can only clear bits, so (x & ~b) <= x, meaning (-a - 1) + 1 never overflows.
        assert(r_carry == 0);

        // With b = 0, we get (-a - 1) & ~0 = -a - 1.
        // Note, if a_borrow is zero we do not need to compute anything for
        // the higher limbs so we can early return here.
        while (i < a.len and a_borrow == 1) : (i += 1) {
            const ov = @subWithOverflow(a[i], a_borrow);
            r[i] = ov[0];
            a_borrow = ov[1];
        }

        assert(a_borrow == 0); // a was 0.

        return false;
    } else if (a_positive and !b_positive) {
        // Result is negative.
        // r = a | (--b)
        //   = a | ~(-b - 1)
        //   = ~~a | ~(-b - 1)
        //   = ~(~a & (-b - 1))
        //   = -((~a & (-b - 1)) + 1)

        var i: usize = 0;
        var b_borrow: u1 = 1;
        var r_carry: u1 = 1;

        while (i < b.len) : (i += 1) {
            const ov1 = @subWithOverflow(b[i], b_borrow);
            b_borrow = ov1[1];
            const ov2 = @addWithOverflow(~a[i] & ov1[0], r_carry);
            r[i] = ov2[0];
            r_carry = ov2[1];
        }

        // b is at least 1, so this should never underflow.
        assert(b_borrow == 0); // b was 0

        // x & ~a can only clear bits, so (x & ~a) <= x, meaning (-b - 1) + 1 never overflows.
        assert(r_carry == 0);

        // With b = 0 and b_borrow = 0, we get ~a & (0 - 0) = ~a & 0 = 0.
        // Omit setting the upper bytes, just deal with those when calling llsignedor.

        return false;
    } else {
        // Result is negative.
        // r = (--a) | (--b)
        //   = ~(-a - 1) | ~(-b - 1)
        //   = ~((-a - 1) & (-b - 1))
        //   = -(~(~((-a - 1) & (-b - 1))) + 1)
        //   = -((-a - 1) & (-b - 1) + 1)

        var i: usize = 0;
        var a_borrow: u1 = 1;
        var b_borrow: u1 = 1;
        var r_carry: u1 = 1;

        while (i < b.len) : (i += 1) {
            const ov1 = @subWithOverflow(a[i], a_borrow);
            a_borrow = ov1[1];
            const ov2 = @subWithOverflow(b[i], b_borrow);
            b_borrow = ov2[1];
            const ov3 = @addWithOverflow(ov1[0] & ov2[0], r_carry);
            r[i] = ov3[0];
            r_carry = ov3[1];
        }

        // b is at least 1, so this should never underflow.
        assert(b_borrow == 0); // b was 0

        // Can never overflow because in order for b_limb to be maxInt(Limb),
        // b_borrow would need to equal 1.

        // x & y can only clear bits, meaning x & y <= x and x & y <= y. This implies that
        // for x = a - 1 and y = b - 1, the +1 term would never cause an overflow.
        assert(r_carry == 0);

        // With b = 0 and b_borrow = 0 we get (-a - 1) & (0 - 0) = (-a - 1) & 0 = 0.
        // Omit setting the upper bytes, just deal with those when calling llsignedor.
        return false;
    }
}

// r = a & b with 2s complement semantics.
// r may alias.
// a and b must not be 0.
// Returns `true` when the result is positive.
// We assume `a.len >= b.len` here, so:
// 1. when b is positive, r requires at least `b.len` limbs of storage,
// 2. when b is negative but a is positive, r requires at least `a.len` limbs of storage,
// 3. when both a and b are negative, r requires at least `a.len + 1` limbs of storage.
fn llsignedand(r: []Limb, a: []const Limb, a_positive: bool, b: []const Limb, b_positive: bool) bool {
    assert(a.len != 0 and b.len != 0);
    assert(a.len >= b.len);
    assert(r.len >= if (b_positive) b.len else if (a_positive) a.len else a.len + 1);

    if (a_positive and b_positive) {
        // Trivial case, result is positive.
        var i: usize = 0;
        while (i < b.len) : (i += 1) {
            r[i] = a[i] & b[i];
        }

        // With b = 0 we have a & 0 = 0, so the upper bytes are zero.
        // Omit setting them here and simply discard them whenever
        // llsignedand is called.

        return true;
    } else if (!a_positive and b_positive) {
        // Result is positive.
        // r = (--a) & b
        //   = ~(-a - 1) & b

        var i: usize = 0;
        var a_borrow: u1 = 1;

        while (i < b.len) : (i += 1) {
            const ov = @subWithOverflow(a[i], a_borrow);
            a_borrow = ov[1];
            r[i] = ~ov[0] & b[i];
        }

        // With b = 0 we have ~(a - 1) & 0 = 0, so the upper bytes are zero.
        // Omit setting them here and simply discard them whenever
        // llsignedand is called.

        return true;
    } else if (a_positive and !b_positive) {
        // Result is positive.
        // r = a & (--b)
        //   = a & ~(-b - 1)

        var i: usize = 0;
        var b_borrow: u1 = 1;

        while (i < b.len) : (i += 1) {
            const ov = @subWithOverflow(b[i], b_borrow);
            b_borrow = ov[1];
            r[i] = a[i] & ~ov[0];
        }

        assert(b_borrow == 0); // b was 0

        // With b = 0 and b_borrow = 0 we have a & ~(0 - 0) = a & ~0 = a, so
        // the upper bytes are the same as those of a.

        while (i < a.len) : (i += 1) {
            r[i] = a[i];
        }

        return true;
    } else {
        // Result is negative.
        // r = (--a) & (--b)
        //   = ~(-a - 1) & ~(-b - 1)
        //   = ~((-a - 1) | (-b - 1))
        //   = -(((-a - 1) | (-b - 1)) + 1)

        var i: usize = 0;
        var a_borrow: u1 = 1;
        var b_borrow: u1 = 1;
        var r_carry: u1 = 1;

        while (i < b.len) : (i += 1) {
            const ov1 = @subWithOverflow(a[i], a_borrow);
            a_borrow = ov1[1];
            const ov2 = @subWithOverflow(b[i], b_borrow);
            b_borrow = ov2[1];
            const ov3 = @addWithOverflow(ov1[0] | ov2[0], r_carry);
            r[i] = ov3[0];
            r_carry = ov3[1];
        }

        // b is at least 1, so this should never underflow.
        assert(b_borrow == 0); // b was 0

        // With b = 0 and b_borrow = 0 we get (-a - 1) | (0 - 0) = (-a - 1) | 0 = -a - 1.
        while (i < a.len) : (i += 1) {
            const ov1 = @subWithOverflow(a[i], a_borrow);
            a_borrow = ov1[1];
            const ov2 = @addWithOverflow(ov1[0], r_carry);
            r[i] = ov2[0];
            r_carry = ov2[1];
        }

        assert(a_borrow == 0); // a was 0.

        // The final addition can overflow here, so we need to keep that in mind.
        r[i] = r_carry;

        return false;
    }
}

// r = a ^ b with 2s complement semantics.
// r may alias.
// a and b must not be -0.
// Returns `true` when the result is positive.
// If the sign of a and b is equal, then r requires at least `@max(a.len, b.len)` limbs are required.
// Otherwise, r requires at least `@max(a.len, b.len) + 1` limbs.
fn llsignedxor(r: []Limb, a: []const Limb, a_positive: bool, b: []const Limb, b_positive: bool) bool {
    assert(a.len != 0 and b.len != 0);
    assert(r.len >= a.len);
    assert(a.len >= b.len);

    // If a and b are positive, the result is positive and r = a ^ b.
    // If a negative, b positive, result is negative and we have
    // r = --(--a ^ b)
    //   = --(~(-a - 1) ^ b)
    //   = -(~(~(-a - 1) ^ b) + 1)
    //   = -(((-a - 1) ^ b) + 1)
    // Same if a is positive and b is negative, sides switched.
    // If both a and b are negative, the result is positive and we have
    // r = (--a) ^ (--b)
    //   = ~(-a - 1) ^ ~(-b - 1)
    //   = (-a - 1) ^ (-b - 1)
    // These operations can be made more generic as follows:
    // - If a is negative, subtract 1 from |a| before the xor.
    // - If b is negative, subtract 1 from |b| before the xor.
    // - if the result is supposed to be negative, add 1.

    var i: usize = 0;
    var a_borrow = @intFromBool(!a_positive);
    var b_borrow = @intFromBool(!b_positive);
    var r_carry = @intFromBool(a_positive != b_positive);

    while (i < b.len) : (i += 1) {
        const ov1 = @subWithOverflow(a[i], a_borrow);
        a_borrow = ov1[1];
        const ov2 = @subWithOverflow(b[i], b_borrow);
        b_borrow = ov2[1];
        const ov3 = @addWithOverflow(ov1[0] ^ ov2[0], r_carry);
        r[i] = ov3[0];
        r_carry = ov3[1];
    }

    while (i < a.len) : (i += 1) {
        const ov1 = @subWithOverflow(a[i], a_borrow);
        a_borrow = ov1[1];
        const ov2 = @addWithOverflow(ov1[0], r_carry);
        r[i] = ov2[0];
        r_carry = ov2[1];
    }

    // If both inputs don't share the same sign, an extra limb is required.
    if (a_positive != b_positive) {
        r[i] = r_carry;
    } else {
        assert(r_carry == 0);
    }

    assert(a_borrow == 0);
    assert(b_borrow == 0);

    return a_positive == b_positive;
}

/// r MUST NOT alias x.
fn llsquareBasecase(r: []Limb, x: []const Limb) void {
    const x_norm = x;
    assert(r.len >= 2 * x_norm.len + 1);
    assert(!slicesOverlap(r, x));

    // Compute the square of a N-limb bigint with only (N^2 + N)/2
    // multiplications by exploiting the symmetry of the coefficients around the
    // diagonal:
    //
    //           a   b   c *
    //           a   b   c =
    // -------------------
    //          ca  cb  cc +
    //      ba  bb  bc     +
    //  aa  ab  ac
    //
    // Note that:
    //  - Each mixed-product term appears twice for each column,
    //  - Squares are always in the 2k (0 <= k < N) column

    for (x_norm, 0..) |v, i| {
        // Accumulate all the x[i]*x[j] (with x!=j) products
        const overflow = llmulLimb(.add, r[2 * i + 1 ..], x_norm[i + 1 ..], v);
        assert(!overflow);
    }

    // Each product appears twice, multiply by 2
    _ = llshl(r, r[0 .. 2 * x_norm.len], 1);

    for (x_norm, 0..) |v, i| {
        // Compute and add the squares
        const overflow = llmulLimb(.add, r[2 * i ..], x[i..][0..1], v);
        assert(!overflow);
    }
}

/// Knuth 4.6.3
fn llpow(r: []Limb, a: []const Limb, b: u32, tmp_limbs: []Limb) void {
    var tmp1: []Limb = undefined;
    var tmp2: []Limb = undefined;

    // Multiplication requires no aliasing between the operand and the result
    // variable, use the output limbs and another temporary set to overcome this
    // limitation.
    // The initial assignment makes the result end in `r` so an extra memory
    // copy is saved, each 1 flips the index twice so it's only the zeros that
    // matter.
    const b_leading_zeros = @clz(b);
    const exp_zeros = @popCount(~b) - b_leading_zeros;
    if (exp_zeros & 1 != 0) {
        tmp1 = tmp_limbs;
        tmp2 = r;
    } else {
        tmp1 = r;
        tmp2 = tmp_limbs;
    }

    @memcpy(tmp1[0..a.len], a);
    @memset(tmp1[a.len..], 0);

    // Scan the exponent as a binary number, from left to right, dropping the
    // most significant bit set.
    // Square the result if the current bit is zero, square and multiply by a if
    // it is one.
    const exp_bits = 32 - 1 - b_leading_zeros;
    var exp = b << @as(u5, @intCast(1 + b_leading_zeros));

    var i: usize = 0;
    while (i < exp_bits) : (i += 1) {
        // Square
        @memset(tmp2, 0);
        llsquareBasecase(tmp2, tmp1[0..llnormalize(tmp1)]);
        mem.swap([]Limb, &tmp1, &tmp2);
        // Multiply by a
        const ov = @shlWithOverflow(exp, 1);
        exp = ov[0];
        if (ov[1] != 0) {
            @memset(tmp2, 0);
            _ = llmulacc(.add, null, tmp2, tmp1[0..llnormalize(tmp1)], a);
            mem.swap([]Limb, &tmp1, &tmp2);
        }
    }
}

// Storage must live for the lifetime of the returned value
fn fixedIntFromSignedDoubleLimb(A: SignedDoubleLimb, storage: []Limb) Mutable {
    assert(storage.len >= 2);

    const A_is_positive = A >= 0;
    const Au = @as(DoubleLimb, @intCast(if (A < 0) -A else A));
    storage[0] = @as(Limb, @truncate(Au));
    storage[1] = @as(Limb, @truncate(Au >> limb_bits));
    return .{
        .limbs = storage[0..2],
        .positive = A_is_positive,
        .len = 2,
    };
}

/// Allows to divide in-place without having an extra limb available to shift when b is not normalized
// Could probably be made less expensive by doing one division step manually, to avoid
// copying the data
// Note (when used by toString) : when `Limb` is 64 bits and b = big_bases[10],
// b is already normalized, so the most common case is not using the slower path
fn divby1(a: []Limb, b: Limb) Limb {
    if (@clz(b) == 0) {
        return lldiv1(a, a, b);
    }

    const base = b << @truncate(@clz(b));
    const a2 = a[0];

    mem.copyForwards(Limb, a, a[1..]);
    a[a.len - 1] = 0;
    const len = std.math.big.int.llshl(a, a[0 .. a.len - 1], @clz(b));

    // B = 2^@bitSizeOf(Limb)
    // a = a1*B + a2                          -- here, a1 is a[1..]
    //   = (q1 * b + r1)*B + (q2 * b + r2)    -- division of a1 and a2 by b
    //   = (q1 * B + q2)*b + (r1 * B + r2)
    // and r1 * B + r2 = q3 * b + r3          -- division of r1*B + r2 by b
    //
    // so a = (q1 * B + q2 + q3)*b + r3
    // q1 and r1 are obtained using `lldiv1`

    // q1 is written to a[1..] (same as doing *B)
    var r1: DoubleLimb = lldiv1(a[1..], a[0..len], base);

    const q1 = a;
    q1[0] = 0;
    // since b was shifted for the division, so is r1 (see division algorithms)
    r1 >>= @truncate(@clz(b));

    // multiply by B and add r2
    r1 <<= @bitSizeOf(Limb);
    r1 += a2 % b;

    const q2 = a2 / b;
    _ = llaccum(.add, q1, &.{q2});

    // compute q3 and r3
    const q3: Limb = @intCast(r1 / b);
    _ = llaccum(.add, q1, &.{q3});
    r1 %= b;

    return @intCast(r1);
}

/// O(n^2) in-place algorithm to convert a number to a string in a different base
/// `string` must have enough space to store the number
/// Does not write leading zeros (filling string with zeros beforehand is advised).
/// Each element of string is the value of the digit rather than its character representation.
/// Converting between the value and the character is handled by the caller.
fn toStringBasecase(num: []Limb, string: []u8, base: u8) void {
    assert(base >= 2);
    assert(base <= constants.big_bases.len);

    const big_base = constants.big_bases[base];
    const dig_per_limb = constants.digits_per_limb[base];

    var string_len: usize = string.len;
    var a = num;

    while (a.len > 1) {
        var d = divby1(num, big_base);

        for (0..dig_per_limb) |_| {
            string[string_len - 1] = @intCast(d % base);
            d /= base;
            string_len -= 1;
        }

        // TODO: can this happen multiple times ?
        while (a.len > 1 and a[a.len - 1] == 0)
            a = a[0 .. a.len - 1];
    }
    var d = a[0];
    while (d != 0) {
        string[string_len - 1] = @intCast(d % base);
        d /= base;
        string_len -= 1;
    }
}

/// Subquadratic algorithm converting a number into an other base
/// actual complexity depends on the multiplication and division's complexity
///
/// `num[num.len - 1]` must not be part of the actual number, and must be left as space for the division.
///
/// bases is a list of B^(2^k), with B = big_bases[base], in increasing order (bases[k] = B^(2^k))
/// at least one of the bases must be greater than sqrt(num) (not asserted)
///
/// As for `toStringBasecase`, the values of num's digits are written to string rather than
/// their character representation (and it is similarly advised to fill `string` with zeros)
///
/// How this algorithm works:
/// At each step of the recursion:
/// - if num is too small, we fallback onto the basecase algorithm
/// otherwise:
/// - we find `B` (written `b` in the code) in the list `bases` such that num > B >= sqrt(num)
///   therefore, B = big_bases[base]^(2^k) = base^(digits_per_limbs[base] * 2^k)
///   because of how `bases` is constructed, `B` is the largest element of `bases` smaller than
///   `num`
/// - we divide `num` by `B`, and get q and r such as `num = q * B + r`
///   since B >= sqrt(num), both q and r are < B (with q <= r), so B is not needed
///   in future recursive calls
///
///   furthermore, `r` is exactly `digits_per_limbs[base] * 2^k` digits, and `q` is less than that
/// - we then recurse on `q` and `r`
///
/// Some alternative algorithms compute B = base^k with `B` close to sqrt(num) (e.g. in Modern Computer Arithmetic)
/// We do not do that (and follow gmp) since it reduces the number of `B` to compute.
/// The drawback is that the division may not be well balanced (if `B` is close to `num`), potentially leading to
/// a small performance hit, which may or may not be noticeable (no tests have been done).
fn toStringSubquadratic(allocator: std.mem.Allocator, num: []Limb, string: []u8, base: u8, bases: []const Mutable) Allocator.Error!void {
    assert(base >= 2);
    assert(base <= constants.big_bases.len);

    if (num.len - 1 < tostring_subquadratic_threshold) {
        toStringBasecase(num[0 .. num.len - 1], string, base);
        return;
    }

    const a = Mutable{ .len = num.len - 1, .limbs = num, .positive = true };

    // Retrieve the first base smaller than num
    var i = bases.len - 1;
    while (bases[i].toConst().order(a.toConst()) != .lt)
        i -= 1;

    const b = bases[i];

    // the "+ 1" is for division in future recursive calls
    const limb_buffer = try allocator.alloc(Limb, calcDivQLen(a.len, b.len) + 1);

    var q = Mutable{ .len = 0, .limbs = limb_buffer, .positive = true };
    var r = Mutable{ .len = 0, .limbs = num, .positive = true };
    Mutable.div(&q, &r, a, b, allocator);

    // `base` is big_bases[b]^(2^i) == b^(k*2^i),
    // so the remainder of the division has k*2^i digits is base b
    const split = string.len - (@as(usize, 1) << @truncate(i)) * constants.digits_per_limb[base];

    try toStringSubquadratic(allocator, q.limbs[0 .. q.len + 1], string[0..split], base, bases[0..i]);
    // since we should receive an arena, this allow the next recursive call to reuse already allocated memory,
    // assuming all memory allocated in the recursive call has already been freed
    allocator.free(limb_buffer);
    try toStringSubquadratic(allocator, r.limbs[0 .. r.len + 1], string[split..], base, bases[0..i]);
}

fn slicesOverlap(a: []const Limb, b: []const Limb) bool {
    // there is no overlap if a.ptr + a.len <= b.ptr or b.ptr + b.len <= a.ptr
    return @intFromPtr(a.ptr + a.len) > @intFromPtr(b.ptr) and @intFromPtr(b.ptr + b.len) > @intFromPtr(a.ptr);
}

test {
    _ = @import("int_test.zig");
}

const testing_allocator = std.testing.allocator;
test "llshl shift by whole number of limb" {
    const padding = maxInt(Limb);

    var r: [10]Limb = @splat(padding);

    const A: Limb = @truncate(0xCCCCCCCCCCCCCCCCCCCCCCC);
    const B: Limb = @truncate(0x22222222222222222222222);

    const data = [2]Limb{ A, B };
    for (0..9) |i| {
        @memset(&r, padding);
        const len = llshl(&r, &data, i * @bitSizeOf(Limb));

        try std.testing.expectEqual(i + 2, len);
        try std.testing.expectEqualSlices(Limb, &data, r[i .. i + 2]);
        for (r[0..i]) |x|
            try std.testing.expectEqual(0, x);
        for (r[i + 2 ..]) |x|
            try std.testing.expectEqual(padding, x);
    }
}

test llshl {
    if (limb_bits != 64) return error.SkipZigTest;

    // 1 << 63
    const left_one = 0x8000000000000000;
    const maxint: Limb = 0xFFFFFFFFFFFFFFFF;

    // zig fmt: off
    try testOneShiftCase(.llshl, .{0,  &.{0},                               &.{0}});
    try testOneShiftCase(.llshl, .{0,  &.{1},                               &.{1}});
    try testOneShiftCase(.llshl, .{0,  &.{125484842448},                    &.{125484842448}});
    try testOneShiftCase(.llshl, .{0,  &.{0xdeadbeef},                      &.{0xdeadbeef}});
    try testOneShiftCase(.llshl, .{0,  &.{maxint},                          &.{maxint}});
    try testOneShiftCase(.llshl, .{0,  &.{left_one},                        &.{left_one}});
    try testOneShiftCase(.llshl, .{0,  &.{0, 1},                            &.{0, 1}});
    try testOneShiftCase(.llshl, .{0,  &.{1, 2},                            &.{1, 2}});
    try testOneShiftCase(.llshl, .{0,  &.{left_one, 1},                     &.{left_one, 1}});
    try testOneShiftCase(.llshl, .{1,  &.{0},                               &.{0}});
    try testOneShiftCase(.llshl, .{1,  &.{2},                               &.{1}});
    try testOneShiftCase(.llshl, .{1,  &.{250969684896},                    &.{125484842448}});
    try testOneShiftCase(.llshl, .{1,  &.{0x1bd5b7dde},                     &.{0xdeadbeef}});
    try testOneShiftCase(.llshl, .{1,  &.{0xfffffffffffffffe, 1},           &.{maxint}});
    try testOneShiftCase(.llshl, .{1,  &.{0, 1},                            &.{left_one}});
    try testOneShiftCase(.llshl, .{1,  &.{0, 2},                            &.{0, 1}});
    try testOneShiftCase(.llshl, .{1,  &.{2, 4},                            &.{1, 2}});
    try testOneShiftCase(.llshl, .{1,  &.{0, 3},                            &.{left_one, 1}});
    try testOneShiftCase(.llshl, .{5,  &.{32},                              &.{1}});
    try testOneShiftCase(.llshl, .{5,  &.{4015514958336},                   &.{125484842448}});
    try testOneShiftCase(.llshl, .{5,  &.{0x1bd5b7dde0},                    &.{0xdeadbeef}});
    try testOneShiftCase(.llshl, .{5,  &.{0xffffffffffffffe0, 0x1f},        &.{maxint}});
    try testOneShiftCase(.llshl, .{5,  &.{0, 16},                           &.{left_one}});
    try testOneShiftCase(.llshl, .{5,  &.{0, 32},                           &.{0, 1}});
    try testOneShiftCase(.llshl, .{5,  &.{32, 64},                          &.{1, 2}});
    try testOneShiftCase(.llshl, .{5,  &.{0, 48},                           &.{left_one, 1}});
    try testOneShiftCase(.llshl, .{64, &.{0, 1},                            &.{1}});
    try testOneShiftCase(.llshl, .{64, &.{0, 125484842448},                 &.{125484842448}});
    try testOneShiftCase(.llshl, .{64, &.{0, 0xdeadbeef},                   &.{0xdeadbeef}});
    try testOneShiftCase(.llshl, .{64, &.{0, maxint},                       &.{maxint}});
    try testOneShiftCase(.llshl, .{64, &.{0, left_one},                     &.{left_one}});
    try testOneShiftCase(.llshl, .{64, &.{0, 0, 1},                         &.{0, 1}});
    try testOneShiftCase(.llshl, .{64, &.{0, 1, 2},                         &.{1, 2}});
    try testOneShiftCase(.llshl, .{64, &.{0, left_one, 1},                  &.{left_one, 1}});
    try testOneShiftCase(.llshl, .{35, &.{0x800000000},                     &.{1}});
    try testOneShiftCase(.llshl, .{35, &.{13534986488655118336, 233},       &.{125484842448}});
    try testOneShiftCase(.llshl, .{35, &.{0xf56df77800000000, 6},           &.{0xdeadbeef}});
    try testOneShiftCase(.llshl, .{35, &.{0xfffffff800000000, 0x7ffffffff}, &.{maxint}});
    try testOneShiftCase(.llshl, .{35, &.{0, 17179869184},                  &.{left_one}});
    try testOneShiftCase(.llshl, .{35, &.{0, 0x800000000},                  &.{0, 1}});
    try testOneShiftCase(.llshl, .{35, &.{0x800000000, 0x1000000000},       &.{1, 2}});
    try testOneShiftCase(.llshl, .{35, &.{0, 0xc00000000},                  &.{left_one, 1}});
    try testOneShiftCase(.llshl, .{70, &.{0, 64},                           &.{1}});
    try testOneShiftCase(.llshl, .{70, &.{0, 8031029916672},                &.{125484842448}});
    try testOneShiftCase(.llshl, .{70, &.{0, 0x37ab6fbbc0},                 &.{0xdeadbeef}});
    try testOneShiftCase(.llshl, .{70, &.{0, 0xffffffffffffffc0, 63},       &.{maxint}});
    try testOneShiftCase(.llshl, .{70, &.{0, 0, 32},                        &.{left_one}});
    try testOneShiftCase(.llshl, .{70, &.{0, 0, 64},                        &.{0, 1}});
    try testOneShiftCase(.llshl, .{70, &.{0, 64, 128},                      &.{1, 2}});
    try testOneShiftCase(.llshl, .{70, &.{0, 0, 0x60},                      &.{left_one, 1}});
    // zig fmt: on
}

test "llshl shift 0" {
    const n = @bitSizeOf(Limb);
    if (n <= 20) return error.SkipZigTest;

    // zig fmt: off
    try testOneShiftCase(.llshl, .{0,   &.{0},    &.{0}});
    try testOneShiftCase(.llshl, .{1,   &.{0},    &.{0}});
    try testOneShiftCase(.llshl, .{5,   &.{0},    &.{0}});
    try testOneShiftCase(.llshl, .{13,  &.{0},    &.{0}});
    try testOneShiftCase(.llshl, .{20,  &.{0},    &.{0}});
    try testOneShiftCase(.llshl, .{0,   &.{0, 0}, &.{0, 0}});
    try testOneShiftCase(.llshl, .{2,   &.{0, 0}, &.{0, 0}});
    try testOneShiftCase(.llshl, .{7,   &.{0, 0}, &.{0, 0}});
    try testOneShiftCase(.llshl, .{11,  &.{0, 0}, &.{0, 0}});
    try testOneShiftCase(.llshl, .{19,  &.{0, 0}, &.{0, 0}});

    try testOneShiftCase(.llshl, .{0,   &.{0},                &.{0}});
    try testOneShiftCase(.llshl, .{n,   &.{0, 0},             &.{0}});
    try testOneShiftCase(.llshl, .{2*n, &.{0, 0, 0},          &.{0}});
    try testOneShiftCase(.llshl, .{3*n, &.{0, 0, 0, 0},       &.{0}});
    try testOneShiftCase(.llshl, .{4*n, &.{0, 0, 0, 0, 0},    &.{0}});
    try testOneShiftCase(.llshl, .{0,   &.{0, 0},             &.{0, 0}});
    try testOneShiftCase(.llshl, .{n,   &.{0, 0, 0},          &.{0, 0}});
    try testOneShiftCase(.llshl, .{2*n, &.{0, 0, 0, 0},       &.{0, 0}});
    try testOneShiftCase(.llshl, .{3*n, &.{0, 0, 0, 0, 0},    &.{0, 0}});
    try testOneShiftCase(.llshl, .{4*n, &.{0, 0, 0, 0, 0, 0}, &.{0, 0}});
    // zig fmt: on
}

test "llshr shift 0" {
    const n = @bitSizeOf(Limb);

    // zig fmt: off
    try testOneShiftCase(.llshr, .{0,   &.{0},    &.{0}});
    try testOneShiftCase(.llshr, .{1,   &.{0},    &.{0}});
    try testOneShiftCase(.llshr, .{5,   &.{0},    &.{0}});
    try testOneShiftCase(.llshr, .{13,  &.{0},    &.{0}});
    try testOneShiftCase(.llshr, .{20,  &.{0},    &.{0}});
    try testOneShiftCase(.llshr, .{0,   &.{0, 0}, &.{0, 0}});
    try testOneShiftCase(.llshr, .{2,   &.{0},    &.{0, 0}});
    try testOneShiftCase(.llshr, .{7,   &.{0},    &.{0, 0}});
    try testOneShiftCase(.llshr, .{11,  &.{0},    &.{0, 0}});
    try testOneShiftCase(.llshr, .{19,  &.{0},    &.{0, 0}});

    try testOneShiftCase(.llshr, .{n,   &.{0}, &.{0}});
    try testOneShiftCase(.llshr, .{2*n, &.{0}, &.{0}});
    try testOneShiftCase(.llshr, .{3*n, &.{0}, &.{0}});
    try testOneShiftCase(.llshr, .{4*n, &.{0}, &.{0}});
    try testOneShiftCase(.llshr, .{n,   &.{0}, &.{0, 0}});
    try testOneShiftCase(.llshr, .{2*n, &.{0}, &.{0, 0}});
    try testOneShiftCase(.llshr, .{3*n, &.{0}, &.{0, 0}});
    try testOneShiftCase(.llshr, .{4*n, &.{0}, &.{0, 0}});

    try testOneShiftCase(.llshr, .{1,  &.{}, &.{}});
    try testOneShiftCase(.llshr, .{2,  &.{}, &.{}});
    try testOneShiftCase(.llshr, .{64, &.{}, &.{}});
    // zig fmt: on
}

test "llshr to 0" {
    const n = @bitSizeOf(Limb);
    if (n != 64 and n != 32) return error.SkipZigTest;

    // zig fmt: off
    try testOneShiftCase(.llshr, .{1,   &.{0}, &.{0}});
    try testOneShiftCase(.llshr, .{1,   &.{0}, &.{1}});
    try testOneShiftCase(.llshr, .{5,   &.{0}, &.{1}});
    try testOneShiftCase(.llshr, .{65,  &.{0}, &.{0, 1}});
    try testOneShiftCase(.llshr, .{193, &.{0}, &.{0, 0, maxInt(Limb)}});
    try testOneShiftCase(.llshr, .{193, &.{0}, &.{maxInt(Limb), 1, maxInt(Limb)}});
    try testOneShiftCase(.llshr, .{193, &.{0}, &.{0xdeadbeef, 0xabcdefab, 0x1234}});
    // zig fmt: on
}

test "llshr single" {
    if (limb_bits != 64) return error.SkipZigTest;

    // 1 << 63
    const left_one = 0x8000000000000000;
    const maxint: Limb = 0xFFFFFFFFFFFFFFFF;

    // zig fmt: off
    try testOneShiftCase(.llshr, .{0,  &.{0},                  &.{0}});
    try testOneShiftCase(.llshr, .{0,  &.{1},                  &.{1}});
    try testOneShiftCase(.llshr, .{0,  &.{125484842448},       &.{125484842448}});
    try testOneShiftCase(.llshr, .{0,  &.{0xdeadbeef},         &.{0xdeadbeef}});
    try testOneShiftCase(.llshr, .{0,  &.{maxint},             &.{maxint}});
    try testOneShiftCase(.llshr, .{0,  &.{left_one},           &.{left_one}});
    try testOneShiftCase(.llshr, .{1,  &.{0},                  &.{0}});
    try testOneShiftCase(.llshr, .{1,  &.{1},                  &.{2}});
    try testOneShiftCase(.llshr, .{1,  &.{62742421224},        &.{125484842448}});
    try testOneShiftCase(.llshr, .{1,  &.{62742421223},        &.{125484842447}});
    try testOneShiftCase(.llshr, .{1,  &.{0x6f56df77},         &.{0xdeadbeef}});
    try testOneShiftCase(.llshr, .{1,  &.{0x7fffffffffffffff}, &.{maxint}});
    try testOneShiftCase(.llshr, .{1,  &.{0x4000000000000000}, &.{left_one}});
    try testOneShiftCase(.llshr, .{8,  &.{1},                  &.{256}});
    try testOneShiftCase(.llshr, .{8,  &.{490175165},          &.{125484842448}});
    try testOneShiftCase(.llshr, .{8,  &.{0xdeadbe},           &.{0xdeadbeef}});
    try testOneShiftCase(.llshr, .{8,  &.{0xffffffffffffff},   &.{maxint}});
    try testOneShiftCase(.llshr, .{8,  &.{0x80000000000000},   &.{left_one}});
    // zig fmt: on
}

test llshr {
    if (limb_bits != 64) return error.SkipZigTest;

    // 1 << 63
    const left_one = 0x8000000000000000;
    const maxint: Limb = 0xFFFFFFFFFFFFFFFF;

    // zig fmt: off
    try testOneShiftCase(.llshr, .{0,  &.{0, 0},                           &.{0, 0}});
    try testOneShiftCase(.llshr, .{0,  &.{0, 1},                           &.{0, 1}});
    try testOneShiftCase(.llshr, .{0,  &.{15, 1},                          &.{15, 1}});
    try testOneShiftCase(.llshr, .{0,  &.{987656565, 123456789456},        &.{987656565, 123456789456}});
    try testOneShiftCase(.llshr, .{0,  &.{0xfeebdaed, 0xdeadbeef},         &.{0xfeebdaed, 0xdeadbeef}});
    try testOneShiftCase(.llshr, .{0,  &.{1, maxint},                      &.{1, maxint}});
    try testOneShiftCase(.llshr, .{0,  &.{0, left_one},                    &.{0, left_one}});
    try testOneShiftCase(.llshr, .{1,  &.{0},                              &.{0, 0}});
    try testOneShiftCase(.llshr, .{1,  &.{left_one},                       &.{0, 1}});
    try testOneShiftCase(.llshr, .{1,  &.{0x8000000000000007},             &.{15, 1}});
    try testOneShiftCase(.llshr, .{1,  &.{493828282, 61728394728},         &.{987656565, 123456789456}});
    try testOneShiftCase(.llshr, .{1,  &.{0x800000007f75ed76, 0x6f56df77}, &.{0xfeebdaed, 0xdeadbeef}});
    try testOneShiftCase(.llshr, .{1,  &.{left_one, 0x7fffffffffffffff},   &.{1, maxint}});
    try testOneShiftCase(.llshr, .{1,  &.{0, 0x4000000000000000},          &.{0, left_one}});
    try testOneShiftCase(.llshr, .{64, &.{0},                              &.{0, 0}});
    try testOneShiftCase(.llshr, .{64, &.{1},                              &.{0, 1}});
    try testOneShiftCase(.llshr, .{64, &.{1},                              &.{15, 1}});
    try testOneShiftCase(.llshr, .{64, &.{123456789456},                   &.{987656565, 123456789456}});
    try testOneShiftCase(.llshr, .{64, &.{0xdeadbeef},                     &.{0xfeebdaed, 0xdeadbeef}});
    try testOneShiftCase(.llshr, .{64, &.{maxint},                         &.{1, maxint}});
    try testOneShiftCase(.llshr, .{64, &.{left_one},                       &.{0, left_one}});
    try testOneShiftCase(.llshr, .{72, &.{0},                              &.{0, 0}});
    try testOneShiftCase(.llshr, .{72, &.{0},                              &.{0, 1}});
    try testOneShiftCase(.llshr, .{72, &.{0},                              &.{15, 1}});
    try testOneShiftCase(.llshr, .{72, &.{482253083},                      &.{987656565, 123456789456}});
    try testOneShiftCase(.llshr, .{72, &.{0xdeadbe},                       &.{0xfeebdaed, 0xdeadbeef}});
    try testOneShiftCase(.llshr, .{72, &.{0xffffffffffffff},               &.{1, maxint}});
    try testOneShiftCase(.llshr, .{72, &.{0x80000000000000},               &.{0, left_one}});
    // zig fmt: on
}

const Case = struct { usize, []const Limb, []const Limb };

fn testOneShiftCase(comptime function: enum { llshr, llshl }, case: Case) !void {
    const func = if (function == .llshl) llshl else llshr;
    const shift_direction = if (function == .llshl) -1 else 1;

    try testOneShiftCaseNoAliasing(func, case);
    try testOneShiftCaseAliasing(func, case, shift_direction);
}

fn testOneShiftCaseNoAliasing(func: fn ([]Limb, []const Limb, usize) usize, case: Case) !void {
    const padding = maxInt(Limb);
    var r: [20]Limb = @splat(padding);

    const shift = case[0];
    const expected = case[1];
    const data = case[2];

    std.debug.assert(expected.len <= 20);

    const len = func(&r, data, shift);

    try std.testing.expectEqual(expected.len, len);
    try std.testing.expectEqualSlices(Limb, expected, r[0..len]);
    try std.testing.expect(mem.allEqual(Limb, r[len..], padding));
}

fn testOneShiftCaseAliasing(func: fn ([]Limb, []const Limb, usize) usize, case: Case, shift_direction: isize) !void {
    const padding = maxInt(Limb);
    var r: [60]Limb = @splat(padding);
    const base = 20;

    assert(shift_direction == 1 or shift_direction == -1);

    for (0..10) |limb_shift| {
        const shift = case[0];
        const expected = case[1];
        const data = case[2];

        std.debug.assert(expected.len <= 20);

        @memset(&r, padding);
        const final_limb_base: usize = @intCast(base + shift_direction * @as(isize, @intCast(limb_shift)));
        const written_data = r[final_limb_base..][0..data.len];
        @memcpy(written_data, data);

        const len = func(r[base..], written_data, shift);

        try std.testing.expectEqual(expected.len, len);
        try std.testing.expectEqualSlices(Limb, expected, r[base .. base + len]);
    }
}

test "llaccum empty y" {
    if (@sizeOf(Limb) < 2) return error.SkipZigTest;
    const maxint: Limb = maxInt(Limb);

    // zig fmt: off
    try testAccum(.add, &.{},                &.{}, &.{},                false);
    try testAccum(.add, &.{0},               &.{}, &.{0},               false);
    try testAccum(.add, &.{maxint} ,         &.{}, &.{maxint},          false);
    try testAccum(.add, &.{0, 0},            &.{}, &.{0, 0},            false);
    try testAccum(.add, &.{0, 48764},        &.{}, &.{0, 48764},        false);
    try testAccum(.add, &.{maxint, 0, 1, 0}, &.{}, &.{maxint, 0, 1, 0}, false);

    try testAccum(.sub, &.{},                &.{}, &.{},                false);
    try testAccum(.sub, &.{0},               &.{}, &.{0},               false);
    try testAccum(.sub, &.{maxint} ,         &.{}, &.{maxint},          false);
    try testAccum(.sub, &.{0, 0},            &.{}, &.{0, 0},            false);
    try testAccum(.sub, &.{0, 48764},        &.{}, &.{0, 48764},        false);
    try testAccum(.sub, &.{maxint, 0, 1, 0}, &.{}, &.{maxint, 0, 1, 0}, false);
    // zig fmt: on
    // TODO: more than 4
    // TODO: more multiples of 4
}

test "llaccum y full of 0" {
    if (@sizeOf(Limb) < 2) return error.SkipZigTest;
    const maxint: Limb = maxInt(Limb);

    // zig fmt: off
    try testAccum(.add, &.{0},               &.{0},             &.{0},               false);
    try testAccum(.add, &.{maxint} ,         &.{0},             &.{maxint},          false);
    try testAccum(.add, &.{0, 0},            &.{0},             &.{0, 0},            false);
    try testAccum(.add, &.{0, 0},            &.{0, 0},          &.{0, 0},            false);
    try testAccum(.add, &.{0, 48764},        &.{0},             &.{0, 48764},        false);
    try testAccum(.add, &.{0, 11111},        &.{0, 0},          &.{0, 11111},        false);
    try testAccum(.add, &.{maxint, 0, 1, 0}, &.{0},             &.{maxint, 0, 1, 0}, false);
    try testAccum(.add, &.{maxint, 0, 1, 0}, &.{0, 0},          &.{maxint, 0, 1, 0}, false);
    try testAccum(.add, &.{maxint, 0, 1, 0}, &.{0, 0, 0},       &.{maxint, 0, 1, 0}, false);
    try testAccum(.add, &.{maxint, 0, 1, 0}, &.{0, 0, 0, 0},    &.{maxint, 0, 1, 0}, false);

    // we test multiple of 4 and non multiple of 4 for both acc and y
    inline for (1..13) |i| {
        inline for (1..i) |j| {
            try testAccum(.add, &(.{maxint} ** i),   &(.{0} ** j), &(.{maxint} ** i),   false);
            try testAccum(.sub, &(.{maxint} ** i),   &(.{0} ** j), &(.{maxint} ** i),   false);
        }
    }

    try testAccum(.sub, &.{0},               &.{0},             &.{0},               false);
    try testAccum(.sub, &.{maxint} ,         &.{0},             &.{maxint},          false);
    try testAccum(.sub, &.{0, 0},            &.{0},             &.{0, 0},            false);
    try testAccum(.sub, &.{0, 0},            &.{0, 0},          &.{0, 0},            false);
    try testAccum(.sub, &.{0, 48764},        &.{0},             &.{0, 48764},        false);
    try testAccum(.sub, &.{0, 11111},        &.{0, 0},          &.{0, 11111},        false);
    try testAccum(.sub, &.{maxint, 0, 1, 0}, &.{0},             &.{maxint, 0, 1, 0}, false);
    try testAccum(.sub, &.{maxint, 0, 1, 0}, &.{0, 0},          &.{maxint, 0, 1, 0}, false);
    try testAccum(.sub, &.{maxint, 0, 1, 0}, &.{0, 0, 0},       &.{maxint, 0, 1, 0}, false);
    try testAccum(.sub, &.{maxint, 0, 1, 0}, &.{0, 0, 0, 0},    &.{maxint, 0, 1, 0}, false);
    // zig fmt: on
}

test llaccum {
    if (@sizeOf(Limb) < 2) return error.SkipZigTest;
    // we make sure to make no use of comptime_int, since it uses BigInts
    const maxint: Limb = maxInt(Limb);

    // zig fmt: off
    // no carry, one limb
    try testAccum(.add, &.{1},     &.{1},  &.{2},     false);
    try testAccum(.add, &.{10},    &.{1},  &.{11},    false);
    try testAccum(.add, &.{1},     &.{10}, &.{11},    false);
    try testAccum(.add, &.{48797}, &.{10}, &.{48807}, false);

    // no carry, multiple limbs
    try testAccum(.add, &.{1, 0},     &.{1},         &.{2, 0},              false);
    try testAccum(.add, &.{10, 0},    &.{1},         &.{11, 0},             false);
    try testAccum(.add, &.{1, 0},     &.{10},        &.{11, 0},             false);
    try testAccum(.add, &.{48797, 0}, &.{10},        &.{48807, 0},          false);
    try testAccum(.add, &.{1, 1},     &.{1},         &.{2, 1},              false);
    try testAccum(.add, &.{100, 1},   &.{1, 1},      &.{101, 2},            false);
    try testAccum(.add, &.{100, 1},   &.{0, 1},      &.{100, 2},            false);
    try testAccum(.add, &.{100, 1},   &.{500, 1247}, &.{600, 1248},         false);
    try testAccum(.add, &(.{1} ** 4), &(.{1} ** 4),  &(.{2} ** 4),          false);
    try testAccum(.add, &(.{1} ** 5), &(.{1} ** 5),  &(.{2} ** 5),          false);
    try testAccum(.add, &(.{1} ** 6), &(.{1} ** 6),  &(.{2} ** 6),          false);
    try testAccum(.add, &(.{1} ** 7), &(.{1} ** 7),  &(.{2} ** 7),          false);
    try testAccum(.add, &(.{1} ** 8), &(.{1} ** 8),  &(.{2} ** 8),          false);
    try testAccum(.add, &(.{1} ** 4), &.{1},         &(.{2} ++ .{1} ** 3),  false);
    try testAccum(.add, &(.{1} ** 5), &.{1},         &(.{2} ++ .{1} ** 4),  false);
    try testAccum(.add, &(.{1} ** 6), &.{1},         &(.{2} ++ .{1} ** 5),  false);
    try testAccum(.add, &(.{1} ** 7), &.{1},         &(.{2} ++ .{1} ** 6),  false);
    try testAccum(.add, &(.{1} ** 8), &.{1},         &(.{2} ++ .{1} ** 7),  false);

    // carry, one limb
    try testAccum(.add, &.{maxint}, &.{1},      &.{0},          true);
    try testAccum(.add, &.{maxint}, &.{10},     &.{9},          true);
    try testAccum(.add, &.{maxint}, &.{maxint}, &.{maxint - 1}, true);

    // carry and carry propagation, multiple limbs
    try testAccum(.add, &.{maxint, 0},             &.{1},              &.{0, 1},               false);
    try testAccum(.add, &(.{maxint} ** 1),         &.{1},              &(.{0} ** 1),           true);
    try testAccum(.add, &(.{maxint} ** 2),         &.{1},              &(.{0} ** 2),           true);
    try testAccum(.add, &(.{maxint} ** 3),         &.{1},              &(.{0} ** 3),           true);
    try testAccum(.add, &(.{maxint} ** 4),         &.{1},              &(.{0} ** 4),           true);
    try testAccum(.add, &(.{maxint} ** 5),         &.{1},              &(.{0} ** 5),           true);
    try testAccum(.add, &(.{maxint} ** 6),         &.{1},              &(.{0} ** 6),           true);
    try testAccum(.add, &(.{maxint} ** 7),         &.{1},              &(.{0} ** 7),           true);
    try testAccum(.add, &(.{maxint} ** 8),         &.{1},              &(.{0} ** 8),           true);
    try testAccum(.add, &.{0, maxint},             &.{0, 1},           &.{0, 0},               true);
    try testAccum(.add, &.{10, 0},                 &.{maxint},         &.{9, 1},               false);
    try testAccum(.add, &.{1024, maxint},          &.{maxint},         &.{1023, 0},            true);
    try testAccum(.add, &.{maxint, maxint},        &.{maxint},         &.{maxint - 1, 0},      true);
    try testAccum(.add, &.{maxint, maxint},        &.{maxint, maxint}, &.{maxint - 1, maxint}, true);
    try testAccum(.add, &(.{maxint} ** 5 ++ .{0}), &.{1},              &(.{0} ** 5 ++ .{1}),   false);
    try testAccum(.add, &(.{maxint} ** 5),         &.{1},              &(.{0} ** 5),           true);

    // sub
    // no carry, one limb
    try testAccum(.sub, &.{1},     &.{1},  &.{0},     false);
    try testAccum(.sub, &.{10},    &.{1},  &.{9},     false);
    try testAccum(.sub, &.{25},    &.{10}, &.{15},    false);
    try testAccum(.sub, &.{48797}, &.{10}, &.{48787}, false);

    // no carry, multiple limbs
    try testAccum(.sub, &.{1, 0},      &.{1},      &.{0, 0},      false);
    try testAccum(.sub, &.{10, 0},     &.{1},      &.{9, 0},      false);
    try testAccum(.sub, &.{25, 0},     &.{10},     &.{15, 0},     false);
    try testAccum(.sub, &.{48797, 0},  &.{10},     &.{48787, 0},  false);
    try testAccum(.sub, &.{1, 1},      &.{1},      &.{0, 1},      false);
    try testAccum(.sub, &.{1, 1},      &.{0, 1},   &.{1, 0},      false);
    try testAccum(.sub, &.{1, 1},      &.{1, 1},   &.{0, 0},      false);
    try testAccum(.sub, &.{100, 1},    &.{1, 1},   &.{99, 0},     false);
    try testAccum(.sub, &.{100, 1},    &.{0, 1},   &.{100, 0},    false);
    try testAccum(.sub, &.{500, 1247}, &.{100, 1}, &.{400, 1246}, false);

    // carry, one limb
    try testAccum(.sub, &.{0},          &.{1},      &.{maxint},     true);
    try testAccum(.sub, &.{1},          &.{2},      &.{maxint},     true);
    try testAccum(.sub, &.{0},          &.{2},      &.{maxint - 1}, true);
    try testAccum(.sub, &.{maxint - 1}, &.{maxint}, &.{maxint},     true);
    try testAccum(.sub, &.{10},         &.{maxint}, &.{11},         true);

    // carry and carry propagation, multiple limbs
    try testAccum(.sub, &.{0, 0},          &.{1},      &.{maxint, maxint},        true);
    try testAccum(.sub, &.{0, 1},          &.{1},      &.{maxint, 0},             false);
    try testAccum(.sub, &.{0, 0},          &.{0, 1},   &.{0, maxint},             true);
    try testAccum(.sub, &.{10, 1},         &.{maxint}, &.{11, 0},                 false);
    try testAccum(.sub, &.{1024, maxint},  &.{maxint}, &.{1025, maxint - 1},      false);
    try testAccum(.sub, &.{0, 0, 0, 0, 1}, &.{1},      &(.{maxint} ** 4 ++ .{0}), false);
    try testAccum(.sub, &(.{0} ** 4),      &.{1},      &(.{maxint} ** 4),         true);
    try testAccum(.sub, &(.{0} ** 5),      &.{1},      &(.{maxint} ** 5),         true);
    try testAccum(.sub, &(.{0} ** 6),      &.{1},      &(.{maxint} ** 6),         true);
    try testAccum(.sub, &(.{0} ** 7),      &.{1},      &(.{maxint} ** 7),         true);
    try testAccum(.sub, &(.{0} ** 8),      &.{1},      &(.{maxint} ** 8),         true);
    try testAccum(.sub, &(.{0} ** 9),      &.{1},      &(.{maxint} ** 9),         true);
    // zig fmt: on
}

test "llaccum aliasing" {
    if (@sizeOf(Limb) < 2) return error.SkipZigTest;
    const maxint = maxInt(Limb);

    const buffer = try testing_allocator.alloc(Limb, 30);
    defer testing_allocator.free(buffer);

    const zeros = buffer[0..10];
    const ones = buffer[10..20];
    const maxints = buffer[20..];
    @memset(zeros, 0);
    @memset(ones, 1);
    @memset(maxints, maxint);

    try std.testing.expectEqual(false, llaccum(.add, zeros, zeros));
    try std.testing.expect(mem.allEqual(Limb, zeros, 0));
    try std.testing.expect(mem.allEqual(Limb, ones, 1));
    try std.testing.expect(mem.allEqual(Limb, maxints, maxint));

    try std.testing.expectEqual(false, llaccum(.add, ones, ones));
    try std.testing.expect(mem.allEqual(Limb, zeros, 0));
    try std.testing.expect(mem.allEqual(Limb, ones, 2));
    try std.testing.expect(mem.allEqual(Limb, maxints, maxint));
    @memset(ones, 1);

    try std.testing.expectEqual(false, llaccum(.sub, ones, ones));
    try std.testing.expect(mem.allEqual(Limb, zeros, 0));
    try std.testing.expect(mem.allEqual(Limb, ones, 0));
    try std.testing.expect(mem.allEqual(Limb, maxints, maxint));
    @memset(ones, 1);

    try std.testing.expectEqual(false, llaccum(.add, zeros, buffer[5..15]));
    try std.testing.expect(mem.allEqual(Limb, zeros[0..5], 0));
    try std.testing.expect(mem.allEqual(Limb, ones, 1));
    try std.testing.expect(mem.allEqual(Limb, maxints, maxint));
    try std.testing.expectEqualSlices(Limb, &(.{0} ** 5 ++ .{1} ** 5), zeros);
    @memset(zeros, 0);

    try std.testing.expectEqual(true, llaccum(.add, ones, buffer[15..25]));
    try std.testing.expect(mem.allEqual(Limb, zeros, 0));
    try std.testing.expect(mem.allEqual(Limb, ones[0..5], 2));
    try std.testing.expectEqual(ones[5], 0);
    try std.testing.expect(mem.allEqual(Limb, ones[6..], 1));
    try std.testing.expect(mem.allEqual(Limb, maxints, maxint));
}

test "llmulLimb zero and empty slice" {
    if (@sizeOf(Limb) < 2) return error.SkipZigTest;
    const maxint = maxInt(Limb);

    inline for (&[2]AccOp{ .add, .sub }) |op| {
        // zig fmt: off
        inline for (0..13) |i| {
            try testMulLimb(op, &(.{0} ** i), &.{}, 0,      &(.{0} ** i), false);
            try testMulLimb(op, &(.{0} ** i), &.{}, 10,     &(.{0} ** i), false);
            try testMulLimb(op, &(.{0} ** i), &.{}, maxint, &(.{0} ** i), false);
        }
        try testMulLimb(op, &.{1},                              &.{},     0,       &.{1},                                 false);
        try testMulLimb(op, &.{1, 1, 1, 1, 1},                  &.{},     0,       &.{1, 1, 1, 1, 1},                     false);
        try testMulLimb(op, &.{1, 1, 1, 1, 1},                  &.{},     10,      &.{1, 1, 1, 1, 1},                     false);
        try testMulLimb(op, &.{1, 1, 1, 1, 1},                  &.{},     maxint,  &.{1, 1, 1, 1, 1},                     false);
        try testMulLimb(op, &.{15, 16, 89},                     &.{0, 0}, 0,       &.{15, 16, 89},                        false);
        try testMulLimb(op, &.{15, 16, 89},                     &.{0, 0}, 1589,    &.{15, 16, 89},                        false);
        try testMulLimb(op, &.{15, 16, 89},                     &.{0, 0}, maxint,  &.{15, 16, 89},                        false);
        try testMulLimb(op, &.{15, 16, 89, maxint, 7899, 5889}, &.{0, 0}, 0,       &.{15, 16, 89, maxint, 7899, 5889},    false);
        try testMulLimb(op, &.{15, 16, 89, maxint, 7899, 5889}, &.{0, 0}, 4897,    &.{15, 16, 89, maxint, 7899, 5889},    false);
        try testMulLimb(op, &.{15, 16, 89, maxint, 7899, 5889}, &.{0, 0}, 1235,    &.{15, 16, 89, maxint, 7899, 5889},    false);

        const slice = .{789, 123, 255, maxint - 12456, 879, 5839, 5346};

        inline for(0..7) |i| {
            try testMulLimb(op, &slice, &(.{0} ** i), maxint, &slice, false);
        }
        // zig fmt: on
    }
}

test llmulLimb {
    if (@sizeOf(Limb) < 2) return error.SkipZigTest;
    const maxint = maxInt(Limb);

    for (&[_]Limb{ 1, 2, 20, 4978, 1235, 1024, 11111, maxint - 1546, maxint }) |d| {
        try testMulLimb(.add, &.{0}, &.{d}, 1, &.{d}, false);
        try testMulLimb(.add, &.{0}, &.{1}, d, &.{d}, false);
    }
    // zig fmt: off
    try testMulLimb(.add, &.{10},           &.{278},    123,    &.{34204},         false);
    try testMulLimb(.add, &.{maxint - 125}, &.{25},     5,      &.{maxint},        false);
    try testMulLimb(.add, &.{1, 0},         &.{maxint}, 1,      &.{0, 1},          false);
    try testMulLimb(.add, &.{1, 1},         &.{maxint}, 1,      &.{0, 2},          false);
    try testMulLimb(.add, &.{0, 0},         &.{maxint}, maxint, &.{1, maxint - 1}, false);
    try testMulLimb(.add, &.{maxint, 0},    &.{maxint}, maxint, &.{0, maxint},     false);
    try testMulLimb(.add, &.{maxint, 1},    &.{maxint}, maxint, &.{0, 0},          true);
    try testMulLimb(.add, &.{maxint, 1, 3}, &.{maxint}, maxint, &.{0, 0, 4},       false);


    try testMulLimb(.add, &.{1, 1, 1, 1},                 &.{1, 1, 1, 1},                   maxint, &.{0, 1, 1, 1},                          true);
    try testMulLimb(.add, &.{1, 1, 1, 1, 1},              &.{1, 1, 1, 1},                   maxint, &.{0, 1, 1, 1, 2},                       false);
    try testMulLimb(.add, &.{1, 1, 1, 1, 1},              &.{1234, 4567, 5534, 23, 1},      10,     &.{12341, 45671, 55341, 231, 11},        false);
    try testMulLimb(.add, &.{1, 45, 64, 78, 100, maxint}, &.{1234, 4567, 5534, 23, 1, 128}, 10,     &.{12341, 45715, 55404, 308, 110, 1279}, true);


    for (&[_]Limb {1, 2, 20, 4978, 1235, 1024, 11111, maxint - 1546, maxint}) |d| {
        try testMulLimb(.sub, &.{d}, &.{d}, 1, &.{0}, false);
        try testMulLimb(.sub, &.{d}, &.{1}, d, &.{0}, false);
    }
    try testMulLimb(.sub, &.{2780},           &.{10},     123,    &.{1550},             false);
    try testMulLimb(.sub, &.{maxint},         &.{25},     5,      &.{maxint - 125},     false);
    try testMulLimb(.sub, &.{155, 1},         &.{12},     13,     &.{maxint, 0},        false);
    try testMulLimb(.sub, &.{1, 1},           &.{maxint}, 1,      &.{2, 0},             false);
    try testMulLimb(.sub, &.{0, 0},           &.{maxint}, maxint, &.{maxint, 1},        true);
    try testMulLimb(.sub, &.{maxint, maxint}, &.{maxint}, 1,      &.{0, maxint},        false);
    try testMulLimb(.sub, &.{maxint, 1},      &.{maxint}, maxint, &.{maxint - 1, 3},    true);
    try testMulLimb(.sub, &.{maxint, 1, 3},   &.{maxint}, maxint, &.{maxint - 1, 3, 2}, false);


    try testMulLimb(.sub, &.{0, 0, 0, 0},              &.{1}, 1, &.{maxint, maxint, maxint, maxint},   true);

    try testMulLimb(.sub, &.{0, 0, 0, 0},              &.{1, 1, 1, 1},       1,      &.{maxint, maxint - 1, maxint - 1, maxint - 1},                                   true);
    try testMulLimb(.sub, &.{123, 456, 789, 123, 456}, &(.{maxint} ** 4),    maxint, &.{122, 457, 789, 123, 457},                                                      true);
    try testMulLimb(.sub, &.{0, 0, 0, 0, 0},           &(.{maxint} ** 5),    1,      &.{1, 0, 0, 0, 0},                                                                true);
    try testMulLimb(.sub, &.{0, 0, 0, 0, 0},           &(.{maxint} ** 5),    maxint, &.{maxint, 0, 0, 0, 0},                                                           true);
    try testMulLimb(.sub, &(.{maxint} ** 6),           &.{1, 2, 3, 4, 5, 6}, 10,     &.{maxint - 10, maxint - 20, maxint - 30, maxint - 40, maxint - 50, maxint - 60}, false);
    // zig fmt: on
}

test "llmulLimb aliasing" {
    if (@sizeOf(Limb) < 2) return error.SkipZigTest;
    const maxint = maxInt(Limb);

    var data = [_]Limb{ 1, 1, 1, 1, 1, 1 };
    {
        const overflows = llmulLimb(.add, data[0..5], data[2..], 2);
        try std.testing.expectEqual(false, overflows);
        try std.testing.expectEqual(true, mem.allEqual(Limb, data[0..4], 3));
        try std.testing.expectEqual(1, data[4]);
        try std.testing.expectEqual(true, mem.allEqual(Limb, data[5..], 1));
        @memset(&data, 1);
    }

    {
        const overflows = llmulLimb(.sub, data[0..5], data[2..], 2);
        try std.testing.expectEqual(false, overflows);
        try std.testing.expectEqualSlices(Limb, &.{ maxint, maxint - 1, maxint - 1, maxint - 1, 0 }, data[0..5]);
        try std.testing.expectEqual(true, mem.allEqual(Limb, data[5..], 1));
        @memset(&data, 1);
    }

    // TODO: more tests
}

fn testMulLimb(comptime op: AccOp, a: []const Limb, b: []const Limb, d: Limb, expected: []const Limb, should_overflow: bool) !void {
    errdefer std.testing.print("\nwhile running: testMulLimb({}, {any}, {any}, {}, {any}, {})\n\n", .{ op, a, b, d, expected, should_overflow });
    assert(a.len == expected.len);

    const acc = try testing_allocator.alloc(Limb, a.len + 10);
    const y = try testing_allocator.alloc(Limb, b.len + 10);
    defer testing_allocator.free(acc);
    defer testing_allocator.free(y);

    @memset(acc, maxInt(Limb));
    @memset(y, maxInt(Limb));

    const acc_slice = acc[5..][0..a.len];
    const y_slice = y[5..][0..b.len];

    @memcpy(acc_slice, a);
    @memcpy(y_slice, b);

    const overflows = llmulLimb(op, acc_slice, y_slice, d);

    try std.testing.expectEqualSlices(Limb, expected, acc_slice);
    try std.testing.expectEqual(should_overflow, overflows);

    try std.testing.expect(mem.allEqual(Limb, acc[0..5], maxInt(Limb)));
    try std.testing.expect(mem.allEqual(Limb, acc[5 + a.len ..], maxInt(Limb)));
}

fn testAccum(comptime op: AccOp, a: []const Limb, b: []const Limb, expected: []const Limb, should_overflow: bool) !void {
    errdefer std.testing.print("\nwhile running: testAccum({}, {any}, {any}, {any}, {})\n\n", .{ op, a, b, expected, should_overflow });
    assert(a.len == expected.len);

    const acc = try testing_allocator.alloc(Limb, a.len + 10);
    const y = try testing_allocator.alloc(Limb, b.len + 10);
    defer testing_allocator.free(acc);
    defer testing_allocator.free(y);

    @memset(acc, maxInt(Limb));
    @memset(y, maxInt(Limb));

    const acc_slice = acc[5..][0..a.len];
    const y_slice = y[5..][0..b.len];

    @memcpy(acc_slice, a);
    @memcpy(y_slice, b);

    const overflows = llaccum(op, acc_slice, y_slice);

    try std.testing.expectEqualSlices(Limb, expected, acc_slice);
    try std.testing.expectEqual(should_overflow, overflows);

    try std.testing.expect(mem.allEqual(Limb, acc[0..5], maxInt(Limb)));
    try std.testing.expect(mem.allEqual(Limb, acc[5 + a.len ..], maxInt(Limb)));
}
