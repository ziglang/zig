const std = @import("../../std.zig");
const math = std.math;
const Limb = std.math.big.Limb;
const limb_bits = @typeInfo(Limb).Int.bits;
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

const debug_safety = false;

/// Returns the number of limbs needed to store `scalar`, which must be a
/// primitive integer value.
pub fn calcLimbLen(scalar: anytype) usize {
    if (scalar == 0) {
        return 1;
    }

    const w_value = std.math.absCast(scalar);
    return @divFloor(@intCast(Limb, math.log2(w_value)), limb_bits) + 1;
}

pub fn calcToStringLimbsBufferLen(a_len: usize, base: u8) usize {
    if (math.isPowerOfTwo(base))
        return 0;
    return a_len + 2 + a_len + calcDivLimbsBufferLen(a_len, 1);
}

pub fn calcDivLimbsBufferLen(a_len: usize, b_len: usize) usize {
    return calcMulLimbsBufferLen(a_len, b_len, 2) * 4;
}

pub fn calcMulLimbsBufferLen(a_len: usize, b_len: usize, aliases: usize) usize {
    return aliases * math.max(a_len, b_len);
}

pub fn calcMulWrapLimbsBufferLen(bit_count: usize, a_len: usize, b_len: usize, aliases: usize) usize {
    const req_limbs = calcTwosCompLimbCount(bit_count);
    return aliases * math.min(req_limbs, math.max(a_len, b_len));
}

pub fn calcSetStringLimbsBufferLen(base: u8, string_len: usize) usize {
    const limb_count = calcSetStringLimbCount(base, string_len);
    return calcMulLimbsBufferLen(limb_count, limb_count, 2);
}

pub fn calcSetStringLimbCount(base: u8, string_len: usize) usize {
    return (string_len + (limb_bits / base - 1)) / (limb_bits / base);
}

pub fn calcPowLimbsBufferLen(a_bit_count: usize, y: usize) usize {
    // The 2 accounts for the minimum space requirement for llmulacc
    return 2 + (a_bit_count * y + (limb_bits - 1)) / limb_bits;
}

// Compute the number of limbs required to store a 2s-complement number of `bit_count` bits.
pub fn calcTwosCompLimbCount(bit_count: usize) usize {
    return std.math.divCeil(usize, bit_count, @bitSizeOf(Limb)) catch unreachable;
}

/// a + b * c + *carry, sets carry to the overflow bits
pub fn addMulLimbWithCarry(a: Limb, b: Limb, c: Limb, carry: *Limb) Limb {
    @setRuntimeSafety(debug_safety);
    var r1: Limb = undefined;

    // r1 = a + *carry
    const c1: Limb = @boolToInt(@addWithOverflow(Limb, a, carry.*, &r1));

    // r2 = b * c
    const bc = @as(DoubleLimb, math.mulWide(Limb, b, c));
    const r2 = @truncate(Limb, bc);
    const c2 = @truncate(Limb, bc >> limb_bits);

    // r1 = r1 + r2
    const c3: Limb = @boolToInt(@addWithOverflow(Limb, r1, r2, &r1));

    // This never overflows, c1, c3 are either 0 or 1 and if both are 1 then
    // c2 is at least <= maxInt(Limb) - 2.
    carry.* = c1 + c2 + c3;

    return r1;
}

/// a - b * c - *carry, sets carry to the overflow bits
fn subMulLimbWithBorrow(a: Limb, b: Limb, c: Limb, carry: *Limb) Limb {
    // r1 = a - *carry
    var r1: Limb = undefined;
    const c1: Limb = @boolToInt(@subWithOverflow(Limb, a, carry.*, &r1));

    // r2 = b * c
    const bc = @as(DoubleLimb, std.math.mulWide(Limb, b, c));
    const r2 = @truncate(Limb, bc);
    const c2 = @truncate(Limb, bc >> limb_bits);

    // r1 = r1 - r2
    const c3: Limb = @boolToInt(@subWithOverflow(Limb, r1, r2, &r1));
    carry.* = c1 + c2 + c3;

    return r1;
}

/// Used to indicate either limit of a 2s-complement integer.
pub const TwosCompIntLimit = enum {
    // The low limit, either 0x00 (unsigned) or (-)0x80 (signed) for an 8-bit integer.
    min,

    // The high limit, either 0xFF (unsigned) or 0x7F (signed) for an 8-bit integer.
    max,
};

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

    /// Asserts that the allocator owns the limbs memory. If this is not the case,
    /// use `toConst().toManaged()`.
    pub fn toManaged(self: Mutable, allocator: *Allocator) Managed {
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
            mem.copy(Limb, self.limbs[0..], other.limbs[0..other.limbs.len]);
        }
        self.positive = other.positive;
        self.len = other.limbs.len;
    }

    /// Efficiently swap an Mutable with another. This swaps the limb pointers and a full copy is not
    /// performed. The address of the limbs field will not be the same after this function.
    pub fn swap(self: *Mutable, other: *Mutable) void {
        mem.swap(Mutable, self, other);
    }

    pub fn dump(self: Mutable) void {
        for (self.limbs[0..self.len]) |limb| {
            std.debug.warn("{x} ", .{limb});
        }
        std.debug.warn("capacity={} positive={}\n", .{ self.limbs.len, self.positive });
    }

    /// Clones an Mutable and returns a new Mutable with the same value. The new Mutable is a deep copy and
    /// can be modified separately from the original.
    /// Asserts that limbs is big enough to store the value.
    pub fn clone(other: Mutable, limbs: []Limb) Mutable {
        mem.copy(Limb, limbs, other.limbs[0..other.len]);
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
            .Int => |info| {
                var w_value = std.math.absCast(value);

                if (info.bits <= limb_bits) {
                    self.limbs[0] = w_value;
                } else {
                    var i: usize = 0;
                    while (w_value != 0) : (i += 1) {
                        self.limbs[i] = @truncate(Limb, w_value);

                        // TODO: shift == 64 at compile-time fails. Fails on u128 limbs.
                        w_value >>= limb_bits / 2;
                        w_value >>= limb_bits / 2;
                    }
                }
            },
            .ComptimeInt => {
                comptime var w_value = std.math.absCast(value);

                if (w_value <= maxInt(Limb)) {
                    self.limbs[0] = w_value;
                } else {
                    const mask = (1 << limb_bits) - 1;

                    comptime var i = 0;
                    inline while (w_value != 0) : (i += 1) {
                        self.limbs[i] = w_value & mask;

                        w_value >>= limb_bits / 2;
                        w_value >>= limb_bits / 2;
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
    /// Asserts there is enough memory for the value in `self.limbs`. An upper bound on number of limbs can
    /// be determined with `calcSetStringLimbCount`.
    /// Asserts the base is in the range [2, 16].
    ///
    /// Returns an error if the value has invalid digits for the requested base.
    ///
    /// `limbs_buffer` is used for temporary storage. The size required can be found with
    /// `calcSetStringLimbsBufferLen`.
    ///
    /// If `allocator` is provided, it will be used for temporary storage to improve
    /// multiplication performance. `error.OutOfMemory` is handled with a fallback algorithm.
    pub fn setString(
        self: *Mutable,
        base: u8,
        value: []const u8,
        limbs_buffer: []Limb,
        allocator: ?*Allocator,
    ) error{InvalidCharacter}!void {
        assert(base >= 2 and base <= 16);

        var i: usize = 0;
        var positive = true;
        if (value.len > 0 and value[0] == '-') {
            positive = false;
            i += 1;
        }

        const ap_base: Const = .{ .limbs = &[_]Limb{base}, .positive = true };
        self.set(0);

        for (value[i..]) |ch| {
            if (ch == '_') {
                continue;
            }
            const d = try std.fmt.charToDigit(ch, base);
            const ap_d: Const = .{ .limbs = &[_]Limb{d}, .positive = true };

            self.mul(self.toConst(), ap_base, limbs_buffer, allocator);
            self.add(self.toConst(), ap_d);
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
        const bit = @truncate(Log2Limb, bit_count - 1);
        const signmask = @as(Limb, 1) << bit; // 0b0..010..0 where 1 is the sign bit.
        const mask = (signmask << 1) -% 1; // 0b0..011..1 where the leftmost 1 is the sign bit.

        r.positive = true;

        switch (signedness) {
            .signed => switch (limit) {
                .min => {
                    // Negative bound, signed = -0x80.
                    r.len = req_limbs;
                    mem.set(Limb, r.limbs[0 .. r.len - 1], 0);
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
                        const msb = @truncate(Log2Limb, bit_count - 2);
                        const new_signmask = @as(Limb, 1) << msb; // 0b0..010..0 where 1 is the sign bit.
                        const new_mask = (new_signmask << 1) -% 1; // 0b0..001..1 where the rightmost 0 is the sign bit.

                        r.len = new_req_limbs;
                        std.mem.set(Limb, r.limbs[0 .. r.len - 1], maxInt(Limb));
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
                    std.mem.set(Limb, r.limbs[0 .. r.len - 1], maxInt(Limb));
                    r.limbs[r.len - 1] = mask;
                },
            },
        }
    }

    /// r = a + scalar
    ///
    /// r and a may be aliases.
    /// scalar is a primitive integer type.
    ///
    /// Asserts the result fits in `r`. An upper bound on the number of limbs needed by
    /// r is `math.max(a.limbs.len, calcLimbLen(scalar)) + 1`.
    pub fn addScalar(r: *Mutable, a: Const, scalar: anytype) void {
        var limbs: [calcLimbLen(scalar)]Limb = undefined;
        const operand = init(&limbs, scalar).toConst();
        return add(r, a, operand);
    }

    /// Base implementation for addition. Adds `max(a.limbs.len, b.limbs.len)` elements from a and b,
    /// and returns whether any overflow occured.
    /// r, a and b may be aliases.
    ///
    /// Asserts r has enough elements to hold the result. The upper bound is `max(a.limbs.len, b.limbs.len)`.
    fn addCarry(r: *Mutable, a: Const, b: Const) bool {
        if (a.eqZero()) {
            r.copy(b);
            return false;
        } else if (b.eqZero()) {
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
    /// r, a and b may be aliases.
    ///
    /// Asserts the result fits in `r`. An upper bound on the number of limbs needed by
    /// r is `math.max(a.limbs.len, b.limbs.len) + 1`.
    pub fn add(r: *Mutable, a: Const, b: Const) void {
        if (r.addCarry(a, b)) {
            // Fix up the result. Note that addCarry normalizes by a.limbs.len or b.limbs.len,
            // so we need to set the length here.
            const msl = math.max(a.limbs.len, b.limbs.len);
            // `[add|sub]Carry` normalizes by `msl`, so we need to fix up the result manually here.
            // Note, the fact that it normalized means that the intermediary limbs are zero here.
            r.len = msl + 1;
            r.limbs[msl] = 1; // If this panics, there wasn't enough space in `r`.
        }
    }

    /// r = a + b with 2s-complement wrapping semantics.
    /// r, a and b may be aliases
    ///
    /// Asserts the result fits in `r`. An upper bound on the number of limbs needed by
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn addWrap(r: *Mutable, a: Const, b: Const, signedness: Signedness, bit_count: usize) void {
        const req_limbs = calcTwosCompLimbCount(bit_count);

        // Slice of the upper bits if they exist, these will be ignored and allows us to use addCarry to determine
        // if an overflow occured.
        const x = Const{
            .positive = a.positive,
            .limbs = a.limbs[0..math.min(req_limbs, a.limbs.len)],
        };

        const y = Const{
            .positive = b.positive,
            .limbs = b.limbs[0..math.min(req_limbs, b.limbs.len)],
        };

        if (r.addCarry(x, y)) {
            // There are two possibilities here:
            // - We overflowed req_limbs. In this case, the carry is ignored, as it would be removed by
            //   truncate anyway.
            // - a and b had less elements than req_limbs, and those were overflowed. This case needs to be handled.
            //   Note: after this we still might need to wrap.
            const msl = math.max(a.limbs.len, b.limbs.len);
            if (msl < req_limbs) {
                r.limbs[msl] = 1;
                r.len = req_limbs;
            }
        }

        r.truncate(r.toConst(), signedness, bit_count);
    }

    /// r = a + b with 2s-complement saturating semantics.
    /// r, a and b may be aliases.
    ///
    /// Assets the result fits in `r`. Upper bound on the number of limbs needed by
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn addSat(r: *Mutable, a: Const, b: Const, signedness: Signedness, bit_count: usize) void {
        const req_limbs = calcTwosCompLimbCount(bit_count);

        // Slice of the upper bits if they exist, these will be ignored and allows us to use addCarry to determine
        // if an overflow occured.
        const x = Const{
            .positive = a.positive,
            .limbs = a.limbs[0..math.min(req_limbs, a.limbs.len)],
        };

        const y = Const{
            .positive = b.positive,
            .limbs = b.limbs[0..math.min(req_limbs, b.limbs.len)],
        };

        if (r.addCarry(x, y)) {
            // There are two possibilities here:
            // - We overflowed req_limbs, in which case we need to saturate.
            // - a and b had less elements than req_limbs, and those were overflowed.
            //   Note: In this case, might _also_ need to saturate.
            const msl = math.max(a.limbs.len, b.limbs.len);
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

    /// Base implementation for subtraction. Subtracts `max(a.limbs.len, b.limbs.len)` elements from a and b,
    /// and returns whether any overflow occured.
    /// r, a and b may be aliases.
    ///
    /// Asserts r has enough elements to hold the result. The upper bound is `max(a.limbs.len, b.limbs.len)`.
    fn subCarry(r: *Mutable, a: Const, b: Const) bool {
        if (a.eqZero()) {
            r.copy(b);
            r.positive = !b.positive;
            return false;
        } else if (b.eqZero()) {
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
    /// r is `math.max(a.limbs.len, b.limbs.len) + 1`. The +1 is not needed if both operands are positive.
    pub fn sub(r: *Mutable, a: Const, b: Const) void {
        r.add(a, b.negate());
    }

    /// r = a - b with 2s-complement wrapping semantics.
    ///
    /// r, a and b may be aliases
    /// Asserts the result fits in `r`. An upper bound on the number of limbs needed by
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn subWrap(r: *Mutable, a: Const, b: Const, signedness: Signedness, bit_count: usize) void {
        r.addWrap(a, b.negate(), signedness, bit_count);
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
    pub fn mul(rma: *Mutable, a: Const, b: Const, limbs_buffer: []Limb, allocator: ?*Allocator) void {
        var buf_index: usize = 0;

        const a_copy = if (rma.limbs.ptr == a.limbs.ptr) blk: {
            const start = buf_index;
            mem.copy(Limb, limbs_buffer[buf_index..], a.limbs);
            buf_index += a.limbs.len;
            break :blk a.toMutable(limbs_buffer[start..buf_index]).toConst();
        } else a;

        const b_copy = if (rma.limbs.ptr == b.limbs.ptr) blk: {
            const start = buf_index;
            mem.copy(Limb, limbs_buffer[buf_index..], b.limbs);
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
    pub fn mulNoAlias(rma: *Mutable, a: Const, b: Const, allocator: ?*Allocator) void {
        assert(rma.limbs.ptr != a.limbs.ptr); // illegal aliasing
        assert(rma.limbs.ptr != b.limbs.ptr); // illegal aliasing

        if (a.limbs.len == 1 and b.limbs.len == 1) {
            if (!@mulWithOverflow(Limb, a.limbs[0], b.limbs[0], &rma.limbs[0])) {
                rma.len = 1;
                rma.positive = (a.positive == b.positive);
                return;
            }
        }

        mem.set(Limb, rma.limbs[0 .. a.limbs.len + b.limbs.len], 0);

        llmulacc(.add, allocator, rma.limbs, a.limbs, b.limbs);

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
        allocator: ?*Allocator,
    ) void {
        var buf_index: usize = 0;
        const req_limbs = calcTwosCompLimbCount(bit_count);

        const a_copy = if (rma.limbs.ptr == a.limbs.ptr) blk: {
            const start = buf_index;
            const a_len = math.min(req_limbs, a.limbs.len);
            mem.copy(Limb, limbs_buffer[buf_index..], a.limbs[0..a_len]);
            buf_index += a_len;
            break :blk a.toMutable(limbs_buffer[start..buf_index]).toConst();
        } else a;

        const b_copy = if (rma.limbs.ptr == b.limbs.ptr) blk: {
            const start = buf_index;
            const b_len = math.min(req_limbs, b.limbs.len);
            mem.copy(Limb, limbs_buffer[buf_index..], b.limbs[0..b_len]);
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
        allocator: ?*Allocator,
    ) void {
        assert(rma.limbs.ptr != a.limbs.ptr); // illegal aliasing
        assert(rma.limbs.ptr != b.limbs.ptr); // illegal aliasing

        const req_limbs = calcTwosCompLimbCount(bit_count);

        // We can ignore the upper bits here, those results will be discarded anyway.
        const a_limbs = a.limbs[0..math.min(req_limbs, a.limbs.len)];
        const b_limbs = b.limbs[0..math.min(req_limbs, b.limbs.len)];

        mem.set(Limb, rma.limbs[0..req_limbs], 0);

        llmulacc(.add, allocator, rma.limbs, a_limbs, b_limbs);
        rma.normalize(math.min(req_limbs, a.limbs.len + b.limbs.len));
        rma.positive = (a.positive == b.positive);
        rma.truncate(rma.toConst(), signedness, bit_count);
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
    pub fn sqrNoAlias(rma: *Mutable, a: Const, opt_allocator: ?*Allocator) void {
        _ = opt_allocator;
        assert(rma.limbs.ptr != a.limbs.ptr); // illegal aliasing

        mem.set(Limb, rma.limbs, 0);

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
    /// The upper bound for r limb count is a.limbs.len.
    /// The upper bound for q limb count is given by `a.limbs.len + b.limbs.len + 1`.
    ///
    /// If `allocator` is provided, it will be used for temporary storage to improve
    /// multiplication performance. `error.OutOfMemory` is handled with a fallback algorithm.
    ///
    /// `limbs_buffer` is used for temporary storage. The amount required is given by `calcDivLimbsBufferLen`.
    pub fn divFloor(
        q: *Mutable,
        r: *Mutable,
        a: Const,
        b: Const,
        limbs_buffer: []Limb,
        allocator: ?*Allocator,
    ) void {
        div(q, r, a, b, limbs_buffer, allocator);

        // Trunc -> Floor.
        if (!q.positive) {
            const one: Const = .{ .limbs = &[_]Limb{1}, .positive = true };
            q.sub(q.toConst(), one);
            r.add(q.toConst(), one);
        }
        r.positive = b.positive;
    }

    /// q = a / b (rem r)
    ///
    /// a / b are truncated (rounded towards -inf).
    /// q may alias with a or b.
    ///
    /// Asserts there is enough memory to store q and r.
    /// The upper bound for r limb count is a.limbs.len.
    /// The upper bound for q limb count is given by `calcQuotientLimbLen`. This accounts
    /// for temporary space used by the division algorithm.
    ///
    /// If `allocator` is provided, it will be used for temporary storage to improve
    /// multiplication performance. `error.OutOfMemory` is handled with a fallback algorithm.
    ///
    /// `limbs_buffer` is used for temporary storage. The amount required is given by `calcDivLimbsBufferLen`.
    pub fn divTrunc(
        q: *Mutable,
        r: *Mutable,
        a: Const,
        b: Const,
        limbs_buffer: []Limb,
        allocator: ?*Allocator,
    ) void {
        div(q, r, a, b, limbs_buffer, allocator);
        r.positive = a.positive;
    }

    /// r = a << shift, in other words, r = a * 2^shift
    ///
    /// r and a may alias.
    ///
    /// Asserts there is enough memory to fit the result. The upper bound Limb count is
    /// `a.limbs.len + (shift / (@sizeOf(Limb) * 8))`.
    pub fn shiftLeft(r: *Mutable, a: Const, shift: usize) void {
        llshl(r.limbs[0..], a.limbs[0..a.limbs.len], shift);
        r.normalize(a.limbs.len + (shift / limb_bits) + 1);
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
            if (a.eqZero()) {
                r.set(0);
            } else {
                r.setTwosCompIntLimit(if (a.positive) .max else .min, signedness, bit_count);
            }
            return;
        }

        const checkbit = bit_count - shift - @boolToInt(signedness == .signed);
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

        // Generate a mask with the bits to check in the most signficant limb. We'll need to check
        // all bits with equal or more significance than checkbit.
        // const msb = @truncate(Log2Limb, checkbit);
        // const checkmask = (@as(Limb, 1) << msb) -% 1;

        if (a.limbs[a.limbs.len - 1] >> @truncate(Log2Limb, checkbit) != 0) {
            // Need to saturate.
            r.setTwosCompIntLimit(if (a.positive) .max else .min, signedness, bit_count);
            return;
        }

        // This shift should not be able to overflow, so invoke llshl and normalize manually
        // to avoid the extra required limb.
        llshl(r.limbs[0..], a.limbs[0..a.limbs.len], shift);
        r.normalize(a.limbs.len + (shift / limb_bits));
        r.positive = a.positive;
    }

    /// r = a >> shift
    /// r and a may alias.
    ///
    /// Asserts there is enough memory to fit the result. The upper bound Limb count is
    /// `a.limbs.len - (shift / (@sizeOf(Limb) * 8))`.
    pub fn shiftRight(r: *Mutable, a: Const, shift: usize) void {
        if (a.limbs.len <= shift / limb_bits) {
            r.len = 1;
            r.positive = true;
            r.limbs[0] = 0;
            return;
        }

        llshr(r.limbs[0..], a.limbs[0..a.limbs.len], shift);
        r.normalize(a.limbs.len - (shift / limb_bits));
        r.positive = a.positive;
    }

    /// r = ~a under 2s complement wrapping semantics.
    /// r may alias with a.
    ///
    /// Assets that r has enough limbs to store the result. The upper bound Limb count is
    /// r is `calcTwosCompLimbCount(bit_count)`.
    pub fn bitNotWrap(r: *Mutable, a: Const, signedness: Signedness, bit_count: usize) void {
        r.copy(a.negate());
        const negative_one = Const{ .limbs = &.{1}, .positive = false };
        r.addWrap(r.toConst(), negative_one, signedness, bit_count);
    }

    /// r = a | b under 2s complement semantics.
    /// r may alias with a or b.
    ///
    /// a and b are zero-extended to the longer of a or b.
    ///
    /// Asserts that r has enough limbs to store the result. Upper bound is `math.max(a.limbs.len, b.limbs.len)`.
    pub fn bitOr(r: *Mutable, a: Const, b: Const) void {
        // Trivial cases, llsignedor does not support zero.
        if (a.eqZero()) {
            r.copy(b);
            return;
        } else if (b.eqZero()) {
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
    /// If a or b is positive, the upper bound is `math.min(a.limbs.len, b.limbs.len)`.
    /// If a and b are negative, the upper bound is `math.max(a.limbs.len, b.limbs.len) + 1`.
    pub fn bitAnd(r: *Mutable, a: Const, b: Const) void {
        // Trivial cases, llsignedand does not support zero.
        if (a.eqZero()) {
            r.copy(a);
            return;
        } else if (b.eqZero()) {
            r.copy(b);
            return;
        }

        if (a.limbs.len >= b.limbs.len) {
            r.positive = llsignedand(r.limbs, a.limbs, a.positive, b.limbs, b.positive);
            r.normalize(if (a.positive or b.positive) b.limbs.len else a.limbs.len + 1);
        } else {
            r.positive = llsignedand(r.limbs, b.limbs, b.positive, a.limbs, a.positive);
            r.normalize(if (a.positive or b.positive) a.limbs.len else b.limbs.len + 1);
        }
    }

    /// r = a ^ b under 2s complement semantics.
    /// r may alias with a or b.
    ///
    /// Asserts that r has enough limbs to store the result. If a and b share the same signedness, the
    /// upper bound is `math.max(a.limbs.len, b.limbs.len)`. Otherwise, if either a or b is negative
    /// but not both, the upper bound is `math.max(a.limbs.len, b.limbs.len) + 1`.
    pub fn bitXor(r: *Mutable, a: Const, b: Const) void {
        // Trivial cases, because llsignedxor does not support negative zero.
        if (a.eqZero()) {
            r.copy(b);
            return;
        } else if (b.eqZero()) {
            r.copy(a);
            return;
        }

        if (a.limbs.len > b.limbs.len) {
            r.positive = llsignedxor(r.limbs, a.limbs, a.positive, b.limbs, b.positive);
            r.normalize(a.limbs.len + @boolToInt(a.positive != b.positive));
        } else {
            r.positive = llsignedxor(r.limbs, b.limbs, b.positive, a.limbs, a.positive);
            r.normalize(b.limbs.len + @boolToInt(a.positive != b.positive));
        }
    }

    /// rma may alias x or y.
    /// x and y may alias each other.
    /// Asserts that `rma` has enough limbs to store the result. Upper bound is
    /// `math.min(x.limbs.len, y.limbs.len)`.
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
    pub fn pow(r: *Mutable, a: Const, b: u32, limbs_buffer: []Limb) !void {
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

        if (a.eqZero()) {
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

        while (y.len() > 1) {
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
                try r.divTrunc(&t_big, x.toConst(), y.toConst());
                assert(t_big.isPositive());

                x.swap(&y);
                y.swap(&t_big);
            } else {
                var storage: [8]Limb = undefined;
                const Ap = fixedIntFromSignedDoubleLimb(A, storage[0..2]).toConst();
                const Bp = fixedIntFromSignedDoubleLimb(B, storage[2..4]).toConst();
                const Cp = fixedIntFromSignedDoubleLimb(C, storage[4..6]).toConst();
                const Dp = fixedIntFromSignedDoubleLimb(D, storage[6..8]).toConst();

                // t_big = Ax + By
                try r.mul(x.toConst(), Ap);
                try t_big.mul(y.toConst(), Bp);
                try t_big.add(r.toConst(), t_big.toConst());

                // u = Cx + Dy, r as u
                try tmp_x.copy(x.toConst());
                try x.mul(tmp_x.toConst(), Cp);
                try r.mul(y.toConst(), Dp);
                try r.add(x.toConst(), r.toConst());

                x.swap(&t_big);
                y.swap(&r);
            }
        }

        // euclidean algorithm
        assert(x.toConst().order(y.toConst()) != .lt);

        while (!y.toConst().eqZero()) {
            try t_big.divTrunc(&r, x.toConst(), y.toConst());
            x.swap(&y);
            y.swap(&r);
        }

        result.copy(x.toConst());
    }

    /// Truncates by default.
    fn div(quo: *Mutable, rem: *Mutable, a: Const, b: Const, limbs_buffer: []Limb, allocator: ?*Allocator) void {
        assert(!b.eqZero()); // division by zero
        assert(quo != rem); // illegal aliasing

        if (a.orderAbs(b) == .lt) {
            // quo may alias a so handle rem first
            rem.copy(a);
            rem.positive = a.positive == b.positive;

            quo.positive = true;
            quo.len = 1;
            quo.limbs[0] = 0;
            return;
        }

        // Handle trailing zero-words of divisor/dividend. These are not handled in the following
        // algorithms.
        const a_zero_limb_count = blk: {
            var i: usize = 0;
            while (i < a.limbs.len) : (i += 1) {
                if (a.limbs[i] != 0) break;
            }
            break :blk i;
        };
        const b_zero_limb_count = blk: {
            var i: usize = 0;
            while (i < b.limbs.len) : (i += 1) {
                if (b.limbs[i] != 0) break;
            }
            break :blk i;
        };

        const ab_zero_limb_count = math.min(a_zero_limb_count, b_zero_limb_count);

        if (b.limbs.len - ab_zero_limb_count == 1) {
            lldiv1(quo.limbs[0..], &rem.limbs[0], a.limbs[ab_zero_limb_count..a.limbs.len], b.limbs[b.limbs.len - 1]);
            quo.normalize(a.limbs.len - ab_zero_limb_count);
            quo.positive = (a.positive == b.positive);

            rem.len = 1;
            rem.positive = true;
        } else {
            // x and y are modified during division
            const sep_len = calcMulLimbsBufferLen(a.limbs.len, b.limbs.len, 2);
            const x_limbs = limbs_buffer[0 * sep_len ..][0..sep_len];
            const y_limbs = limbs_buffer[1 * sep_len ..][0..sep_len];
            const t_limbs = limbs_buffer[2 * sep_len ..][0..sep_len];
            const mul_limbs_buf = limbs_buffer[3 * sep_len ..][0..sep_len];

            var x: Mutable = .{
                .limbs = x_limbs,
                .positive = a.positive,
                .len = a.limbs.len - ab_zero_limb_count,
            };
            var y: Mutable = .{
                .limbs = y_limbs,
                .positive = b.positive,
                .len = b.limbs.len - ab_zero_limb_count,
            };

            // Shrink x, y such that the trailing zero limbs shared between are removed.
            mem.copy(Limb, x.limbs, a.limbs[ab_zero_limb_count..a.limbs.len]);
            mem.copy(Limb, y.limbs, b.limbs[ab_zero_limb_count..b.limbs.len]);

            divN(quo, rem, &x, &y, t_limbs, mul_limbs_buf, allocator);
            quo.positive = (a.positive == b.positive);
        }

        if (ab_zero_limb_count != 0) {
            rem.shiftLeft(rem.toConst(), ab_zero_limb_count * limb_bits);
        }
    }

    /// Handbook of Applied Cryptography, 14.20
    ///
    /// x = qy + r where 0 <= r < y
    fn divN(
        q: *Mutable,
        r: *Mutable,
        x: *Mutable,
        y: *Mutable,
        tmp_limbs: []Limb,
        mul_limb_buf: []Limb,
        allocator: ?*Allocator,
    ) void {
        assert(y.len >= 2);
        assert(x.len >= y.len);
        assert(q.limbs.len >= x.len + y.len - 1);

        // See 3.2
        var backup_tmp_limbs: [3]Limb = undefined;
        const t_limbs = if (tmp_limbs.len < 3) &backup_tmp_limbs else tmp_limbs;

        var tmp: Mutable = .{
            .limbs = t_limbs,
            .len = 1,
            .positive = true,
        };
        tmp.limbs[0] = 0;

        // Normalize so y > limb_bits / 2 (i.e. leading bit is set) and even
        var norm_shift = @clz(Limb, y.limbs[y.len - 1]);
        if (norm_shift == 0 and y.toConst().isOdd()) {
            norm_shift = limb_bits;
        }
        x.shiftLeft(x.toConst(), norm_shift);
        y.shiftLeft(y.toConst(), norm_shift);

        const n = x.len - 1;
        const t = y.len - 1;

        // 1.
        q.len = n - t + 1;
        q.positive = true;
        mem.set(Limb, q.limbs[0..q.len], 0);

        // 2.
        tmp.shiftLeft(y.toConst(), limb_bits * (n - t));
        while (x.toConst().order(tmp.toConst()) != .lt) {
            q.limbs[n - t] += 1;
            x.sub(x.toConst(), tmp.toConst());
        }

        // 3.
        var i = n;
        while (i > t) : (i -= 1) {
            // 3.1
            if (x.limbs[i] == y.limbs[t]) {
                q.limbs[i - t - 1] = maxInt(Limb);
            } else {
                const num = (@as(DoubleLimb, x.limbs[i]) << limb_bits) | @as(DoubleLimb, x.limbs[i - 1]);
                const z = @intCast(Limb, num / @as(DoubleLimb, y.limbs[t]));
                q.limbs[i - t - 1] = if (z > maxInt(Limb)) maxInt(Limb) else @as(Limb, z);
            }

            // 3.2
            tmp.limbs[0] = if (i >= 2) x.limbs[i - 2] else 0;
            tmp.limbs[1] = if (i >= 1) x.limbs[i - 1] else 0;
            tmp.limbs[2] = x.limbs[i];
            tmp.normalize(3);

            while (true) {
                // 2x1 limb multiplication unrolled against single-limb q[i-t-1]
                var carry: Limb = 0;
                r.limbs[0] = addMulLimbWithCarry(0, if (t >= 1) y.limbs[t - 1] else 0, q.limbs[i - t - 1], &carry);
                r.limbs[1] = addMulLimbWithCarry(0, y.limbs[t], q.limbs[i - t - 1], &carry);
                r.limbs[2] = carry;
                r.normalize(3);

                if (r.toConst().orderAbs(tmp.toConst()) != .gt) {
                    break;
                }

                q.limbs[i - t - 1] -= 1;
            }

            // 3.3
            tmp.set(q.limbs[i - t - 1]);
            tmp.mul(tmp.toConst(), y.toConst(), mul_limb_buf, allocator);
            tmp.shiftLeft(tmp.toConst(), limb_bits * (i - t - 1));
            x.sub(x.toConst(), tmp.toConst());

            if (!x.positive) {
                tmp.shiftLeft(y.toConst(), limb_bits * (i - t - 1));
                x.add(x.toConst(), tmp.toConst());
                q.limbs[i - t - 1] -= 1;
            }
        }

        // Denormalize
        q.normalize(q.len);

        r.shiftRight(x.toConst(), norm_shift);
        r.normalize(r.len);
    }

    /// Truncate an integer to a number of bits, following 2s-complement semantics.
    /// r may alias a.
    ///
    /// Asserts `r` has enough storage to store the result.
    /// The upper bound is `calcTwosCompLimbCount(a.len)`.
    pub fn truncate(r: *Mutable, a: Const, signedness: Signedness, bit_count: usize) void {
        const req_limbs = calcTwosCompLimbCount(bit_count);

        // Handle 0-bit integers.
        if (req_limbs == 0 or a.eqZero()) {
            r.set(0);
            return;
        }

        const bit = @truncate(Log2Limb, bit_count - 1);
        const signmask = @as(Limb, 1) << bit; // 0b0..010...0 where 1 is the sign bit.
        const mask = (signmask << 1) -% 1; // 0b0..01..1 where the leftmost 1 is the sign bit.

        if (!a.positive) {
            // Convert the integer from sign-magnitude into twos-complement.
            // -x = ~(x - 1)
            // Note, we simply take req_limbs * @bitSizeOf(Limb) as the
            // target bit count.

            r.addScalar(a.abs(), -1);

            // Zero-extend the result
            if (req_limbs > r.len) {
                mem.set(Limb, r.limbs[r.len..req_limbs], 0);
            }

            // Truncate to required number of limbs.
            assert(r.limbs.len >= req_limbs);
            r.len = req_limbs;

            // Without truncating, we can already peek at the sign bit of the result here.
            // Note that it will be 0 if the result is negative, as we did not apply the flip here.
            // If the result is negative, we have
            // -(-x & mask)
            // = ~(~(x - 1) & mask) + 1
            // = ~(~((x - 1) | ~mask)) + 1
            // = ((x - 1) | ~mask)) + 1
            // Note, this is only valid for the target bits and not the upper bits
            // of the most significant limb. Those still need to be cleared.
            // Also note that `mask` is zero for all other bits, reducing to the identity.
            // This means that we still need to use & mask to clear off the upper bits.

            if (signedness == .signed and r.limbs[r.len - 1] & signmask == 0) {
                // Re-add the one and negate to get the result.
                r.limbs[r.len - 1] &= mask;
                // Note, addition cannot require extra limbs here as we did a subtraction before.
                r.addScalar(r.toConst(), 1);
                r.normalize(r.len);
                r.positive = false;
            } else {
                llnot(r.limbs[0..r.len]);
                r.limbs[r.len - 1] &= mask;
                r.normalize(r.len);
            }
        } else {
            if (a.limbs.len < req_limbs) {
                // Integer fits within target bits, no wrapping required.
                r.copy(a);
                return;
            }

            r.copy(.{
                .positive = a.positive,
                .limbs = a.limbs[0..req_limbs],
            });
            r.limbs[r.len - 1] &= mask;
            r.normalize(r.len);

            if (signedness == .signed and r.limbs[r.len - 1] & signmask != 0) {
                // Convert 2s-complement back to sign-magnitude.
                // Sign-extend the upper bits so that they are inverted correctly.
                r.limbs[r.len - 1] |= ~mask;
                llnot(r.limbs[0..r.len]);

                // Note, can only overflow if r holds 0xFFF...F which can only happen if
                // a holds 0.
                r.addScalar(r.toConst(), 1);

                r.positive = false;
            }
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

    pub fn readTwosComplement(
        x: *Mutable,
        buffer: []const u8,
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
        // zig fmt: off
        switch (signedness) {
            .signed => {
                if (bit_count <=   8) return x.set(mem.readInt(  i8, buffer[0.. 1], endian));
                if (bit_count <=  16) return x.set(mem.readInt( i16, buffer[0.. 2], endian));
                if (bit_count <=  32) return x.set(mem.readInt( i32, buffer[0.. 4], endian));
                if (bit_count <=  64) return x.set(mem.readInt( i64, buffer[0.. 8], endian));
                if (bit_count <= 128) return x.set(mem.readInt(i128, buffer[0..16], endian));
            },
            .unsigned => {
                if (bit_count <=   8) return x.set(mem.readInt(  u8, buffer[0.. 1], endian));
                if (bit_count <=  16) return x.set(mem.readInt( u16, buffer[0.. 2], endian));
                if (bit_count <=  32) return x.set(mem.readInt( u32, buffer[0.. 4], endian));
                if (bit_count <=  64) return x.set(mem.readInt( u64, buffer[0.. 8], endian));
                if (bit_count <= 128) return x.set(mem.readInt(u128, buffer[0..16], endian));
            },
        }
        // zig fmt: on

        @panic("TODO implement std lib big int readTwosComplement");
    }

    /// Normalize a possible sequence of leading zeros.
    ///
    /// [1, 2, 3, 4, 0] -> [1, 2, 3, 4]
    /// [1, 2, 0, 0, 0] -> [1, 2]
    /// [0, 0, 0, 0, 0] -> [0]
    fn normalize(r: *Mutable, length: usize) void {
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
    pub fn toManaged(self: Const, allocator: *Allocator) Allocator.Error!Managed {
        const limbs = try allocator.alloc(Limb, math.max(Managed.default_capacity, self.limbs.len));
        mem.copy(Limb, limbs, self.limbs);
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
        mem.copy(Limb, limbs, self.limbs[0..self.limbs.len]);
        return .{
            .limbs = limbs,
            .positive = self.positive,
            .len = self.limbs.len,
        };
    }

    pub fn dump(self: Const) void {
        for (self.limbs[0..self.limbs.len]) |limb| {
            std.debug.warn("{x} ", .{limb});
        }
        std.debug.warn("positive={}\n", .{self.positive});
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
        return (self.limbs.len - 1) * limb_bits + (limb_bits - @clz(Limb, self.limbs[self.limbs.len - 1]));
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

            if (@popCount(Limb, self.limbs[self.limbs.len - 1]) == 1) {
                for (self.limbs[0 .. self.limbs.len - 1]) |limb| {
                    if (@popCount(Limb, limb) != 0) {
                        break :block;
                    }
                }

                bits -= 1;
            }
        }

        return bits;
    }

    pub fn fitsInTwosComp(self: Const, signedness: Signedness, bit_count: usize) bool {
        if (self.eqZero()) {
            return true;
        }
        if (signedness == .unsigned and !self.positive) {
            return false;
        }

        const req_bits = self.bitCountTwosComp() + @boolToInt(self.positive and signedness == .signed);
        return bit_count >= req_bits;
    }

    /// Returns whether self can fit into an integer of the requested type.
    pub fn fits(self: Const, comptime T: type) bool {
        const info = @typeInfo(T).Int;
        return self.fitsInTwosComp(info.signedness, info.bits);
    }

    /// Returns the approximate size of the integer in the given base. Negative values accommodate for
    /// the minus sign. This is used for determining the number of characters needed to print the
    /// value. It is inexact and may exceed the given value by ~1-2 bytes.
    /// TODO See if we can make this exact.
    pub fn sizeInBaseUpperBound(self: Const, base: usize) usize {
        const bit_count = @as(usize, @boolToInt(!self.positive)) + self.bitCountAbs();
        return (bit_count / math.log2(base)) + 2;
    }

    pub const ConvertError = error{
        NegativeIntoUnsigned,
        TargetTooSmall,
    };

    /// Convert self to type T.
    ///
    /// Returns an error if self cannot be narrowed into the requested type without truncation.
    pub fn to(self: Const, comptime T: type) ConvertError!T {
        switch (@typeInfo(T)) {
            .Int => |info| {
                const UT = std.meta.Int(.unsigned, info.bits);

                if (self.bitCountTwosComp() > info.bits) {
                    return error.TargetTooSmall;
                }

                var r: UT = 0;

                if (@sizeOf(UT) <= @sizeOf(Limb)) {
                    r = @intCast(UT, self.limbs[0]);
                } else {
                    for (self.limbs[0..self.limbs.len]) |_, ri| {
                        const limb = self.limbs[self.limbs.len - ri - 1];
                        r <<= limb_bits;
                        r |= limb;
                    }
                }

                if (info.signedness == .unsigned) {
                    return if (self.positive) @intCast(T, r) else error.NegativeIntoUnsigned;
                } else {
                    if (self.positive) {
                        return @intCast(T, r);
                    } else {
                        if (math.cast(T, r)) |ok| {
                            return -ok;
                        } else |_| {
                            return minInt(T);
                        }
                    }
                }
            },
            else => @compileError("cannot convert Const to type " ++ @typeName(T)),
        }
    }

    /// To allow `std.fmt.format` to work with this type.
    /// If the integer is larger than `pow(2, 64 * @sizeOf(usize) * 8), this function will fail
    /// to print the string, printing "(BigInt)" instead of a number.
    /// This is because the rendering algorithm requires reversing a string, which requires O(N) memory.
    /// See `toString` and `toStringAlloc` for a way to print big integers without failure.
    pub fn format(
        self: Const,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        out_stream: anytype,
    ) !void {
        _ = options;
        comptime var radix = 10;
        comptime var case: std.fmt.Case = .lower;

        if (fmt.len == 0 or comptime mem.eql(u8, fmt, "d")) {
            radix = 10;
            case = .lower;
        } else if (comptime mem.eql(u8, fmt, "b")) {
            radix = 2;
            case = .lower;
        } else if (comptime mem.eql(u8, fmt, "x")) {
            radix = 16;
            case = .lower;
        } else if (comptime mem.eql(u8, fmt, "X")) {
            radix = 16;
            case = .upper;
        } else {
            @compileError("Unknown format string: '" ++ fmt ++ "'");
        }

        var limbs: [128]Limb = undefined;
        const needed_limbs = calcDivLimbsBufferLen(self.limbs.len, 1);
        if (needed_limbs > limbs.len)
            return out_stream.writeAll("(BigInt)");

        // This is the inverse of calcDivLimbsBufferLen
        const available_len = (limbs.len / 3) - 2;

        const biggest: Const = .{
            .limbs = &([1]Limb{math.maxInt(Limb)} ** available_len),
            .positive = false,
        };
        var buf: [biggest.sizeInBaseUpperBound(radix)]u8 = undefined;
        const len = self.toString(&buf, radix, case, &limbs);
        return out_stream.writeAll(buf[0..len]);
    }

    /// Converts self to a string in the requested base.
    /// Caller owns returned memory.
    /// Asserts that `base` is in the range [2, 16].
    /// See also `toString`, a lower level function than this.
    pub fn toStringAlloc(self: Const, allocator: *Allocator, base: u8, case: std.fmt.Case) Allocator.Error![]u8 {
        assert(base >= 2);
        assert(base <= 16);

        if (self.eqZero()) {
            return allocator.dupe(u8, "0");
        }
        const string = try allocator.alloc(u8, self.sizeInBaseUpperBound(base));
        errdefer allocator.free(string);

        const limbs = try allocator.alloc(Limb, calcToStringLimbsBufferLen(self.limbs.len, base));
        defer allocator.free(limbs);

        return allocator.shrink(string, self.toString(string, base, case, limbs));
    }

    /// Converts self to a string in the requested base.
    /// Asserts that `base` is in the range [2, 16].
    /// `string` is a caller-provided slice of at least `sizeInBaseUpperBound` bytes,
    /// where the result is written to.
    /// Returns the length of the string.
    /// `limbs_buffer` is caller-provided memory for `toString` to use as a working area. It must have
    /// length of at least `calcToStringLimbsBufferLen`.
    /// In the case of power-of-two base, `limbs_buffer` is ignored.
    /// See also `toStringAlloc`, a higher level function than this.
    pub fn toString(self: Const, string: []u8, base: u8, case: std.fmt.Case, limbs_buffer: []Limb) usize {
        assert(base >= 2);
        assert(base <= 16);

        if (self.eqZero()) {
            string[0] = '0';
            return 1;
        }

        var digits_len: usize = 0;

        // Power of two: can do a single pass and use masks to extract digits.
        if (math.isPowerOfTwo(base)) {
            const base_shift = math.log2_int(Limb, base);

            outer: for (self.limbs[0..self.limbs.len]) |limb| {
                var shift: usize = 0;
                while (shift < limb_bits) : (shift += base_shift) {
                    const r = @intCast(u8, (limb >> @intCast(Log2Limb, shift)) & @as(Limb, base - 1));
                    const ch = std.fmt.digitToChar(r, case);
                    string[digits_len] = ch;
                    digits_len += 1;
                    // If we hit the end, it must be all zeroes from here.
                    if (digits_len == string.len) break :outer;
                }
            }

            // Always will have a non-zero digit somewhere.
            while (string[digits_len - 1] == '0') {
                digits_len -= 1;
            }
        } else {
            // Non power-of-two: batch divisions per word size.
            const digits_per_limb = math.log(Limb, base, maxInt(Limb));
            var limb_base: Limb = 1;
            var j: usize = 0;
            while (j < digits_per_limb) : (j += 1) {
                limb_base *= base;
            }
            const b: Const = .{ .limbs = &[_]Limb{limb_base}, .positive = true };

            var q: Mutable = .{
                .limbs = limbs_buffer[0 .. self.limbs.len + 2],
                .positive = true, // Make absolute by ignoring self.positive.
                .len = self.limbs.len,
            };
            mem.copy(Limb, q.limbs, self.limbs);

            var r: Mutable = .{
                .limbs = limbs_buffer[q.limbs.len..][0..self.limbs.len],
                .positive = true,
                .len = 1,
            };
            r.limbs[0] = 0;

            const rest_of_the_limbs_buf = limbs_buffer[q.limbs.len + r.limbs.len ..];

            while (q.len >= 2) {
                // Passing an allocator here would not be helpful since this division is destroying
                // information, not creating it. [TODO citation needed]
                q.divTrunc(&r, q.toConst(), b, rest_of_the_limbs_buf, null);

                var r_word = r.limbs[0];
                var i: usize = 0;
                while (i < digits_per_limb) : (i += 1) {
                    const ch = std.fmt.digitToChar(@intCast(u8, r_word % base), case);
                    r_word /= base;
                    string[digits_len] = ch;
                    digits_len += 1;
                }
            }

            {
                assert(q.len == 1);

                var r_word = q.limbs[0];
                while (r_word != 0) {
                    const ch = std.fmt.digitToChar(@intCast(u8, r_word % base), case);
                    r_word /= base;
                    string[digits_len] = ch;
                    digits_len += 1;
                }
            }
        }

        if (!self.positive) {
            string[digits_len] = '-';
            digits_len += 1;
        }

        const s = string[0..digits_len];
        mem.reverse(u8, s);
        return s.len;
    }

    /// Asserts that `buffer` and `bit_count` are large enough to store the value.
    pub fn writeTwosComplement(x: Const, buffer: []u8, bit_count: usize, endian: Endian) void {
        if (bit_count == 0) return;

        // zig fmt: off
        if (x.positive) {
            if (bit_count <=   8) return mem.writeInt(  u8, buffer[0.. 1], x.to(  u8) catch unreachable, endian);
            if (bit_count <=  16) return mem.writeInt( u16, buffer[0.. 2], x.to( u16) catch unreachable, endian);
            if (bit_count <=  32) return mem.writeInt( u32, buffer[0.. 4], x.to( u32) catch unreachable, endian);
            if (bit_count <=  64) return mem.writeInt( u64, buffer[0.. 8], x.to( u64) catch unreachable, endian);
            if (bit_count <= 128) return mem.writeInt(u128, buffer[0..16], x.to(u128) catch unreachable, endian);
        } else {
            if (bit_count <=   8) return mem.writeInt(  i8, buffer[0.. 1], x.to(  i8) catch unreachable, endian);
            if (bit_count <=  16) return mem.writeInt( i16, buffer[0.. 2], x.to( i16) catch unreachable, endian);
            if (bit_count <=  32) return mem.writeInt( i32, buffer[0.. 4], x.to( i32) catch unreachable, endian);
            if (bit_count <=  64) return mem.writeInt( i64, buffer[0.. 8], x.to( i64) catch unreachable, endian);
            if (bit_count <= 128) return mem.writeInt(i128, buffer[0..16], x.to(i128) catch unreachable, endian);
        }
        // zig fmt: on

        @panic("TODO implement std lib big int writeTwosComplement for larger than 128 bits");
    }

    /// Returns `math.Order.lt`, `math.Order.eq`, `math.Order.gt` if
    /// `|a| < |b|`, `|a| == |b|`, or `|a| > |b|` respectively.
    pub fn orderAbs(a: Const, b: Const) math.Order {
        if (a.limbs.len < b.limbs.len) {
            return .lt;
        }
        if (a.limbs.len > b.limbs.len) {
            return .gt;
        }

        var i: usize = a.limbs.len - 1;
        while (i != 0) : (i -= 1) {
            if (a.limbs[i] != b.limbs[i]) {
                break;
            }
        }

        if (a.limbs[i] < b.limbs[i]) {
            return .lt;
        } else if (a.limbs[i] > b.limbs[i]) {
            return .gt;
        } else {
            return .eq;
        }
    }

    /// Returns `math.Order.lt`, `math.Order.eq`, `math.Order.gt` if `a < b`, `a == b` or `a > b` respectively.
    pub fn order(a: Const, b: Const) math.Order {
        if (a.positive != b.positive) {
            return if (a.positive) .gt else .lt;
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
        var limbs: [calcLimbLen(scalar)]Limb = undefined;
        const rhs = Mutable.init(&limbs, scalar);
        return order(lhs, rhs.toConst());
    }

    /// Returns true if `a == 0`.
    pub fn eqZero(a: Const) bool {
        var d: Limb = 0;
        for (a.limbs) |limb| d |= limb;
        return d == 0;
    }

    /// Returns true if `|a| == |b|`.
    pub fn eqAbs(a: Const, b: Const) bool {
        return orderAbs(a, b) == .eq;
    }

    /// Returns true if `a == b`.
    pub fn eq(a: Const, b: Const) bool {
        return order(a, b) == .eq;
    }
};

/// An arbitrary-precision big integer along with an allocator which manages the memory.
///
/// Memory is allocated as needed to ensure operations never overflow. The range
/// is bounded only by available memory.
pub const Managed = struct {
    pub const sign_bit: usize = 1 << (@typeInfo(usize).Int.bits - 1);

    /// Default number of limbs to allocate on creation of a `Managed`.
    pub const default_capacity = 4;

    /// Allocator used by the Managed when requesting memory.
    allocator: *Allocator,

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
    pub fn init(allocator: *Allocator) !Managed {
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
    pub fn initSet(allocator: *Allocator, value: anytype) !Managed {
        var s = try Managed.init(allocator);
        try s.set(value);
        return s;
    }

    /// Creates a new Managed with a specific capacity. If capacity < default_capacity then the
    /// default capacity will be used instead.
    /// The integer value after initializing is `0`.
    pub fn initCapacity(allocator: *Allocator, capacity: usize) !Managed {
        return Managed{
            .allocator = allocator,
            .metadata = 1,
            .limbs = block: {
                const limbs = try allocator.alloc(Limb, math.max(default_capacity, capacity));
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

    pub fn cloneWithDifferentAllocator(other: Managed, allocator: *Allocator) !Managed {
        return Managed{
            .allocator = allocator,
            .metadata = other.metadata,
            .limbs = block: {
                var limbs = try allocator.alloc(Limb, other.len());
                mem.copy(Limb, limbs[0..], other.limbs[0..other.len()]);
                break :block limbs;
            },
        };
    }

    /// Copies the value of the integer to an existing `Managed` so that they both have the same value.
    /// Extra memory will be allocated if the receiver does not have enough capacity.
    pub fn copy(self: *Managed, other: Const) !void {
        if (self.limbs.ptr == other.limbs.ptr) return;

        try self.ensureCapacity(other.limbs.len);
        mem.copy(Limb, self.limbs[0..], other.limbs[0..other.limbs.len]);
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
            std.debug.warn("{x} ", .{limb});
        }
        std.debug.warn("capacity={} positive={}\n", .{ self.limbs.len, self.isPositive() });
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

    /// Convert self to type T.
    ///
    /// Returns an error if self cannot be narrowed into the requested type without truncation.
    pub fn to(self: Managed, comptime T: type) ConvertError!T {
        return self.toConst().to(T);
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
        if (base < 2 or base > 16) return error.InvalidBase;
        try self.ensureCapacity(calcSetStringLimbCount(base, value.len));
        const limbs_buffer = try self.allocator.alloc(Limb, calcSetStringLimbsBufferLen(base, value.len));
        defer self.allocator.free(limbs_buffer);
        var m = self.toMutable();
        try m.setString(base, value, limbs_buffer, self.allocator);
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
    pub fn toString(self: Managed, allocator: *Allocator, base: u8, case: std.fmt.Case) ![]u8 {
        _ = allocator;
        if (base < 2 or base > 16) return error.InvalidBase;
        return self.toConst().toStringAlloc(self.allocator, base, case);
    }

    /// To allow `std.fmt.format` to work with `Managed`.
    /// If the integer is larger than `pow(2, 64 * @sizeOf(usize) * 8), this function will fail
    /// to print the string, printing "(BigInt)" instead of a number.
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

    /// Returns math.Order.lt, math.Order.eq, math.Order.gt if a < b, a == b or a
    /// > b respectively.
    pub fn order(a: Managed, b: Managed) math.Order {
        return a.toConst().order(b.toConst());
    }

    /// Returns true if a == 0.
    pub fn eqZero(a: Managed) bool {
        return a.toConst().eqZero();
    }

    /// Returns true if |a| == |b|.
    pub fn eqAbs(a: Managed, b: Managed) bool {
        return a.toConst().eqAbs(b.toConst());
    }

    /// Returns true if a == b.
    pub fn eq(a: Managed, b: Managed) bool {
        return a.toConst().eq(b.toConst());
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
    /// r and a may be aliases. If r aliases a, then caller must call
    /// `r.ensureAddScalarCapacity` prior to calling `add`.
    /// scalar is a primitive integer type.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn addScalar(r: *Managed, a: Const, scalar: anytype) Allocator.Error!void {
        assert((r.limbs.ptr != a.limbs.ptr) or r.limbs.len >= math.max(a.limbs.len, calcLimbLen(scalar)) + 1);
        try r.ensureAddScalarCapacity(a, scalar);
        var m = r.toMutable();
        m.addScalar(a, scalar);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a + b
    ///
    /// r, a and b may be aliases. If r aliases a or b, then caller must call
    /// `r.ensureAddCapacity` prior to calling `add`.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn add(r: *Managed, a: Const, b: Const) Allocator.Error!void {
        assert((r.limbs.ptr != a.limbs.ptr and r.limbs.ptr != b.limbs.ptr) or r.limbs.len >= math.max(a.limbs.len, b.limbs.len) + 1);
        try r.ensureAddCapacity(a, b);
        var m = r.toMutable();
        m.add(a, b);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a + b with 2s-complement wrapping semantics.
    ///
    /// r, a and b may be aliases. If r aliases a or b, then caller must call
    /// `r.ensureTwosCompCapacity` prior to calling `add`.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn addWrap(r: *Managed, a: Const, b: Const, signedness: Signedness, bit_count: usize) Allocator.Error!void {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        m.addWrap(a, b, signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a + b with 2s-complement saturating semantics.
    ///
    /// r, a and b may be aliases. If r aliases a or b, then caller must call
    /// `r.ensureTwosCompCapacity` prior to calling `add`.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn addSat(r: *Managed, a: Const, b: Const, signedness: Signedness, bit_count: usize) Allocator.Error!void {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        m.addSat(a, b, signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a - b
    ///
    /// r, a and b may be aliases.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn sub(r: *Managed, a: Const, b: Const) !void {
        try r.ensureCapacity(math.max(a.limbs.len, b.limbs.len) + 1);
        var m = r.toMutable();
        m.sub(a, b);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a - b with 2s-complement wrapping semantics.
    ///
    /// r, a and b may be aliases. If r aliases a or b, then caller must call
    /// `r.ensureTwosCompCapacity` prior to calling `add`.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn subWrap(r: *Managed, a: Const, b: Const, signedness: Signedness, bit_count: usize) Allocator.Error!void {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        m.subWrap(a, b, signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a - b with 2s-complement saturating semantics.
    ///
    /// r, a and b may be aliases. If r aliases a or b, then caller must call
    /// `r.ensureTwosCompCapacity` prior to calling `add`.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn subSat(r: *Managed, a: Const, b: Const, signedness: Signedness, bit_count: usize) Allocator.Error!void {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        m.subSat(a, b, signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// rma = a * b
    ///
    /// rma, a and b may be aliases. However, it is more efficient if rma does not alias a or b.
    /// If rma aliases a or b, then caller must call `rma.ensureMulCapacity` prior to calling `mul`.
    ///
    /// Returns an error if memory could not be allocated.
    ///
    /// rma's allocator is used for temporary storage to speed up the multiplication.
    pub fn mul(rma: *Managed, a: Const, b: Const) !void {
        var alias_count: usize = 0;
        if (rma.limbs.ptr == a.limbs.ptr)
            alias_count += 1;
        if (rma.limbs.ptr == b.limbs.ptr)
            alias_count += 1;
        assert(alias_count == 0 or rma.limbs.len >= a.limbs.len + b.limbs.len + 1);
        try rma.ensureMulCapacity(a, b);
        var m = rma.toMutable();
        if (alias_count == 0) {
            m.mulNoAlias(a, b, rma.allocator);
        } else {
            const limb_count = calcMulLimbsBufferLen(a.limbs.len, b.limbs.len, alias_count);
            const limbs_buffer = try rma.allocator.alloc(Limb, limb_count);
            defer rma.allocator.free(limbs_buffer);
            m.mul(a, b, limbs_buffer, rma.allocator);
        }
        rma.setMetadata(m.positive, m.len);
    }

    /// rma = a * b with 2s-complement wrapping semantics.
    ///
    /// rma, a and b may be aliases. However, it is more efficient if rma does not alias a or b.
    /// If rma aliases a or b, then caller must call `ensureTwosCompCapacity`
    /// prior to calling `mul`.
    ///
    /// Returns an error if memory could not be allocated.
    ///
    /// rma's allocator is used for temporary storage to speed up the multiplication.
    pub fn mulWrap(rma: *Managed, a: Const, b: Const, signedness: Signedness, bit_count: usize) !void {
        var alias_count: usize = 0;
        if (rma.limbs.ptr == a.limbs.ptr)
            alias_count += 1;
        if (rma.limbs.ptr == b.limbs.ptr)
            alias_count += 1;

        try rma.ensureTwosCompCapacity(bit_count);
        var m = rma.toMutable();
        if (alias_count == 0) {
            m.mulWrapNoAlias(a, b, signedness, bit_count, rma.allocator);
        } else {
            const limb_count = calcMulWrapLimbsBufferLen(bit_count, a.limbs.len, b.limbs.len, alias_count);
            const limbs_buffer = try rma.allocator.alloc(Limb, limb_count);
            defer rma.allocator.free(limbs_buffer);
            m.mulWrap(a, b, signedness, bit_count, limbs_buffer, rma.allocator);
        }
        rma.setMetadata(m.positive, m.len);
    }

    pub fn ensureTwosCompCapacity(r: *Managed, bit_count: usize) !void {
        try r.ensureCapacity(calcTwosCompLimbCount(bit_count));
    }

    pub fn ensureAddScalarCapacity(r: *Managed, a: Const, scalar: anytype) !void {
        try r.ensureCapacity(math.max(a.limbs.len, calcLimbLen(scalar)) + 1);
    }

    pub fn ensureAddCapacity(r: *Managed, a: Const, b: Const) !void {
        try r.ensureCapacity(math.max(a.limbs.len, b.limbs.len) + 1);
    }

    pub fn ensureMulCapacity(rma: *Managed, a: Const, b: Const) !void {
        try rma.ensureCapacity(a.limbs.len + b.limbs.len + 1);
    }

    /// q = a / b (rem r)
    ///
    /// a / b are floored (rounded towards 0).
    ///
    /// Returns an error if memory could not be allocated.
    ///
    /// q's allocator is used for temporary storage to speed up the multiplication.
    pub fn divFloor(q: *Managed, r: *Managed, a: Const, b: Const) !void {
        try q.ensureCapacity(a.limbs.len + b.limbs.len + 1);
        try r.ensureCapacity(a.limbs.len);
        var mq = q.toMutable();
        var mr = r.toMutable();
        const limbs_buffer = try q.allocator.alloc(Limb, calcDivLimbsBufferLen(a.limbs.len, b.limbs.len));
        defer q.allocator.free(limbs_buffer);
        mq.divFloor(&mr, a, b, limbs_buffer, q.allocator);
        q.setMetadata(mq.positive, mq.len);
        r.setMetadata(mr.positive, mr.len);
    }

    /// q = a / b (rem r)
    ///
    /// a / b are truncated (rounded towards -inf).
    ///
    /// Returns an error if memory could not be allocated.
    ///
    /// q's allocator is used for temporary storage to speed up the multiplication.
    pub fn divTrunc(q: *Managed, r: *Managed, a: Const, b: Const) !void {
        try q.ensureCapacity(a.limbs.len + b.limbs.len + 1);
        try r.ensureCapacity(a.limbs.len);
        var mq = q.toMutable();
        var mr = r.toMutable();
        const limbs_buffer = try q.allocator.alloc(Limb, calcDivLimbsBufferLen(a.limbs.len, b.limbs.len));
        defer q.allocator.free(limbs_buffer);
        mq.divTrunc(&mr, a, b, limbs_buffer, q.allocator);
        q.setMetadata(mq.positive, mq.len);
        r.setMetadata(mr.positive, mr.len);
    }

    /// r = a << shift, in other words, r = a * 2^shift
    pub fn shiftLeft(r: *Managed, a: Managed, shift: usize) !void {
        try r.ensureCapacity(a.len() + (shift / limb_bits) + 1);
        var m = r.toMutable();
        m.shiftLeft(a.toConst(), shift);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a <<| shift with 2s-complement saturating semantics.
    pub fn shiftLeftSat(r: *Managed, a: Managed, shift: usize, signedness: Signedness, bit_count: usize) !void {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        m.shiftLeftSat(a.toConst(), shift, signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a >> shift
    pub fn shiftRight(r: *Managed, a: Managed, shift: usize) !void {
        if (a.len() <= shift / limb_bits) {
            r.metadata = 1;
            r.limbs[0] = 0;
            return;
        }

        try r.ensureCapacity(a.len() - (shift / limb_bits));
        var m = r.toMutable();
        m.shiftRight(a.toConst(), shift);
        r.setMetadata(m.positive, m.len);
    }

    /// r = ~a under 2s-complement wrapping semantics.
    pub fn bitNotWrap(r: *Managed, a: Managed, signedness: Signedness, bit_count: usize) !void {
        try r.ensureTwosCompCapacity(bit_count);
        var m = r.toMutable();
        m.bitNotWrap(a.toConst(), signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// r = a | b
    ///
    /// a and b are zero-extended to the longer of a or b.
    pub fn bitOr(r: *Managed, a: Managed, b: Managed) !void {
        try r.ensureCapacity(math.max(a.len(), b.len()));
        var m = r.toMutable();
        m.bitOr(a.toConst(), b.toConst());
        r.setMetadata(m.positive, m.len);
    }

    /// r = a & b
    pub fn bitAnd(r: *Managed, a: Managed, b: Managed) !void {
        const cap = if (a.isPositive() or b.isPositive())
            math.min(a.len(), b.len())
        else
            math.max(a.len(), b.len()) + 1;
        try r.ensureCapacity(cap);
        var m = r.toMutable();
        m.bitAnd(a.toConst(), b.toConst());
        r.setMetadata(m.positive, m.len);
    }

    /// r = a ^ b
    pub fn bitXor(r: *Managed, a: Managed, b: Managed) !void {
        var cap = math.max(a.len(), b.len()) + @boolToInt(a.isPositive() != b.isPositive());
        try r.ensureCapacity(cap);

        var m = r.toMutable();
        m.bitXor(a.toConst(), b.toConst());
        r.setMetadata(m.positive, m.len);
    }

    /// rma may alias x or y.
    /// x and y may alias each other.
    ///
    /// rma's allocator is used for temporary storage to boost multiplication performance.
    pub fn gcd(rma: *Managed, x: Managed, y: Managed) !void {
        try rma.ensureCapacity(math.min(x.len(), y.len()));
        var m = rma.toMutable();
        var limbs_buffer = std.ArrayList(Limb).init(rma.allocator);
        defer limbs_buffer.deinit();
        try m.gcd(x.toConst(), y.toConst(), &limbs_buffer);
        rma.setMetadata(m.positive, m.len);
    }

    /// r = a * a
    pub fn sqr(rma: *Managed, a: Const) !void {
        const needed_limbs = 2 * a.limbs.len + 1;

        if (rma.limbs.ptr == a.limbs.ptr) {
            var m = try Managed.initCapacity(rma.allocator, needed_limbs);
            errdefer m.deinit();
            var m_mut = m.toMutable();
            m_mut.sqrNoAlias(a, rma.allocator);
            m.setMetadata(m_mut.positive, m_mut.len);

            rma.deinit();
            rma.swap(&m);
        } else {
            try rma.ensureCapacity(needed_limbs);
            var rma_mut = rma.toMutable();
            rma_mut.sqrNoAlias(a, rma.allocator);
            rma.setMetadata(rma_mut.positive, rma_mut.len);
        }
    }

    pub fn pow(rma: *Managed, a: Const, b: u32) !void {
        const needed_limbs = calcPowLimbsBufferLen(a.bitCountAbs(), b);

        const limbs_buffer = try rma.allocator.alloc(Limb, needed_limbs);
        defer rma.allocator.free(limbs_buffer);

        if (rma.limbs.ptr == a.limbs.ptr) {
            var m = try Managed.initCapacity(rma.allocator, needed_limbs);
            errdefer m.deinit();
            var m_mut = m.toMutable();
            try m_mut.pow(a, b, limbs_buffer);
            m.setMetadata(m_mut.positive, m_mut.len);

            rma.deinit();
            rma.swap(&m);
        } else {
            try rma.ensureCapacity(needed_limbs);
            var rma_mut = rma.toMutable();
            try rma_mut.pow(a, b, limbs_buffer);
            rma.setMetadata(rma_mut.positive, rma_mut.len);
        }
    }

    /// r = truncate(Int(signedness, bit_count), a)
    pub fn truncate(r: *Managed, a: Const, signedness: Signedness, bit_count: usize) !void {
        try r.ensureCapacity(calcTwosCompLimbCount(bit_count));
        var m = r.toMutable();
        m.truncate(a, signedness, bit_count);
        r.setMetadata(m.positive, m.len);
    }

    /// r = saturate(Int(signedness, bit_count), a)
    pub fn saturate(r: *Managed, a: Const, signedness: Signedness, bit_count: usize) !void {
        try r.ensureCapacity(calcTwosCompLimbCount(bit_count));
        var m = r.toMutable();
        m.saturate(a, signedness, bit_count);
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
};

/// Knuth 4.3.1, Algorithm M.
///
/// r = r (op) a * b
/// r MUST NOT alias any of a or b.
///
/// The result is computed modulo `r.len`. When `r.len >= a.len + b.len`, no overflow occurs.
fn llmulacc(comptime op: AccOp, opt_allocator: ?*Allocator, r: []Limb, a: []const Limb, b: []const Limb) void {
    @setRuntimeSafety(debug_safety);
    assert(r.len >= a.len);
    assert(r.len >= b.len);

    // Order greatest first.
    var x = a;
    var y = b;
    if (a.len < b.len) {
        x = b;
        y = a;
    }

    k_mul: {
        if (y.len > 48) {
            if (opt_allocator) |allocator| {
                llmulaccKaratsuba(op, allocator, r, x, y) catch |err| switch (err) {
                    error.OutOfMemory => break :k_mul, // handled below
                };
                return;
            }
        }
    }

    llmulaccLong(op, r, x, y);
}

/// Knuth 4.3.1, Algorithm M.
///
/// r = r (op) a * b
/// r MUST NOT alias any of a or b.
///
/// The result is computed modulo `r.len`. When `r.len >= a.len + b.len`, no overflow occurs.
fn llmulaccKaratsuba(
    comptime op: AccOp,
    allocator: *Allocator,
    r: []Limb,
    a: []const Limb,
    b: []const Limb,
) error{OutOfMemory}!void {
    @setRuntimeSafety(debug_safety);
    assert(r.len >= a.len);
    assert(a.len >= b.len);

    // Classical karatsuba algorithm:
    // a = a1 * B + a0
    // b = b1 * B + b0
    // Where a0, b0 < B
    //
    // We then have:
    // ab = a * b
    //    = (a1 * B + a0) * (b1 * B + b0)
    //    = a1 * b1 * B * B + a1 * B * b0 + a0 * b1 * B + a0 * b0
    //    = a1 * b1 * B * B + (a1 * b0 + a0 * b1) * B + a0 * b0
    //
    // Note that:
    // a1 * b0 + a0 * b1
    //    = (a1 + a0)(b1 + b0) - a1 * b1 - a0 * b0
    //    = (a0 - a1)(b1 - b0) + a1 * b1 + a0 * b0
    //
    // This yields:
    // ab = p2 * B^2 + (p0 + p1 + p2) * B + p0
    //
    // Where:
    // p0 = a0 * b0
    // p1 = (a0 - a1)(b1 - b0)
    // p2 = a1 * b1
    //
    // Note, (a0 - a1) and (b1 - b0) produce values -B < x < B, and so we need to mind the sign here.
    // We also have:
    // 0 <= p0 <= 2B
    // -2B <= p1 <= 2B
    //
    // Note, when B is a multiple of the limb size, multiplies by B amount to shifts or
    // slices of a limbs array.
    //
    // This function computes the result of the multiplication modulo r.len. This means:
    // - p2 and p1 only need to be computed modulo r.len - B.
    // - In the case of p2, p2 * B^2 needs to be added modulo r.len - 2 * B.

    const split = b.len / 2; // B

    const limbs_after_split = r.len - split; // Limbs to compute for p1 and p2.
    const limbs_after_split2 = r.len - split * 2; // Limbs to add for p2 * B^2.

    // For a0 and b0 we need the full range.
    const a0 = a[0..llnormalize(a[0..split])];
    const b0 = b[0..llnormalize(b[0..split])];

    // For a1 and b1 we only need `limbs_after_split` limbs.
    const a1 = blk: {
        var a1 = a[split..];
        a1.len = math.min(llnormalize(a1), limbs_after_split);
        break :blk a1;
    };

    const b1 = blk: {
        var b1 = b[split..];
        b1.len = math.min(llnormalize(b1), limbs_after_split);
        break :blk b1;
    };

    // Note that the above slices relative to `split` work because we have a.len > b.len.

    // We need some temporary memory to store intermediate results.
    // Note, we can reduce the amount of temporaries we need by reordering the computation here:
    // ab = p2 * B^2 + (p0 + p1 + p2) * B + p0
    //    = p2 * B^2 + (p0 * B + p1 * B + p2 * B) + p0
    //    = (p2 * B^2 + p2 * B) + (p0 * B + p0) + p1 * B

    // Allocate at least enough memory to be able to multiply the upper two segments of a and b, assuming
    // no overflow.
    const tmp = try allocator.alloc(Limb, a.len - split + b.len - split);
    defer allocator.free(tmp);

    // Compute p2.
    // Note, we don't need to compute all of p2, just enough limbs to satisfy r.
    const p2_limbs = math.min(limbs_after_split, a1.len + b1.len);

    mem.set(Limb, tmp[0..p2_limbs], 0);
    llmulacc(.add, allocator, tmp[0..p2_limbs], a1[0..math.min(a1.len, p2_limbs)], b1[0..math.min(b1.len, p2_limbs)]);
    const p2 = tmp[0..llnormalize(tmp[0..p2_limbs])];

    // Add p2 * B to the result.
    llaccum(op, r[split..], p2);

    // Add p2 * B^2 to the result if required.
    if (limbs_after_split2 > 0) {
        llaccum(op, r[split * 2 ..], p2[0..math.min(p2.len, limbs_after_split2)]);
    }

    // Compute p0.
    // Since a0.len, b0.len <= split and r.len >= split * 2, the full width of p0 needs to be computed.
    const p0_limbs = a0.len + b0.len;
    mem.set(Limb, tmp[0..p0_limbs], 0);
    llmulacc(.add, allocator, tmp[0..p0_limbs], a0, b0);
    const p0 = tmp[0..llnormalize(tmp[0..p0_limbs])];

    // Add p0 to the result.
    llaccum(op, r, p0);

    // Add p0 * B to the result. In this case, we may not need all of it.
    llaccum(op, r[split..], p0[0..math.min(limbs_after_split, p0.len)]);

    // Finally, compute and add p1.
    // From now on we only need `limbs_after_split` limbs for a0 and b0, since the result of the
    // following computation will be added * B.
    const a0x = a0[0..std.math.min(a0.len, limbs_after_split)];
    const b0x = b0[0..std.math.min(b0.len, limbs_after_split)];

    const j0_sign = llcmp(a0x, a1);
    const j1_sign = llcmp(b1, b0x);

    if (j0_sign * j1_sign == 0) {
        // p1 is zero, we don't need to do any computation at all.
        return;
    }

    mem.set(Limb, tmp, 0);

    // p1 is nonzero, so compute the intermediary terms j0 = a0 - a1 and j1 = b1 - b0.
    // Note that in this case, we again need some storage for intermediary results
    // j0 and j1. Since we have tmp.len >= 2B, we can store both
    // intermediaries in the already allocated array.
    const j0 = tmp[0 .. a.len - split];
    const j1 = tmp[a.len - split ..];

    // Ensure that no subtraction overflows.
    if (j0_sign == 1) {
        // a0 > a1.
        _ = llsubcarry(j0, a0x, a1);
    } else {
        // a0 < a1.
        _ = llsubcarry(j0, a1, a0x);
    }

    if (j1_sign == 1) {
        // b1 > b0.
        _ = llsubcarry(j1, b1, b0x);
    } else {
        // b1 > b0.
        _ = llsubcarry(j1, b0x, b1);
    }

    if (j0_sign * j1_sign == 1) {
        // If j0 and j1 are both positive, we now have:
        // p1 = j0 * j1
        // If j0 and j1 are both negative, we now have:
        // p1 = -j0 * -j1 = j0 * j1
        // In this case we can add p1 to the result using llmulacc.
        llmulacc(op, allocator, r[split..], j0[0..llnormalize(j0)], j1[0..llnormalize(j1)]);
    } else {
        // In this case either j0 or j1 is negative, an we have:
        // p1 = -(j0 * j1)
        // Now we need to subtract instead of accumulate.
        const inverted_op = if (op == .add) .sub else .add;
        llmulacc(inverted_op, allocator, r[split..], j0[0..llnormalize(j0)], j1[0..llnormalize(j1)]);
    }
}

/// r = r (op) a.
/// The result is computed modulo `r.len`.
fn llaccum(comptime op: AccOp, r: []Limb, a: []const Limb) void {
    @setRuntimeSafety(debug_safety);
    if (op == .sub) {
        _ = llsubcarry(r, r, a);
        return;
    }

    assert(r.len != 0 and a.len != 0);
    assert(r.len >= a.len);

    var i: usize = 0;
    var carry: Limb = 0;

    while (i < a.len) : (i += 1) {
        var c: Limb = 0;
        c += @boolToInt(@addWithOverflow(Limb, r[i], a[i], &r[i]));
        c += @boolToInt(@addWithOverflow(Limb, r[i], carry, &r[i]));
        carry = c;
    }

    while ((carry != 0) and i < r.len) : (i += 1) {
        carry = @boolToInt(@addWithOverflow(Limb, r[i], carry, &r[i]));
    }
}

/// Returns -1, 0, 1 if |a| < |b|, |a| == |b| or |a| > |b| respectively for limbs.
pub fn llcmp(a: []const Limb, b: []const Limb) i8 {
    @setRuntimeSafety(debug_safety);
    const a_len = llnormalize(a);
    const b_len = llnormalize(b);
    if (a_len < b_len) {
        return -1;
    }
    if (a_len > b_len) {
        return 1;
    }

    var i: usize = a_len - 1;
    while (i != 0) : (i -= 1) {
        if (a[i] != b[i]) {
            break;
        }
    }

    if (a[i] < b[i]) {
        return -1;
    } else if (a[i] > b[i]) {
        return 1;
    } else {
        return 0;
    }
}

/// r = r (op) y * xi
/// The result is computed modulo `r.len`. When `r.len >= a.len + b.len`, no overflow occurs.
fn llmulaccLong(comptime op: AccOp, r: []Limb, a: []const Limb, b: []const Limb) void {
    @setRuntimeSafety(debug_safety);
    assert(r.len >= a.len);
    assert(a.len >= b.len);

    var i: usize = 0;
    while (i < b.len) : (i += 1) {
        llmulLimb(op, r[i..], a, b[i]);
    }
}

/// r = r (op) y * xi
/// The result is computed modulo `r.len`.
fn llmulLimb(comptime op: AccOp, acc: []Limb, y: []const Limb, xi: Limb) void {
    @setRuntimeSafety(debug_safety);
    if (xi == 0) {
        return;
    }

    var a_lo = acc[0..y.len];
    var a_hi = acc[y.len..];

    switch (op) {
        .add => {
            var carry: Limb = 0;
            var j: usize = 0;
            while (j < a_lo.len) : (j += 1) {
                a_lo[j] = addMulLimbWithCarry(a_lo[j], y[j], xi, &carry);
            }

            j = 0;
            while ((carry != 0) and (j < a_hi.len)) : (j += 1) {
                carry = @boolToInt(@addWithOverflow(Limb, a_hi[j], carry, &a_hi[j]));
            }
        },
        .sub => {
            var borrow: Limb = 0;
            var j: usize = 0;
            while (j < a_lo.len) : (j += 1) {
                a_lo[j] = subMulLimbWithBorrow(a_lo[j], y[j], xi, &borrow);
            }

            j = 0;
            while ((borrow != 0) and (j < a_hi.len)) : (j += 1) {
                borrow = @boolToInt(@subWithOverflow(Limb, a_hi[j], borrow, &a_hi[j]));
            }
        },
    }
}

/// returns the min length the limb could be.
fn llnormalize(a: []const Limb) usize {
    @setRuntimeSafety(debug_safety);
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
    @setRuntimeSafety(debug_safety);
    assert(a.len != 0 and b.len != 0);
    assert(a.len >= b.len);
    assert(r.len >= a.len);

    var i: usize = 0;
    var borrow: Limb = 0;

    while (i < b.len) : (i += 1) {
        var c: Limb = 0;
        c += @boolToInt(@subWithOverflow(Limb, a[i], b[i], &r[i]));
        c += @boolToInt(@subWithOverflow(Limb, r[i], borrow, &r[i]));
        borrow = c;
    }

    while (i < a.len) : (i += 1) {
        borrow = @boolToInt(@subWithOverflow(Limb, a[i], borrow, &r[i]));
    }

    return borrow;
}

fn llsub(r: []Limb, a: []const Limb, b: []const Limb) void {
    @setRuntimeSafety(debug_safety);
    assert(a.len > b.len or (a.len == b.len and a[a.len - 1] >= b[b.len - 1]));
    assert(llsubcarry(r, a, b) == 0);
}

/// Knuth 4.3.1, Algorithm A.
fn lladdcarry(r: []Limb, a: []const Limb, b: []const Limb) Limb {
    @setRuntimeSafety(debug_safety);
    assert(a.len != 0 and b.len != 0);
    assert(a.len >= b.len);
    assert(r.len >= a.len);

    var i: usize = 0;
    var carry: Limb = 0;

    while (i < b.len) : (i += 1) {
        var c: Limb = 0;
        c += @boolToInt(@addWithOverflow(Limb, a[i], b[i], &r[i]));
        c += @boolToInt(@addWithOverflow(Limb, r[i], carry, &r[i]));
        carry = c;
    }

    while (i < a.len) : (i += 1) {
        carry = @boolToInt(@addWithOverflow(Limb, a[i], carry, &r[i]));
    }

    return carry;
}

fn lladd(r: []Limb, a: []const Limb, b: []const Limb) void {
    @setRuntimeSafety(debug_safety);
    assert(r.len >= a.len + 1);
    r[a.len] = lladdcarry(r, a, b);
}

/// Knuth 4.3.1, Exercise 16.
fn lldiv1(quo: []Limb, rem: *Limb, a: []const Limb, b: Limb) void {
    @setRuntimeSafety(debug_safety);
    assert(a.len > 1 or a[0] >= b);
    assert(quo.len >= a.len);

    rem.* = 0;
    for (a) |_, ri| {
        const i = a.len - ri - 1;
        const pdiv = ((@as(DoubleLimb, rem.*) << limb_bits) | a[i]);

        if (pdiv == 0) {
            quo[i] = 0;
            rem.* = 0;
        } else if (pdiv < b) {
            quo[i] = 0;
            rem.* = @truncate(Limb, pdiv);
        } else if (pdiv == b) {
            quo[i] = 1;
            rem.* = 0;
        } else {
            quo[i] = @truncate(Limb, @divTrunc(pdiv, b));
            rem.* = @truncate(Limb, pdiv - (quo[i] *% b));
        }
    }
}

fn llshl(r: []Limb, a: []const Limb, shift: usize) void {
    @setRuntimeSafety(debug_safety);
    assert(a.len >= 1);

    const interior_limb_shift = @truncate(Log2Limb, shift);

    // We only need the extra limb if the shift of the last element overflows.
    // This is useful for the implementation of `shiftLeftSat`.
    if (a[a.len - 1] << interior_limb_shift >> interior_limb_shift != a[a.len - 1]) {
        assert(r.len >= a.len + (shift / limb_bits) + 1);
    } else {
        assert(r.len >= a.len + (shift / limb_bits));
    }

    const limb_shift = shift / limb_bits + 1;

    var carry: Limb = 0;
    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        const src_i = a.len - i - 1;
        const dst_i = src_i + limb_shift;

        const src_digit = a[src_i];
        r[dst_i] = carry | @call(.{ .modifier = .always_inline }, math.shr, .{
            Limb,
            src_digit,
            limb_bits - @intCast(Limb, interior_limb_shift),
        });
        carry = (src_digit << interior_limb_shift);
    }

    r[limb_shift - 1] = carry;
    mem.set(Limb, r[0 .. limb_shift - 1], 0);
}

fn llshr(r: []Limb, a: []const Limb, shift: usize) void {
    @setRuntimeSafety(debug_safety);
    assert(a.len >= 1);
    assert(r.len >= a.len - (shift / limb_bits));

    const limb_shift = shift / limb_bits;
    const interior_limb_shift = @truncate(Log2Limb, shift);

    var carry: Limb = 0;
    var i: usize = 0;
    while (i < a.len - limb_shift) : (i += 1) {
        const src_i = a.len - i - 1;
        const dst_i = src_i - limb_shift;

        const src_digit = a[src_i];
        r[dst_i] = carry | (src_digit >> interior_limb_shift);
        carry = @call(.{ .modifier = .always_inline }, math.shl, .{
            Limb,
            src_digit,
            limb_bits - @intCast(Limb, interior_limb_shift),
        });
    }
}

// r = ~r
fn llnot(r: []Limb) void {
    @setRuntimeSafety(debug_safety);

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
    @setRuntimeSafety(debug_safety);
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
            var a_limb: Limb = undefined;
            a_borrow = @boolToInt(@subWithOverflow(Limb, a[i], a_borrow, &a_limb));

            r[i] = a_limb & ~b[i];
            r_carry = @boolToInt(@addWithOverflow(Limb, r[i], r_carry, &r[i]));
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
            a_borrow = @boolToInt(@subWithOverflow(Limb, a[i], a_borrow, &r[i]));
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
            var b_limb: Limb = undefined;
            b_borrow = @boolToInt(@subWithOverflow(Limb, b[i], b_borrow, &b_limb));

            r[i] = ~a[i] & b_limb;
            r_carry = @boolToInt(@addWithOverflow(Limb, r[i], r_carry, &r[i]));
        }

        // b is at least 1, so this should never underflow.
        assert(b_borrow == 0); // b was 0

        // x & ~a can only clear bits, so (x & ~a) <= x, meaning (-b - 1) + 1 never overflows.
        assert(r_carry == 0);

        // With b = 0 and b_borrow = 0, we get ~a & (-0 - 0) = ~a & 0 = 0.
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
            var a_limb: Limb = undefined;
            a_borrow = @boolToInt(@subWithOverflow(Limb, a[i], a_borrow, &a_limb));

            var b_limb: Limb = undefined;
            b_borrow = @boolToInt(@subWithOverflow(Limb, b[i], b_borrow, &b_limb));

            r[i] = a_limb & b_limb;
            r_carry = @boolToInt(@addWithOverflow(Limb, r[i], r_carry, &r[i]));
        }

        // b is at least 1, so this should never underflow.
        assert(b_borrow == 0); // b was 0

        // Can never overflow because in order for b_limb to be maxInt(Limb),
        // b_borrow would need to equal 1.

        // x & y can only clear bits, meaning x & y <= x and x & y <= y. This implies that
        // for x = a - 1 and y = b - 1, the +1 term would never cause an overflow.
        assert(r_carry == 0);

        // With b = 0 and b_borrow = 0 we get (-a - 1) & (-0 - 0) = (-a - 1) & 0 = 0.
        // Omit setting the upper bytes, just deal with those when calling llsignedor.
        return false;
    }
}

// r = a & b with 2s complement semantics.
// r may alias.
// a and b must not be 0.
// Returns `true` when the result is positive.
// When either or both of a and b are positive, r requires at least `b.len` limbs of storage.
// When both a and b are negative, r requires at least `a.limbs.len + 1` limbs of storage.
fn llsignedand(r: []Limb, a: []const Limb, a_positive: bool, b: []const Limb, b_positive: bool) bool {
    @setRuntimeSafety(debug_safety);
    assert(a.len != 0 and b.len != 0);
    assert(r.len >= a.len);
    assert(a.len >= b.len);

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
            var a_limb: Limb = undefined;
            a_borrow = @boolToInt(@subWithOverflow(Limb, a[i], a_borrow, &a_limb));
            r[i] = ~a_limb & b[i];
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
            var a_limb: Limb = undefined;
            b_borrow = @boolToInt(@subWithOverflow(Limb, b[i], b_borrow, &a_limb));
            r[i] = a[i] & ~a_limb;
        }

        assert(b_borrow == 0); // b was 0

        // With b = 0 and b_borrow = 0 we have a & ~(-0 - 0) = a & 0 = 0, so
        // the upper bytes are zero.  Omit setting them here and simply discard
        // them whenever llsignedand is called.

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
            var a_limb: Limb = undefined;
            a_borrow = @boolToInt(@subWithOverflow(Limb, a[i], a_borrow, &a_limb));

            var b_limb: Limb = undefined;
            b_borrow = @boolToInt(@subWithOverflow(Limb, b[i], b_borrow, &b_limb));

            r[i] = a_limb | b_limb;
            r_carry = @boolToInt(@addWithOverflow(Limb, r[i], r_carry, &r[i]));
        }

        // b is at least 1, so this should never underflow.
        assert(b_borrow == 0); // b was 0

        // With b = 0 and b_borrow = 0 we get (-a - 1) | (-0 - 0) = (-a - 1) | 0 = -a - 1.
        while (i < a.len) : (i += 1) {
            a_borrow = @boolToInt(@subWithOverflow(Limb, a[i], a_borrow, &r[i]));
            r_carry = @boolToInt(@addWithOverflow(Limb, r[i], r_carry, &r[i]));
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
// If the sign of a and b is equal, then r requires at least `max(a.len, b.len)` limbs are required.
// Otherwise, r requires at least `max(a.len, b.len) + 1` limbs.
fn llsignedxor(r: []Limb, a: []const Limb, a_positive: bool, b: []const Limb, b_positive: bool) bool {
    @setRuntimeSafety(debug_safety);
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
    var a_borrow = @boolToInt(!a_positive);
    var b_borrow = @boolToInt(!b_positive);
    var r_carry = @boolToInt(a_positive != b_positive);

    while (i < b.len) : (i += 1) {
        var a_limb: Limb = undefined;
        a_borrow = @boolToInt(@subWithOverflow(Limb, a[i], a_borrow, &a_limb));

        var b_limb: Limb = undefined;
        b_borrow = @boolToInt(@subWithOverflow(Limb, b[i], b_borrow, &b_limb));

        r[i] = a_limb ^ b_limb;
        r_carry = @boolToInt(@addWithOverflow(Limb, r[i], r_carry, &r[i]));
    }

    while (i < a.len) : (i += 1) {
        a_borrow = @boolToInt(@subWithOverflow(Limb, a[i], a_borrow, &r[i]));
        r_carry = @boolToInt(@addWithOverflow(Limb, r[i], r_carry, &r[i]));
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
    @setRuntimeSafety(debug_safety);

    const x_norm = x;
    assert(r.len >= 2 * x_norm.len + 1);

    // Compute the square of a N-limb bigint with only (N^2 + N)/2
    // multiplications by exploting the symmetry of the coefficients around the
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

    for (x_norm) |v, i| {
        // Accumulate all the x[i]*x[j] (with x!=j) products
        llmulLimb(.add, r[2 * i + 1 ..], x_norm[i + 1 ..], v);
    }

    // Each product appears twice, multiply by 2
    llshl(r, r[0 .. 2 * x_norm.len], 1);

    for (x_norm) |v, i| {
        // Compute and add the squares
        llmulLimb(.add, r[2 * i ..], x[i .. i + 1], v);
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
    const b_leading_zeros = @clz(u32, b);
    const exp_zeros = @popCount(u32, ~b) - b_leading_zeros;
    if (exp_zeros & 1 != 0) {
        tmp1 = tmp_limbs;
        tmp2 = r;
    } else {
        tmp1 = r;
        tmp2 = tmp_limbs;
    }

    mem.copy(Limb, tmp1, a);
    mem.set(Limb, tmp1[a.len..], 0);

    // Scan the exponent as a binary number, from left to right, dropping the
    // most significant bit set.
    // Square the result if the current bit is zero, square and multiply by a if
    // it is one.
    var exp_bits = 32 - 1 - b_leading_zeros;
    var exp = b << @intCast(u5, 1 + b_leading_zeros);

    var i: usize = 0;
    while (i < exp_bits) : (i += 1) {
        // Square
        mem.set(Limb, tmp2, 0);
        llsquareBasecase(tmp2, tmp1[0..llnormalize(tmp1)]);
        mem.swap([]Limb, &tmp1, &tmp2);
        // Multiply by a
        if (@shlWithOverflow(u32, exp, 1, &exp)) {
            mem.set(Limb, tmp2, 0);
            llmulacc(.add, null, tmp2, tmp1[0..llnormalize(tmp1)], a);
            mem.swap([]Limb, &tmp1, &tmp2);
        }
    }
}

// Storage must live for the lifetime of the returned value
fn fixedIntFromSignedDoubleLimb(A: SignedDoubleLimb, storage: []Limb) Mutable {
    assert(storage.len >= 2);

    const A_is_positive = A >= 0;
    const Au = @intCast(DoubleLimb, if (A < 0) -A else A);
    storage[0] = @truncate(Limb, Au);
    storage[1] = @truncate(Limb, Au >> limb_bits);
    return .{
        .limbs = storage[0..2],
        .positive = A_is_positive,
        .len = 2,
    };
}

test {
    _ = @import("int_test.zig");
}
