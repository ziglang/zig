const std = @import("../../std.zig");
const debug = std.debug;
const testing = std.testing;
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const maxInt = std.math.maxInt;
const minInt = std.math.minInt;

pub const Limb = usize;
pub const DoubleLimb = std.meta.IntType(false, 2 * Limb.bit_count);
pub const Log2Limb = math.Log2Int(Limb);

comptime {
    debug.assert(math.floorPowerOfTwo(usize, Limb.bit_count) == Limb.bit_count);
    debug.assert(Limb.bit_count <= 64); // u128 set is unsupported
    debug.assert(Limb.is_signed == false);
}

/// An arbitrary-precision big integer.
///
/// Memory is allocated by an Int as needed to ensure operations never overflow. The range of an
/// Int is bounded only by available memory.
pub const Int = struct {
    const sign_bit: usize = 1 << (usize.bit_count - 1);

    /// Default number of limbs to allocate on creation of an Int.
    pub const default_capacity = 4;

    /// Allocator used by the Int when requesting memory.
    allocator: ?*Allocator,

    /// Raw digits. These are:
    ///
    /// * Little-endian ordered
    /// * limbs.len >= 1
    /// * Zero is represent as Int.len() == 1 with limbs[0] == 0.
    ///
    /// Accessing limbs directly should be avoided.
    limbs: []Limb,

    /// High bit is the sign bit. If set, Int is negative, else Int is positive.
    /// The remaining bits represent the number of limbs used by Int.
    metadata: usize,

    /// Creates a new Int. default_capacity limbs will be allocated immediately.
    /// Int will be zeroed.
    pub fn init(allocator: *Allocator) !Int {
        return try Int.initCapacity(allocator, default_capacity);
    }

    /// Creates a new Int. Int will be set to `value`.
    ///
    /// This is identical to an `init`, followed by a `set`.
    pub fn initSet(allocator: *Allocator, value: var) !Int {
        var s = try Int.init(allocator);
        try s.set(value);
        return s;
    }

    /// Creates a new Int with a specific capacity. If capacity < default_capacity then the
    /// default capacity will be used instead.
    pub fn initCapacity(allocator: *Allocator, capacity: usize) !Int {
        return Int{
            .allocator = allocator,
            .metadata = 1,
            .limbs = block: {
                var limbs = try allocator.alloc(Limb, math.max(default_capacity, capacity));
                limbs[0] = 0;
                break :block limbs;
            },
        };
    }

    /// Returns the number of limbs currently in use.
    pub fn len(self: Int) usize {
        return self.metadata & ~sign_bit;
    }

    /// Returns whether an Int is positive.
    pub fn isPositive(self: Int) bool {
        return self.metadata & sign_bit == 0;
    }

    /// Sets the sign of an Int.
    pub fn setSign(self: *Int, positive: bool) void {
        if (positive) {
            self.metadata &= ~sign_bit;
        } else {
            self.metadata |= sign_bit;
        }
    }

    /// Sets the length of an Int.
    ///
    /// If setLen is used, then the Int must be normalized to suit.
    pub fn setLen(self: *Int, new_len: usize) void {
        self.metadata &= sign_bit;
        self.metadata |= new_len;
    }

    /// Returns an Int backed by a fixed set of limb values.
    /// This is read-only and cannot be used as a result argument. If the Int tries to allocate
    /// memory a runtime panic will occur.
    pub fn initFixed(limbs: []const Limb) Int {
        var self = Int{
            .allocator = null,
            .metadata = limbs.len,
            // Cast away the const, invalid use to pass as a pointer argument.
            .limbs = @intToPtr([*]Limb, @ptrToInt(limbs.ptr))[0..limbs.len],
        };

        self.normalize(limbs.len);
        return self;
    }

    /// Ensures an Int has enough space allocated for capacity limbs. If the Int does not have
    /// sufficient capacity, the exact amount will be allocated. This occurs even if the requested
    /// capacity is only greater than the current capacity by one limb.
    pub fn ensureCapacity(self: *Int, capacity: usize) !void {
        self.assertWritable();
        if (capacity <= self.limbs.len) {
            return;
        }

        self.limbs = try self.allocator.?.realloc(self.limbs, capacity);
    }

    fn assertWritable(self: Int) void {
        if (self.allocator == null) {
            @panic("provided Int value is read-only but must be writable");
        }
    }

    /// Frees all memory associated with an Int.
    pub fn deinit(self: Int) void {
        self.assertWritable();
        self.allocator.?.free(self.limbs);
    }

    /// Clones an Int and returns a new Int with the same value. The new Int is a deep copy and
    /// can be modified separately from the original.
    pub fn clone(other: Int) !Int {
        other.assertWritable();
        return Int{
            .allocator = other.allocator,
            .metadata = other.metadata,
            .limbs = block: {
                var limbs = try other.allocator.?.alloc(Limb, other.len());
                mem.copy(Limb, limbs[0..], other.limbs[0..other.len()]);
                break :block limbs;
            },
        };
    }

    /// Copies the value of an Int to an existing Int so that they both have the same value.
    /// Extra memory will be allocated if the receiver does not have enough capacity.
    pub fn copy(self: *Int, other: Int) !void {
        self.assertWritable();
        if (self.limbs.ptr == other.limbs.ptr) {
            return;
        }

        try self.ensureCapacity(other.len());
        mem.copy(Limb, self.limbs[0..], other.limbs[0..other.len()]);
        self.metadata = other.metadata;
    }

    /// Efficiently swap an Int with another. This swaps the limb pointers and a full copy is not
    /// performed. The address of the limbs field will not be the same after this function.
    pub fn swap(self: *Int, other: *Int) void {
        self.assertWritable();
        mem.swap(Int, self, other);
    }

    pub fn dump(self: Int) void {
        for (self.limbs) |limb| {
            debug.warn("{x} ", .{limb});
        }
        debug.warn("\n", .{});
    }

    /// Negate the sign of an Int.
    pub fn negate(self: *Int) void {
        self.metadata ^= sign_bit;
    }

    /// Make an Int positive.
    pub fn abs(self: *Int) void {
        self.metadata &= ~sign_bit;
    }

    /// Returns true if an Int is odd.
    pub fn isOdd(self: Int) bool {
        return self.limbs[0] & 1 != 0;
    }

    /// Returns true if an Int is even.
    pub fn isEven(self: Int) bool {
        return !self.isOdd();
    }

    /// Returns the number of bits required to represent the absolute value an Int.
    fn bitCountAbs(self: Int) usize {
        return (self.len() - 1) * Limb.bit_count + (Limb.bit_count - @clz(Limb, self.limbs[self.len() - 1]));
    }

    /// Returns the number of bits required to represent the integer in twos-complement form.
    ///
    /// If the integer is negative the value returned is the number of bits needed by a signed
    /// integer to represent the value. If positive the value is the number of bits for an
    /// unsigned integer. Any unsigned integer will fit in the signed integer with bitcount
    /// one greater than the returned value.
    ///
    /// e.g. -127 returns 8 as it will fit in an i8. 127 returns 7 since it fits in a u7.
    fn bitCountTwosComp(self: Int) usize {
        var bits = self.bitCountAbs();

        // If the entire value has only one bit set (e.g. 0b100000000) then the negation in twos
        // complement requires one less bit.
        if (!self.isPositive()) block: {
            bits += 1;

            if (@popCount(Limb, self.limbs[self.len() - 1]) == 1) {
                for (self.limbs[0 .. self.len() - 1]) |limb| {
                    if (@popCount(Limb, limb) != 0) {
                        break :block;
                    }
                }

                bits -= 1;
            }
        }

        return bits;
    }

    fn fitsInTwosComp(self: Int, is_signed: bool, bit_count: usize) bool {
        if (self.eqZero()) {
            return true;
        }
        if (!is_signed and !self.isPositive()) {
            return false;
        }

        const req_bits = self.bitCountTwosComp() + @boolToInt(self.isPositive() and is_signed);
        return bit_count >= req_bits;
    }

    /// Returns whether self can fit into an integer of the requested type.
    pub fn fits(self: Int, comptime T: type) bool {
        return self.fitsInTwosComp(T.is_signed, T.bit_count);
    }

    /// Returns the approximate size of the integer in the given base. Negative values accommodate for
    /// the minus sign. This is used for determining the number of characters needed to print the
    /// value. It is inexact and may exceed the given value by ~1-2 bytes.
    pub fn sizeInBase(self: Int, base: usize) usize {
        const bit_count = @as(usize, @boolToInt(!self.isPositive())) + self.bitCountAbs();
        return (bit_count / math.log2(base)) + 1;
    }

    /// Sets an Int to value. Value must be an primitive integer type.
    pub fn set(self: *Int, value: var) Allocator.Error!void {
        self.assertWritable();
        const T = @TypeOf(value);

        switch (@typeInfo(T)) {
            .Int => |info| {
                const UT = if (T.is_signed) std.meta.IntType(false, T.bit_count - 1) else T;

                try self.ensureCapacity(@sizeOf(UT) / @sizeOf(Limb));
                self.metadata = 0;
                self.setSign(value >= 0);

                var w_value: UT = if (value < 0) @intCast(UT, -value) else @intCast(UT, value);

                if (info.bits <= Limb.bit_count) {
                    self.limbs[0] = @as(Limb, w_value);
                    self.metadata += 1;
                } else {
                    var i: usize = 0;
                    while (w_value != 0) : (i += 1) {
                        self.limbs[i] = @truncate(Limb, w_value);
                        self.metadata += 1;

                        // TODO: shift == 64 at compile-time fails. Fails on u128 limbs.
                        w_value >>= Limb.bit_count / 2;
                        w_value >>= Limb.bit_count / 2;
                    }
                }
            },
            .ComptimeInt => {
                comptime var w_value = if (value < 0) -value else value;

                const req_limbs = @divFloor(math.log2(w_value), Limb.bit_count) + 1;
                try self.ensureCapacity(req_limbs);

                self.metadata = req_limbs;
                self.setSign(value >= 0);

                if (w_value <= maxInt(Limb)) {
                    self.limbs[0] = w_value;
                } else {
                    const mask = (1 << Limb.bit_count) - 1;

                    comptime var i = 0;
                    inline while (w_value != 0) : (i += 1) {
                        self.limbs[i] = w_value & mask;

                        w_value >>= Limb.bit_count / 2;
                        w_value >>= Limb.bit_count / 2;
                    }
                }
            },
            else => {
                @compileError("cannot set Int using type " ++ @typeName(T));
            },
        }
    }

    pub const ConvertError = error{
        NegativeIntoUnsigned,
        TargetTooSmall,
    };

    /// Convert self to type T.
    ///
    /// Returns an error if self cannot be narrowed into the requested type without truncation.
    pub fn to(self: Int, comptime T: type) ConvertError!T {
        switch (@typeInfo(T)) {
            .Int => {
                const UT = std.meta.IntType(false, T.bit_count);

                if (self.bitCountTwosComp() > T.bit_count) {
                    return error.TargetTooSmall;
                }

                var r: UT = 0;

                if (@sizeOf(UT) <= @sizeOf(Limb)) {
                    r = @intCast(UT, self.limbs[0]);
                } else {
                    for (self.limbs[0..self.len()]) |_, ri| {
                        const limb = self.limbs[self.len() - ri - 1];
                        r <<= Limb.bit_count;
                        r |= limb;
                    }
                }

                if (!T.is_signed) {
                    return if (self.isPositive()) @intCast(T, r) else error.NegativeIntoUnsigned;
                } else {
                    if (self.isPositive()) {
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
            else => {
                @compileError("cannot convert Int to type " ++ @typeName(T));
            },
        }
    }

    fn charToDigit(ch: u8, base: u8) !u8 {
        const d = switch (ch) {
            '0'...'9' => ch - '0',
            'a'...'f' => (ch - 'a') + 0xa,
            else => return error.InvalidCharForDigit,
        };

        return if (d < base) d else return error.DigitTooLargeForBase;
    }

    fn digitToChar(d: u8, base: u8) !u8 {
        if (d >= base) {
            return error.DigitTooLargeForBase;
        }

        return switch (d) {
            0...9 => '0' + d,
            0xa...0xf => ('a' - 0xa) + d,
            else => unreachable,
        };
    }

    /// Set self from the string representation `value`.
    ///
    /// value must contain only digits <= `base`. Base prefixes are not allowed (e.g. 0x43 should
    /// simply be 43).
    ///
    /// Returns an error if memory could not be allocated or `value` has invalid digits for the
    /// requested base.
    pub fn setString(self: *Int, base: u8, value: []const u8) !void {
        self.assertWritable();
        if (base < 2 or base > 16) {
            return error.InvalidBase;
        }

        var i: usize = 0;
        var positive = true;
        if (value.len > 0 and value[0] == '-') {
            positive = false;
            i += 1;
        }

        const ap_base = Int.initFixed(([_]Limb{base})[0..]);
        try self.set(0);

        for (value[i..]) |ch| {
            const d = try charToDigit(ch, base);

            const ap_d = Int.initFixed(([_]Limb{d})[0..]);

            try self.mul(self.*, ap_base);
            try self.add(self.*, ap_d);
        }
        self.setSign(positive);
    }

    /// Converts self to a string in the requested base. Memory is allocated from the provided
    /// allocator and not the one present in self.
    /// TODO make this call format instead of the other way around
    pub fn toString(self: Int, allocator: *Allocator, base: u8) ![]const u8 {
        if (base < 2 or base > 16) {
            return error.InvalidBase;
        }

        var digits = ArrayList(u8).init(allocator);
        try digits.ensureCapacity(self.sizeInBase(base) + 1);
        defer digits.deinit();

        if (self.eqZero()) {
            try digits.append('0');
            return digits.toOwnedSlice();
        }

        // Power of two: can do a single pass and use masks to extract digits.
        if (math.isPowerOfTwo(base)) {
            const base_shift = math.log2_int(Limb, base);

            for (self.limbs[0..self.len()]) |limb| {
                var shift: usize = 0;
                while (shift < Limb.bit_count) : (shift += base_shift) {
                    const r = @intCast(u8, (limb >> @intCast(Log2Limb, shift)) & @as(Limb, base - 1));
                    const ch = try digitToChar(r, base);
                    try digits.append(ch);
                }
            }

            while (true) {
                // always will have a non-zero digit somewhere
                const c = digits.pop();
                if (c != '0') {
                    digits.append(c) catch unreachable;
                    break;
                }
            }
        } // Non power-of-two: batch divisions per word size.
        else {
            const digits_per_limb = math.log(Limb, base, maxInt(Limb));
            var limb_base: Limb = 1;
            var j: usize = 0;
            while (j < digits_per_limb) : (j += 1) {
                limb_base *= base;
            }

            var q = try self.clone();
            defer q.deinit();
            q.abs();
            var r = try Int.init(allocator);
            defer r.deinit();
            var b = try Int.initSet(allocator, limb_base);
            defer b.deinit();

            while (q.len() >= 2) {
                try Int.divTrunc(&q, &r, q, b);

                var r_word = r.limbs[0];
                var i: usize = 0;
                while (i < digits_per_limb) : (i += 1) {
                    const ch = try digitToChar(@intCast(u8, r_word % base), base);
                    r_word /= base;
                    try digits.append(ch);
                }
            }

            {
                debug.assert(q.len() == 1);

                var r_word = q.limbs[0];
                while (r_word != 0) {
                    const ch = try digitToChar(@intCast(u8, r_word % base), base);
                    r_word /= base;
                    try digits.append(ch);
                }
            }
        }

        if (!self.isPositive()) {
            try digits.append('-');
        }

        var s = digits.toOwnedSlice();
        mem.reverse(u8, s);
        return s;
    }

    /// To allow `std.fmt.printf` to work with Int.
    /// TODO make this non-allocating
    pub fn format(
        self: Int,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        context: var,
        comptime FmtError: type,
        output: fn (@TypeOf(context), []const u8) FmtError!void,
    ) FmtError!void {
        self.assertWritable();
        // TODO look at fmt and support other bases
        // TODO support read-only fixed integers
        const str = self.toString(self.allocator.?, 10) catch @panic("TODO make this non allocating");
        defer self.allocator.?.free(str);
        return output(context, str);
    }

    /// Returns -1, 0, 1 if |a| < |b|, |a| == |b| or |a| > |b| respectively.
    pub fn cmpAbs(a: Int, b: Int) i8 {
        if (a.len() < b.len()) {
            return -1;
        }
        if (a.len() > b.len()) {
            return 1;
        }

        var i: usize = a.len() - 1;
        while (i != 0) : (i -= 1) {
            if (a.limbs[i] != b.limbs[i]) {
                break;
            }
        }

        if (a.limbs[i] < b.limbs[i]) {
            return -1;
        } else if (a.limbs[i] > b.limbs[i]) {
            return 1;
        } else {
            return 0;
        }
    }

    /// Returns -1, 0, 1 if a < b, a == b or a > b respectively.
    pub fn cmp(a: Int, b: Int) i8 {
        if (a.isPositive() != b.isPositive()) {
            return if (a.isPositive()) @as(i8, 1) else -1;
        } else {
            const r = cmpAbs(a, b);
            return if (a.isPositive()) r else -r;
        }
    }

    /// Returns true if a == 0.
    pub fn eqZero(a: Int) bool {
        return a.len() == 1 and a.limbs[0] == 0;
    }

    /// Returns true if |a| == |b|.
    pub fn eqAbs(a: Int, b: Int) bool {
        return cmpAbs(a, b) == 0;
    }

    /// Returns true if a == b.
    pub fn eq(a: Int, b: Int) bool {
        return cmp(a, b) == 0;
    }

    // Normalize a possible sequence of leading zeros.
    //
    // [1, 2, 3, 4, 0] -> [1, 2, 3, 4]
    // [1, 2, 0, 0, 0] -> [1, 2]
    // [0, 0, 0, 0, 0] -> [0]
    fn normalize(r: *Int, length: usize) void {
        debug.assert(length > 0);
        debug.assert(length <= r.limbs.len);

        var j = length;
        while (j > 0) : (j -= 1) {
            if (r.limbs[j - 1] != 0) {
                break;
            }
        }

        // Handle zero
        r.setLen(if (j != 0) j else 1);
    }

    // Cannot be used as a result argument to any function.
    fn readOnlyPositive(a: Int) Int {
        return Int{
            .allocator = null,
            .metadata = a.len(),
            .limbs = a.limbs,
        };
    }

    /// r = a + b
    ///
    /// r, a and b may be aliases.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn add(r: *Int, a: Int, b: Int) Allocator.Error!void {
        r.assertWritable();
        if (a.eqZero()) {
            try r.copy(b);
            return;
        } else if (b.eqZero()) {
            try r.copy(a);
            return;
        }

        if (a.isPositive() != b.isPositive()) {
            if (a.isPositive()) {
                // (a) + (-b) => a - b
                try r.sub(a, readOnlyPositive(b));
            } else {
                // (-a) + (b) => b - a
                try r.sub(b, readOnlyPositive(a));
            }
        } else {
            if (a.len() >= b.len()) {
                try r.ensureCapacity(a.len() + 1);
                lladd(r.limbs[0..], a.limbs[0..a.len()], b.limbs[0..b.len()]);
                r.normalize(a.len() + 1);
            } else {
                try r.ensureCapacity(b.len() + 1);
                lladd(r.limbs[0..], b.limbs[0..b.len()], a.limbs[0..a.len()]);
                r.normalize(b.len() + 1);
            }

            r.setSign(a.isPositive());
        }
    }

    // Knuth 4.3.1, Algorithm A.
    fn lladd(r: []Limb, a: []const Limb, b: []const Limb) void {
        @setRuntimeSafety(false);
        debug.assert(a.len != 0 and b.len != 0);
        debug.assert(a.len >= b.len);
        debug.assert(r.len >= a.len + 1);

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

        r[i] = carry;
    }

    /// r = a - b
    ///
    /// r, a and b may be aliases.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn sub(r: *Int, a: Int, b: Int) !void {
        r.assertWritable();
        if (a.isPositive() != b.isPositive()) {
            if (a.isPositive()) {
                // (a) - (-b) => a + b
                try r.add(a, readOnlyPositive(b));
            } else {
                // (-a) - (b) => -(a + b)
                try r.add(readOnlyPositive(a), b);
                r.setSign(false);
            }
        } else {
            if (a.isPositive()) {
                // (a) - (b) => a - b
                if (a.cmp(b) >= 0) {
                    try r.ensureCapacity(a.len() + 1);
                    llsub(r.limbs[0..], a.limbs[0..a.len()], b.limbs[0..b.len()]);
                    r.normalize(a.len());
                    r.setSign(true);
                } else {
                    try r.ensureCapacity(b.len() + 1);
                    llsub(r.limbs[0..], b.limbs[0..b.len()], a.limbs[0..a.len()]);
                    r.normalize(b.len());
                    r.setSign(false);
                }
            } else {
                // (-a) - (-b) => -(a - b)
                if (a.cmp(b) < 0) {
                    try r.ensureCapacity(a.len() + 1);
                    llsub(r.limbs[0..], a.limbs[0..a.len()], b.limbs[0..b.len()]);
                    r.normalize(a.len());
                    r.setSign(false);
                } else {
                    try r.ensureCapacity(b.len() + 1);
                    llsub(r.limbs[0..], b.limbs[0..b.len()], a.limbs[0..a.len()]);
                    r.normalize(b.len());
                    r.setSign(true);
                }
            }
        }
    }

    // Knuth 4.3.1, Algorithm S.
    fn llsub(r: []Limb, a: []const Limb, b: []const Limb) void {
        @setRuntimeSafety(false);
        debug.assert(a.len != 0 and b.len != 0);
        debug.assert(a.len > b.len or (a.len == b.len and a[a.len - 1] >= b[b.len - 1]));
        debug.assert(r.len >= a.len);

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

        debug.assert(borrow == 0);
    }

    /// rma = a * b
    ///
    /// rma, a and b may be aliases. However, it is more efficient if rma does not alias a or b.
    ///
    /// Returns an error if memory could not be allocated.
    pub fn mul(rma: *Int, a: Int, b: Int) !void {
        rma.assertWritable();

        var r = rma;
        var aliased = rma.limbs.ptr == a.limbs.ptr or rma.limbs.ptr == b.limbs.ptr;

        var sr: Int = undefined;
        if (aliased) {
            sr = try Int.initCapacity(rma.allocator.?, a.len() + b.len());
            r = &sr;
            aliased = true;
        }
        defer if (aliased) {
            rma.swap(r);
            r.deinit();
        };

        try r.ensureCapacity(a.len() + b.len() + 1);

        mem.set(Limb, r.limbs[0 .. a.len() + b.len() + 1], 0);

        try llmulacc(rma.allocator.?, r.limbs, a.limbs[0..a.len()], b.limbs[0..b.len()]);

        r.normalize(a.len() + b.len());
        r.setSign(a.isPositive() == b.isPositive());
    }

    // a + b * c + *carry, sets carry to the overflow bits
    pub fn addMulLimbWithCarry(a: Limb, b: Limb, c: Limb, carry: *Limb) Limb {
        @setRuntimeSafety(false);
        var r1: Limb = undefined;

        // r1 = a + *carry
        const c1: Limb = @boolToInt(@addWithOverflow(Limb, a, carry.*, &r1));

        // r2 = b * c
        const bc = @as(DoubleLimb, math.mulWide(Limb, b, c));
        const r2 = @truncate(Limb, bc);
        const c2 = @truncate(Limb, bc >> Limb.bit_count);

        // r1 = r1 + r2
        const c3: Limb = @boolToInt(@addWithOverflow(Limb, r1, r2, &r1));

        // This never overflows, c1, c3 are either 0 or 1 and if both are 1 then
        // c2 is at least <= maxInt(Limb) - 2.
        carry.* = c1 + c2 + c3;

        return r1;
    }

    fn llmulDigit(acc: []Limb, y: []const Limb, xi: Limb) void {
        @setRuntimeSafety(false);
        if (xi == 0) {
            return;
        }

        var carry: usize = 0;
        var a_lo = acc[0..y.len];
        var a_hi = acc[y.len..];

        var j: usize = 0;
        while (j < a_lo.len) : (j += 1) {
            a_lo[j] = @call(.{ .modifier = .always_inline }, addMulLimbWithCarry, .{ a_lo[j], y[j], xi, &carry });
        }

        j = 0;
        while ((carry != 0) and (j < a_hi.len)) : (j += 1) {
            carry = @boolToInt(@addWithOverflow(Limb, a_hi[j], carry, &a_hi[j]));
        }
    }

    // Knuth 4.3.1, Algorithm M.
    //
    // r MUST NOT alias any of a or b.
    fn llmulacc(allocator: *Allocator, r: []Limb, a: []const Limb, b: []const Limb) error{OutOfMemory}!void {
        @setRuntimeSafety(false);

        const a_norm = a[0..llnormalize(a)];
        const b_norm = b[0..llnormalize(b)];
        var x = a_norm;
        var y = b_norm;
        if (a_norm.len > b_norm.len) {
            x = b_norm;
            y = a_norm;
        }

        debug.assert(r.len >= x.len + y.len + 1);

        // 48 is a pretty abitrary size chosen based on performance of a factorial program.
        if (x.len <= 48) {
            // Basecase multiplication
            var i: usize = 0;
            while (i < x.len) : (i += 1) {
                llmulDigit(r[i..], y, x[i]);
            }
        } else {
            // Karatsuba multiplication
            const split = @divFloor(x.len, 2);
            var x0 = x[0..split];
            var x1 = x[split..x.len];
            var y0 = y[0..split];
            var y1 = y[split..y.len];

            var tmp = try allocator.alloc(Limb, x1.len + y1.len + 1);
            defer allocator.free(tmp);
            mem.set(Limb, tmp, 0);

            try llmulacc(allocator, tmp, x1, y1);

            var length = llnormalize(tmp);
            _ = llaccum(r[split..], tmp[0..length]);
            _ = llaccum(r[split * 2 ..], tmp[0..length]);

            mem.set(Limb, tmp[0..length], 0);

            try llmulacc(allocator, tmp, x0, y0);

            length = llnormalize(tmp);
            _ = llaccum(r[0..], tmp[0..length]);
            _ = llaccum(r[split..], tmp[0..length]);

            const x_cmp = llcmp(x1, x0);
            const y_cmp = llcmp(y1, y0);
            if (x_cmp * y_cmp == 0) {
                return;
            }
            const x0_len = llnormalize(x0);
            const x1_len = llnormalize(x1);
            var j0 = try allocator.alloc(Limb, math.max(x0_len, x1_len));
            defer allocator.free(j0);
            if (x_cmp == 1) {
                llsub(j0, x1[0..x1_len], x0[0..x0_len]);
            } else {
                llsub(j0, x0[0..x0_len], x1[0..x1_len]);
            }

            const y0_len = llnormalize(y0);
            const y1_len = llnormalize(y1);
            var j1 = try allocator.alloc(Limb, math.max(y0_len, y1_len));
            defer allocator.free(j1);
            if (y_cmp == 1) {
                llsub(j1, y1[0..y1_len], y0[0..y0_len]);
            } else {
                llsub(j1, y0[0..y0_len], y1[0..y1_len]);
            }
            const j0_len = llnormalize(j0);
            const j1_len = llnormalize(j1);
            if (x_cmp == y_cmp) {
                mem.set(Limb, tmp[0..length], 0);
                try llmulacc(allocator, tmp, j0, j1);

                length = Int.llnormalize(tmp);
                llsub(r[split..], r[split..], tmp[0..length]);
            } else {
                try llmulacc(allocator, r[split..], j0, j1);
            }
        }
    }

    // r = r + a
    fn llaccum(r: []Limb, a: []const Limb) Limb {
        @setRuntimeSafety(false);
        debug.assert(r.len != 0 and a.len != 0);
        debug.assert(r.len >= a.len);

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

        return carry;
    }

    /// Returns -1, 0, 1 if |a| < |b|, |a| == |b| or |a| > |b| respectively for limbs.
    pub fn llcmp(a: []const Limb, b: []const Limb) i8 {
        @setRuntimeSafety(false);
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

    // returns the min length the limb could be.
    fn llnormalize(a: []const Limb) usize {
        @setRuntimeSafety(false);
        var j = a.len;
        while (j > 0) : (j -= 1) {
            if (a[j - 1] != 0) {
                break;
            }
        }

        // Handle zero
        return if (j != 0) j else 1;
    }

    /// q = a / b (rem r)
    ///
    /// a / b are floored (rounded towards 0).
    pub fn divFloor(q: *Int, r: *Int, a: Int, b: Int) !void {
        try div(q, r, a, b);

        // Trunc -> Floor.
        if (!q.isPositive()) {
            const one = Int.initFixed(([_]Limb{1})[0..]);
            try q.sub(q.*, one);
            try r.add(q.*, one);
        }
        r.setSign(b.isPositive());
    }

    /// q = a / b (rem r)
    ///
    /// a / b are truncated (rounded towards -inf).
    pub fn divTrunc(q: *Int, r: *Int, a: Int, b: Int) !void {
        try div(q, r, a, b);
        r.setSign(a.isPositive());
    }

    // Truncates by default.
    fn div(quo: *Int, rem: *Int, a: Int, b: Int) !void {
        quo.assertWritable();
        rem.assertWritable();

        if (b.eqZero()) {
            @panic("division by zero");
        }
        if (quo == rem) {
            @panic("quo and rem cannot be same variable");
        }

        if (a.cmpAbs(b) < 0) {
            // quo may alias a so handle rem first
            try rem.copy(a);
            rem.setSign(a.isPositive() == b.isPositive());

            quo.metadata = 1;
            quo.limbs[0] = 0;
            return;
        }

        // Handle trailing zero-words of divisor/dividend. These are not handled in the following
        // algorithms.
        const a_zero_limb_count = blk: {
            var i: usize = 0;
            while (i < a.len()) : (i += 1) {
                if (a.limbs[i] != 0) break;
            }
            break :blk i;
        };
        const b_zero_limb_count = blk: {
            var i: usize = 0;
            while (i < b.len()) : (i += 1) {
                if (b.limbs[i] != 0) break;
            }
            break :blk i;
        };

        const ab_zero_limb_count = std.math.min(a_zero_limb_count, b_zero_limb_count);

        if (b.len() - ab_zero_limb_count == 1) {
            try quo.ensureCapacity(a.len());

            lldiv1(quo.limbs[0..], &rem.limbs[0], a.limbs[ab_zero_limb_count..a.len()], b.limbs[b.len() - 1]);
            quo.normalize(a.len() - ab_zero_limb_count);
            quo.setSign(a.isPositive() == b.isPositive());

            rem.metadata = 1;
        } else {
            // x and y are modified during division
            var x = try Int.initCapacity(quo.allocator.?, a.len());
            defer x.deinit();
            try x.copy(a);

            var y = try Int.initCapacity(quo.allocator.?, b.len());
            defer y.deinit();
            try y.copy(b);

            // x may grow one limb during normalization
            try quo.ensureCapacity(a.len() + y.len());

            // Shrink x, y such that the trailing zero limbs shared between are removed.
            if (ab_zero_limb_count != 0) {
                std.mem.copy(Limb, x.limbs[0..], x.limbs[ab_zero_limb_count..]);
                std.mem.copy(Limb, y.limbs[0..], y.limbs[ab_zero_limb_count..]);
                x.metadata -= ab_zero_limb_count;
                y.metadata -= ab_zero_limb_count;
            }

            try divN(quo.allocator.?, quo, rem, &x, &y);
            quo.setSign(a.isPositive() == b.isPositive());
        }

        if (ab_zero_limb_count != 0) {
            try rem.shiftLeft(rem.*, ab_zero_limb_count * Limb.bit_count);
        }
    }

    // Knuth 4.3.1, Exercise 16.
    fn lldiv1(quo: []Limb, rem: *Limb, a: []const Limb, b: Limb) void {
        @setRuntimeSafety(false);
        debug.assert(a.len > 1 or a[0] >= b);
        debug.assert(quo.len >= a.len);

        rem.* = 0;
        for (a) |_, ri| {
            const i = a.len - ri - 1;
            const pdiv = ((@as(DoubleLimb, rem.*) << Limb.bit_count) | a[i]);

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

    // Handbook of Applied Cryptography, 14.20
    //
    // x = qy + r where 0 <= r < y
    fn divN(allocator: *Allocator, q: *Int, r: *Int, x: *Int, y: *Int) !void {
        debug.assert(y.len() >= 2);
        debug.assert(x.len() >= y.len());
        debug.assert(q.limbs.len >= x.len() + y.len() - 1);
        debug.assert(default_capacity >= 3); // see 3.2

        var tmp = try Int.init(allocator);
        defer tmp.deinit();

        // Normalize so y > Limb.bit_count / 2 (i.e. leading bit is set) and even
        var norm_shift = @clz(Limb, y.limbs[y.len() - 1]);
        if (norm_shift == 0 and y.isOdd()) {
            norm_shift = Limb.bit_count;
        }
        try x.shiftLeft(x.*, norm_shift);
        try y.shiftLeft(y.*, norm_shift);

        const n = x.len() - 1;
        const t = y.len() - 1;

        // 1.
        q.metadata = n - t + 1;
        mem.set(Limb, q.limbs[0..q.len()], 0);

        // 2.
        try tmp.shiftLeft(y.*, Limb.bit_count * (n - t));
        while (x.cmp(tmp) >= 0) {
            q.limbs[n - t] += 1;
            try x.sub(x.*, tmp);
        }

        // 3.
        var i = n;
        while (i > t) : (i -= 1) {
            // 3.1
            if (x.limbs[i] == y.limbs[t]) {
                q.limbs[i - t - 1] = maxInt(Limb);
            } else {
                const num = (@as(DoubleLimb, x.limbs[i]) << Limb.bit_count) | @as(DoubleLimb, x.limbs[i - 1]);
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

                if (r.cmpAbs(tmp) <= 0) {
                    break;
                }

                q.limbs[i - t - 1] -= 1;
            }

            // 3.3
            try tmp.set(q.limbs[i - t - 1]);
            try tmp.mul(tmp, y.*);
            try tmp.shiftLeft(tmp, Limb.bit_count * (i - t - 1));
            try x.sub(x.*, tmp);

            if (!x.isPositive()) {
                try tmp.shiftLeft(y.*, Limb.bit_count * (i - t - 1));
                try x.add(x.*, tmp);
                q.limbs[i - t - 1] -= 1;
            }
        }

        // Denormalize
        q.normalize(q.len());

        try r.shiftRight(x.*, norm_shift);
        r.normalize(r.len());
    }

    /// r = a << shift, in other words, r = a * 2^shift
    pub fn shiftLeft(r: *Int, a: Int, shift: usize) !void {
        r.assertWritable();

        try r.ensureCapacity(a.len() + (shift / Limb.bit_count) + 1);
        llshl(r.limbs[0..], a.limbs[0..a.len()], shift);
        r.normalize(a.len() + (shift / Limb.bit_count) + 1);
        r.setSign(a.isPositive());
    }

    fn llshl(r: []Limb, a: []const Limb, shift: usize) void {
        @setRuntimeSafety(false);
        debug.assert(a.len >= 1);
        debug.assert(r.len >= a.len + (shift / Limb.bit_count) + 1);

        const limb_shift = shift / Limb.bit_count + 1;
        const interior_limb_shift = @intCast(Log2Limb, shift % Limb.bit_count);

        var carry: Limb = 0;
        var i: usize = 0;
        while (i < a.len) : (i += 1) {
            const src_i = a.len - i - 1;
            const dst_i = src_i + limb_shift;

            const src_digit = a[src_i];
            r[dst_i] = carry | @call(.{ .modifier = .always_inline }, math.shr, .{
                Limb,
                src_digit,
                Limb.bit_count - @intCast(Limb, interior_limb_shift),
            });
            carry = (src_digit << interior_limb_shift);
        }

        r[limb_shift - 1] = carry;
        mem.set(Limb, r[0 .. limb_shift - 1], 0);
    }

    /// r = a >> shift
    pub fn shiftRight(r: *Int, a: Int, shift: usize) !void {
        r.assertWritable();

        if (a.len() <= shift / Limb.bit_count) {
            r.metadata = 1;
            r.limbs[0] = 0;
            return;
        }

        try r.ensureCapacity(a.len() - (shift / Limb.bit_count));
        const r_len = llshr(r.limbs[0..], a.limbs[0..a.len()], shift);
        r.metadata = a.len() - (shift / Limb.bit_count);
        r.setSign(a.isPositive());
    }

    fn llshr(r: []Limb, a: []const Limb, shift: usize) void {
        @setRuntimeSafety(false);
        debug.assert(a.len >= 1);
        debug.assert(r.len >= a.len - (shift / Limb.bit_count));

        const limb_shift = shift / Limb.bit_count;
        const interior_limb_shift = @intCast(Log2Limb, shift % Limb.bit_count);

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
                Limb.bit_count - @intCast(Limb, interior_limb_shift),
            });
        }
    }

    /// r = a | b
    ///
    /// a and b are zero-extended to the longer of a or b.
    pub fn bitOr(r: *Int, a: Int, b: Int) !void {
        r.assertWritable();

        if (a.len() > b.len()) {
            try r.ensureCapacity(a.len());
            llor(r.limbs[0..], a.limbs[0..a.len()], b.limbs[0..b.len()]);
            r.setLen(a.len());
        } else {
            try r.ensureCapacity(b.len());
            llor(r.limbs[0..], b.limbs[0..b.len()], a.limbs[0..a.len()]);
            r.setLen(b.len());
        }
    }

    fn llor(r: []Limb, a: []const Limb, b: []const Limb) void {
        @setRuntimeSafety(false);
        debug.assert(r.len >= a.len);
        debug.assert(a.len >= b.len);

        var i: usize = 0;
        while (i < b.len) : (i += 1) {
            r[i] = a[i] | b[i];
        }
        while (i < a.len) : (i += 1) {
            r[i] = a[i];
        }
    }

    /// r = a & b
    pub fn bitAnd(r: *Int, a: Int, b: Int) !void {
        r.assertWritable();

        if (a.len() > b.len()) {
            try r.ensureCapacity(b.len());
            lland(r.limbs[0..], a.limbs[0..a.len()], b.limbs[0..b.len()]);
            r.normalize(b.len());
        } else {
            try r.ensureCapacity(a.len());
            lland(r.limbs[0..], b.limbs[0..b.len()], a.limbs[0..a.len()]);
            r.normalize(a.len());
        }
    }

    fn lland(r: []Limb, a: []const Limb, b: []const Limb) void {
        @setRuntimeSafety(false);
        debug.assert(r.len >= b.len);
        debug.assert(a.len >= b.len);

        var i: usize = 0;
        while (i < b.len) : (i += 1) {
            r[i] = a[i] & b[i];
        }
    }

    /// r = a ^ b
    pub fn bitXor(r: *Int, a: Int, b: Int) !void {
        r.assertWritable();

        if (a.len() > b.len()) {
            try r.ensureCapacity(a.len());
            llxor(r.limbs[0..], a.limbs[0..a.len()], b.limbs[0..b.len()]);
            r.normalize(a.len());
        } else {
            try r.ensureCapacity(b.len());
            llxor(r.limbs[0..], b.limbs[0..b.len()], a.limbs[0..a.len()]);
            r.normalize(b.len());
        }
    }

    fn llxor(r: []Limb, a: []const Limb, b: []const Limb) void {
        @setRuntimeSafety(false);
        debug.assert(r.len >= a.len);
        debug.assert(a.len >= b.len);

        var i: usize = 0;
        while (i < b.len) : (i += 1) {
            r[i] = a[i] ^ b[i];
        }
        while (i < a.len) : (i += 1) {
            r[i] = a[i];
        }
    }
};

// NOTE: All the following tests assume the max machine-word will be 64-bit.
//
// They will still run on larger than this and should pass, but the multi-limb code-paths
// may be untested in some cases.

test "big.int comptime_int set" {
    comptime var s = 0xefffffff00000001eeeeeeefaaaaaaab;
    var a = try Int.initSet(testing.allocator, s);
    defer a.deinit();

    const s_limb_count = 128 / Limb.bit_count;

    comptime var i: usize = 0;
    inline while (i < s_limb_count) : (i += 1) {
        const result = @as(Limb, s & maxInt(Limb));
        s >>= Limb.bit_count / 2;
        s >>= Limb.bit_count / 2;
        testing.expect(a.limbs[i] == result);
    }
}

test "big.int comptime_int set negative" {
    var a = try Int.initSet(testing.allocator, -10);
    defer a.deinit();

    testing.expect(a.limbs[0] == 10);
    testing.expect(a.isPositive() == false);
}

test "big.int int set unaligned small" {
    var a = try Int.initSet(testing.allocator, @as(u7, 45));
    defer a.deinit();

    testing.expect(a.limbs[0] == 45);
    testing.expect(a.isPositive() == true);
}

test "big.int comptime_int to" {
    const a = try Int.initSet(testing.allocator, 0xefffffff00000001eeeeeeefaaaaaaab);
    defer a.deinit();

    testing.expect((try a.to(u128)) == 0xefffffff00000001eeeeeeefaaaaaaab);
}

test "big.int sub-limb to" {
    const a = try Int.initSet(testing.allocator, 10);
    defer a.deinit();

    testing.expect((try a.to(u8)) == 10);
}

test "big.int to target too small error" {
    const a = try Int.initSet(testing.allocator, 0xffffffff);
    defer a.deinit();

    testing.expectError(error.TargetTooSmall, a.to(u8));
}

test "big.int normalize" {
    var a = try Int.init(testing.allocator);
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
    var a = try Int.init(testing.allocator);
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
    var a = try Int.init(testing.allocator);
    defer a.deinit();

    try a.set(0);
    testing.expect(a.isEven());
    testing.expect(!a.isOdd());

    try a.set(7);
    testing.expect(!a.isEven());
    testing.expect(a.isOdd());
}

test "big.int bitcount + sizeInBase" {
    var a = try Int.init(testing.allocator);
    defer a.deinit();

    try a.set(0b100);
    testing.expect(a.bitCountAbs() == 3);
    testing.expect(a.sizeInBase(2) >= 3);
    testing.expect(a.sizeInBase(10) >= 1);

    a.negate();
    testing.expect(a.bitCountAbs() == 3);
    testing.expect(a.sizeInBase(2) >= 4);
    testing.expect(a.sizeInBase(10) >= 2);

    try a.set(0xffffffff);
    testing.expect(a.bitCountAbs() == 32);
    testing.expect(a.sizeInBase(2) >= 32);
    testing.expect(a.sizeInBase(10) >= 10);

    try a.shiftLeft(a, 5000);
    testing.expect(a.bitCountAbs() == 5032);
    testing.expect(a.sizeInBase(2) >= 5032);
    a.setSign(false);

    testing.expect(a.bitCountAbs() == 5032);
    testing.expect(a.sizeInBase(2) >= 5033);
}

test "big.int bitcount/to" {
    var a = try Int.init(testing.allocator);
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
    var a = try Int.init(testing.allocator);
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
    var a = try Int.init(testing.allocator);
    defer a.deinit();

    try a.setString(10, "120317241209124781241290847124");
    testing.expect((try a.to(u128)) == 120317241209124781241290847124);
}

test "big.int string negative" {
    var a = try Int.init(testing.allocator);
    defer a.deinit();

    try a.setString(10, "-1023");
    testing.expect((try a.to(i32)) == -1023);
}

test "big.int string set bad char error" {
    var a = try Int.init(testing.allocator);
    defer a.deinit();
    testing.expectError(error.InvalidCharForDigit, a.setString(10, "x"));
}

test "big.int string set bad base error" {
    var a = try Int.init(testing.allocator);
    defer a.deinit();
    testing.expectError(error.InvalidBase, a.setString(45, "10"));
}

test "big.int string to" {
    const a = try Int.initSet(testing.allocator, 120317241209124781241290847124);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 10);
    defer testing.allocator.free(as);
    const es = "120317241209124781241290847124";

    testing.expect(mem.eql(u8, as, es));
}

test "big.int string to base base error" {
    const a = try Int.initSet(testing.allocator, 0xffffffff);
    defer a.deinit();

    testing.expectError(error.InvalidBase, a.toString(testing.allocator, 45));
}

test "big.int string to base 2" {
    const a = try Int.initSet(testing.allocator, -0b1011);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 2);
    defer testing.allocator.free(as);
    const es = "-1011";

    testing.expect(mem.eql(u8, as, es));
}

test "big.int string to base 16" {
    const a = try Int.initSet(testing.allocator, 0xefffffff00000001eeeeeeefaaaaaaab);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 16);
    defer testing.allocator.free(as);
    const es = "efffffff00000001eeeeeeefaaaaaaab";

    testing.expect(mem.eql(u8, as, es));
}

test "big.int neg string to" {
    const a = try Int.initSet(testing.allocator, -123907434);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 10);
    defer testing.allocator.free(as);
    const es = "-123907434";

    testing.expect(mem.eql(u8, as, es));
}

test "big.int zero string to" {
    const a = try Int.initSet(testing.allocator, 0);
    defer a.deinit();

    const as = try a.toString(testing.allocator, 10);
    defer testing.allocator.free(as);
    const es = "0";

    testing.expect(mem.eql(u8, as, es));
}

test "big.int clone" {
    var a = try Int.initSet(testing.allocator, 1234);
    defer a.deinit();
    const b = try a.clone();
    defer b.deinit();

    testing.expect((try a.to(u32)) == 1234);
    testing.expect((try b.to(u32)) == 1234);

    try a.set(77);
    testing.expect((try a.to(u32)) == 77);
    testing.expect((try b.to(u32)) == 1234);
}

test "big.int swap" {
    var a = try Int.initSet(testing.allocator, 1234);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 5678);
    defer b.deinit();

    testing.expect((try a.to(u32)) == 1234);
    testing.expect((try b.to(u32)) == 5678);

    a.swap(&b);

    testing.expect((try a.to(u32)) == 5678);
    testing.expect((try b.to(u32)) == 1234);
}

test "big.int to negative" {
    var a = try Int.initSet(testing.allocator, -10);
    defer a.deinit();

    testing.expect((try a.to(i32)) == -10);
}

test "big.int compare" {
    var a = try Int.initSet(testing.allocator, -11);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 10);
    defer b.deinit();

    testing.expect(a.cmpAbs(b) == 1);
    testing.expect(a.cmp(b) == -1);
}

test "big.int compare similar" {
    var a = try Int.initSet(testing.allocator, 0xffffffffeeeeeeeeffffffffeeeeeeee);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0xffffffffeeeeeeeeffffffffeeeeeeef);
    defer b.deinit();

    testing.expect(a.cmpAbs(b) == -1);
    testing.expect(b.cmpAbs(a) == 1);
}

test "big.int compare different limb size" {
    var a = try Int.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 1);
    defer b.deinit();

    testing.expect(a.cmpAbs(b) == 1);
    testing.expect(b.cmpAbs(a) == -1);
}

test "big.int compare multi-limb" {
    var a = try Int.initSet(testing.allocator, -0x7777777799999999ffffeeeeffffeeeeffffeeeef);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0x7777777799999999ffffeeeeffffeeeeffffeeeee);
    defer b.deinit();

    testing.expect(a.cmpAbs(b) == 1);
    testing.expect(a.cmp(b) == -1);
}

test "big.int equality" {
    var a = try Int.initSet(testing.allocator, 0xffffffff1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, -0xffffffff1);
    defer b.deinit();

    testing.expect(a.eqAbs(b));
    testing.expect(!a.eq(b));
}

test "big.int abs" {
    var a = try Int.initSet(testing.allocator, -5);
    defer a.deinit();

    a.abs();
    testing.expect((try a.to(u32)) == 5);

    a.abs();
    testing.expect((try a.to(u32)) == 5);
}

test "big.int negate" {
    var a = try Int.initSet(testing.allocator, 5);
    defer a.deinit();

    a.negate();
    testing.expect((try a.to(i32)) == -5);

    a.negate();
    testing.expect((try a.to(i32)) == 5);
}

test "big.int add single-single" {
    var a = try Int.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 5);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.add(a, b);

    testing.expect((try c.to(u32)) == 55);
}

test "big.int add multi-single" {
    var a = try Int.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 1);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();

    try c.add(a, b);
    testing.expect((try c.to(DoubleLimb)) == maxInt(Limb) + 2);

    try c.add(b, a);
    testing.expect((try c.to(DoubleLimb)) == maxInt(Limb) + 2);
}

test "big.int add multi-multi" {
    const op1 = 0xefefefef7f7f7f7f;
    const op2 = 0xfefefefe9f9f9f9f;
    var a = try Int.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, op2);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.add(a, b);

    testing.expect((try c.to(u128)) == op1 + op2);
}

test "big.int add zero-zero" {
    var a = try Int.initSet(testing.allocator, 0);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.add(a, b);

    testing.expect((try c.to(u32)) == 0);
}

test "big.int add alias multi-limb nonzero-zero" {
    const op1 = 0xffffffff777777771;
    var a = try Int.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0);
    defer b.deinit();

    try a.add(a, b);

    testing.expect((try a.to(u128)) == op1);
}

test "big.int add sign" {
    var a = try Int.init(testing.allocator);
    defer a.deinit();

    const one = try Int.initSet(testing.allocator, 1);
    defer one.deinit();
    const two = try Int.initSet(testing.allocator, 2);
    defer two.deinit();
    const neg_one = try Int.initSet(testing.allocator, -1);
    defer neg_one.deinit();
    const neg_two = try Int.initSet(testing.allocator, -2);
    defer neg_two.deinit();

    try a.add(one, two);
    testing.expect((try a.to(i32)) == 3);

    try a.add(neg_one, two);
    testing.expect((try a.to(i32)) == 1);

    try a.add(one, neg_two);
    testing.expect((try a.to(i32)) == -1);

    try a.add(neg_one, neg_two);
    testing.expect((try a.to(i32)) == -3);
}

test "big.int sub single-single" {
    var a = try Int.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 5);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.sub(a, b);

    testing.expect((try c.to(u32)) == 45);
}

test "big.int sub multi-single" {
    var a = try Int.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 1);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.sub(a, b);

    testing.expect((try c.to(Limb)) == maxInt(Limb));
}

test "big.int sub multi-multi" {
    const op1 = 0xefefefefefefefefefefefef;
    const op2 = 0xabababababababababababab;

    var a = try Int.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, op2);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.sub(a, b);

    testing.expect((try c.to(u128)) == op1 - op2);
}

test "big.int sub equal" {
    var a = try Int.initSet(testing.allocator, 0x11efefefefefefefefefefefef);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0x11efefefefefefefefefefefef);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.sub(a, b);

    testing.expect((try c.to(u32)) == 0);
}

test "big.int sub sign" {
    var a = try Int.init(testing.allocator);
    defer a.deinit();

    const one = try Int.initSet(testing.allocator, 1);
    defer one.deinit();
    const two = try Int.initSet(testing.allocator, 2);
    defer two.deinit();
    const neg_one = try Int.initSet(testing.allocator, -1);
    defer neg_one.deinit();
    const neg_two = try Int.initSet(testing.allocator, -2);
    defer neg_two.deinit();

    try a.sub(one, two);
    testing.expect((try a.to(i32)) == -1);

    try a.sub(neg_one, two);
    testing.expect((try a.to(i32)) == -3);

    try a.sub(one, neg_two);
    testing.expect((try a.to(i32)) == 3);

    try a.sub(neg_one, neg_two);
    testing.expect((try a.to(i32)) == 1);

    try a.sub(neg_two, neg_one);
    testing.expect((try a.to(i32)) == -1);
}

test "big.int mul single-single" {
    var a = try Int.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 5);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.mul(a, b);

    testing.expect((try c.to(u64)) == 250);
}

test "big.int mul multi-single" {
    var a = try Int.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 2);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.mul(a, b);

    testing.expect((try c.to(DoubleLimb)) == 2 * maxInt(Limb));
}

test "big.int mul multi-multi" {
    const op1 = 0x998888efefefefefefefef;
    const op2 = 0x333000abababababababab;
    var a = try Int.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, op2);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.mul(a, b);

    testing.expect((try c.to(u256)) == op1 * op2);
}

test "big.int mul alias r with a" {
    var a = try Int.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 2);
    defer b.deinit();

    try a.mul(a, b);

    testing.expect((try a.to(DoubleLimb)) == 2 * maxInt(Limb));
}

test "big.int mul alias r with b" {
    var a = try Int.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 2);
    defer b.deinit();

    try a.mul(b, a);

    testing.expect((try a.to(DoubleLimb)) == 2 * maxInt(Limb));
}

test "big.int mul alias r with a and b" {
    var a = try Int.initSet(testing.allocator, maxInt(Limb));
    defer a.deinit();

    try a.mul(a, a);

    testing.expect((try a.to(DoubleLimb)) == maxInt(Limb) * maxInt(Limb));
}

test "big.int mul a*0" {
    var a = try Int.initSet(testing.allocator, 0xefefefefefefefef);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.mul(a, b);

    testing.expect((try c.to(u32)) == 0);
}

test "big.int mul 0*0" {
    var a = try Int.initSet(testing.allocator, 0);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0);
    defer b.deinit();

    var c = try Int.init(testing.allocator);
    defer c.deinit();
    try c.mul(a, b);

    testing.expect((try c.to(u32)) == 0);
}

test "big.int div single-single no rem" {
    var a = try Int.initSet(testing.allocator, 50);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 5);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u32)) == 10);
    testing.expect((try r.to(u32)) == 0);
}

test "big.int div single-single with rem" {
    var a = try Int.initSet(testing.allocator, 49);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 5);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u32)) == 9);
    testing.expect((try r.to(u32)) == 4);
}

test "big.int div multi-single no rem" {
    const op1 = 0xffffeeeeddddcccc;
    const op2 = 34;

    var a = try Int.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u64)) == op1 / op2);
    testing.expect((try r.to(u64)) == 0);
}

test "big.int div multi-single with rem" {
    const op1 = 0xffffeeeeddddcccf;
    const op2 = 34;

    var a = try Int.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u64)) == op1 / op2);
    testing.expect((try r.to(u64)) == 3);
}

test "big.int div multi>2-single" {
    const op1 = 0xfefefefefefefefefefefefefefefefe;
    const op2 = 0xefab8;

    var a = try Int.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u128)) == op1 / op2);
    testing.expect((try r.to(u32)) == 0x3e4e);
}

test "big.int div single-single q < r" {
    var a = try Int.initSet(testing.allocator, 0x0078f432);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0x01000000);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u64)) == 0);
    testing.expect((try r.to(u64)) == 0x0078f432);
}

test "big.int div single-single q == r" {
    var a = try Int.initSet(testing.allocator, 10);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 10);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u64)) == 1);
    testing.expect((try r.to(u64)) == 0);
}

test "big.int div q=0 alias" {
    var a = try Int.initSet(testing.allocator, 3);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 10);
    defer b.deinit();

    try Int.divTrunc(&a, &b, a, b);

    testing.expect((try a.to(u64)) == 0);
    testing.expect((try b.to(u64)) == 3);
}

test "big.int div multi-multi q < r" {
    const op1 = 0x1ffffffff0078f432;
    const op2 = 0x1ffffffff01000000;
    var a = try Int.initSet(testing.allocator, op1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, op2);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u128)) == 0);
    testing.expect((try r.to(u128)) == op1);
}

test "big.int div trunc single-single +/+" {
    const u: i32 = 5;
    const v: i32 = 3;

    var a = try Int.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

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

    var a = try Int.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

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

    var a = try Int.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

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

    var a = try Int.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

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

    var a = try Int.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divFloor(&q, &r, a, b);

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

    var a = try Int.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divFloor(&q, &r, a, b);

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

    var a = try Int.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divFloor(&q, &r, a, b);

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

    var a = try Int.initSet(testing.allocator, u);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, v);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divFloor(&q, &r, a, b);

    //  n =  q *  d + r
    // -5 =  2 * -3 + 1
    const eq = 1;
    const er = -2;

    testing.expect((try q.to(i32)) == eq);
    testing.expect((try r.to(i32)) == er);
}

test "big.int div multi-multi with rem" {
    var a = try Int.initSet(testing.allocator, 0x8888999911110000ffffeeeeddddccccbbbbaaaa9999);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0x99990000111122223333);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u128)) == 0xe38f38e39161aaabd03f0f1b);
    testing.expect((try r.to(u128)) == 0x28de0acacd806823638);
}

test "big.int div multi-multi no rem" {
    var a = try Int.initSet(testing.allocator, 0x8888999911110000ffffeeeedb4fec200ee3a4286361);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0x99990000111122223333);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u128)) == 0xe38f38e39161aaabd03f0f1b);
    testing.expect((try r.to(u128)) == 0);
}

test "big.int div multi-multi (2 branch)" {
    var a = try Int.initSet(testing.allocator, 0x866666665555555588888887777777761111111111111111);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0x86666666555555554444444433333333);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u128)) == 0x10000000000000000);
    testing.expect((try r.to(u128)) == 0x44444443444444431111111111111111);
}

test "big.int div multi-multi (3.1/3.3 branch)" {
    var a = try Int.initSet(testing.allocator, 0x11111111111111111111111111111111111111111111111111111111111111);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0x1111111111111111111111111111111111111111171);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u128)) == 0xfffffffffffffffffff);
    testing.expect((try r.to(u256)) == 0x1111111111111111111110b12222222222222222282);
}

test "big.int div multi-single zero-limb trailing" {
    var a = try Int.initSet(testing.allocator, 0x60000000000000000000000000000000000000000000000000000000000000000);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0x10000000000000000);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    var expected = try Int.initSet(testing.allocator, 0x6000000000000000000000000000000000000000000000000);
    defer expected.deinit();
    testing.expect(q.eq(expected));
    testing.expect(r.eqZero());
}

test "big.int div multi-multi zero-limb trailing (with rem)" {
    var a = try Int.initSet(testing.allocator, 0x86666666555555558888888777777776111111111111111100000000000000000000000000000000);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0x8666666655555555444444443333333300000000000000000000000000000000);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u128)) == 0x10000000000000000);

    const rs = try r.toString(testing.allocator, 16);
    defer testing.allocator.free(rs);
    testing.expect(std.mem.eql(u8, rs, "4444444344444443111111111111111100000000000000000000000000000000"));
}

test "big.int div multi-multi zero-limb trailing (with rem) and dividend zero-limb count > divisor zero-limb count" {
    var a = try Int.initSet(testing.allocator, 0x8666666655555555888888877777777611111111111111110000000000000000);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0x8666666655555555444444443333333300000000000000000000000000000000);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    testing.expect((try q.to(u128)) == 0x1);

    const rs = try r.toString(testing.allocator, 16);
    defer testing.allocator.free(rs);
    testing.expect(std.mem.eql(u8, rs, "444444434444444311111111111111110000000000000000"));
}

test "big.int div multi-multi zero-limb trailing (with rem) and dividend zero-limb count < divisor zero-limb count" {
    var a = try Int.initSet(testing.allocator, 0x86666666555555558888888777777776111111111111111100000000000000000000000000000000);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0x866666665555555544444444333333330000000000000000);
    defer b.deinit();

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    const qs = try q.toString(testing.allocator, 16);
    defer testing.allocator.free(qs);
    testing.expect(std.mem.eql(u8, qs, "10000000000000000820820803105186f"));

    const rs = try r.toString(testing.allocator, 16);
    defer testing.allocator.free(rs);
    testing.expect(std.mem.eql(u8, rs, "4e11f2baa5896a321d463b543d0104e30000000000000000"));
}

test "big.int div multi-multi fuzz case #1" {
    var a = try Int.init(testing.allocator);
    defer a.deinit();
    var b = try Int.init(testing.allocator);
    defer b.deinit();

    try a.setString(16, "ffffffffffffffffffffffffffffc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000");
    try b.setString(16, "3ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0000000000000000000000000000000000001ffffffffffffffffffffffffffffffffffffffffffffffffffc000000000000000000000000000000007fffffffffff");

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    const qs = try q.toString(testing.allocator, 16);
    defer testing.allocator.free(qs);
    testing.expect(std.mem.eql(u8, qs, "3ffffffffffffffffffffffffffff0000000000000000000000000000000000001ffffffffffffffffffffffffffff7fffffffe000000000000000000000000000180000000000000000000003fffffbfffffffdfffffffffffffeffff800000100101000000100000000020003fffffdfbfffffe3ffffffffffffeffff7fffc00800a100000017ffe000002000400007efbfff7fe9f00000037ffff3fff7fffa004006100000009ffe00000190038200bf7d2ff7fefe80400060000f7d7f8fbf9401fe38e0403ffc0bdffffa51102c300d7be5ef9df4e5060007b0127ad3fa69f97d0f820b6605ff617ddf7f32ad7a05c0d03f2e7bc78a6000e087a8bbcdc59e07a5a079128a7861f553ddebed7e8e56701756f9ead39b48cd1b0831889ea6ec1fddf643d0565b075ff07e6caea4e2854ec9227fd635ed60a2f5eef2893052ffd54718fa08604acbf6a15e78a467c4a3c53c0278af06c4416573f925491b195e8fd79302cb1aaf7caf4ecfc9aec1254cc969786363ac729f914c6ddcc26738d6b0facd54eba026580aba2eb6482a088b0d224a8852420b91ec1"));

    const rs = try r.toString(testing.allocator, 16);
    defer testing.allocator.free(rs);
    testing.expect(std.mem.eql(u8, rs, "310d1d4c414426b4836c2635bad1df3a424e50cbdd167ffccb4dfff57d36b4aae0d6ca0910698220171a0f3373c1060a046c2812f0027e321f72979daa5e7973214170d49e885de0c0ecc167837d44502430674a82522e5df6a0759548052420b91ec1"));
}

test "big.int div multi-multi fuzz case #2" {
    var a = try Int.init(testing.allocator);
    defer a.deinit();
    var b = try Int.init(testing.allocator);
    defer b.deinit();

    try a.setString(16, "3ffffffffe00000000000000000000000000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffe000000000000000000000000000000000000000000000000000000000000001fffffffffffffffff800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ffffffffffffffffffffc000000000000000000000000000000000000000000000000000000000000000");
    try b.setString(16, "ffc0000000000000000000000000000000000000000000000000");

    var q = try Int.init(testing.allocator);
    defer q.deinit();
    var r = try Int.init(testing.allocator);
    defer r.deinit();
    try Int.divTrunc(&q, &r, a, b);

    const qs = try q.toString(testing.allocator, 16);
    defer testing.allocator.free(qs);
    testing.expect(std.mem.eql(u8, qs, "40100400fe3f8fe3f8fe3f8fe3f8fe3f8fe4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f93e4f91e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4992649926499264991e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4791e4792e4b92e4b92e4b92e4b92a4a92a4a92a4"));

    const rs = try r.toString(testing.allocator, 16);
    defer testing.allocator.free(rs);
    testing.expect(std.mem.eql(u8, rs, "a900000000000000000000000000000000000000000000000000"));
}

test "big.int shift-right single" {
    var a = try Int.initSet(testing.allocator, 0xffff0000);
    defer a.deinit();
    try a.shiftRight(a, 16);

    testing.expect((try a.to(u32)) == 0xffff);
}

test "big.int shift-right multi" {
    var a = try Int.initSet(testing.allocator, 0xffff0000eeee1111dddd2222cccc3333);
    defer a.deinit();
    try a.shiftRight(a, 67);

    testing.expect((try a.to(u64)) == 0x1fffe0001dddc222);
}

test "big.int shift-left single" {
    var a = try Int.initSet(testing.allocator, 0xffff);
    defer a.deinit();
    try a.shiftLeft(a, 16);

    testing.expect((try a.to(u64)) == 0xffff0000);
}

test "big.int shift-left multi" {
    var a = try Int.initSet(testing.allocator, 0x1fffe0001dddc222);
    defer a.deinit();
    try a.shiftLeft(a, 67);

    testing.expect((try a.to(u128)) == 0xffff0000eeee11100000000000000000);
}

test "big.int shift-right negative" {
    var a = try Int.init(testing.allocator);
    defer a.deinit();

    try a.shiftRight(try Int.initSet(testing.allocator, -20), 2);
    defer a.deinit();
    testing.expect((try a.to(i32)) == -20 >> 2);

    try a.shiftRight(try Int.initSet(testing.allocator, -5), 10);
    defer a.deinit();
    testing.expect((try a.to(i32)) == -5 >> 10);
}

test "big.int shift-left negative" {
    var a = try Int.init(testing.allocator);
    defer a.deinit();

    try a.shiftRight(try Int.initSet(testing.allocator, -10), 1232);
    defer a.deinit();
    testing.expect((try a.to(i32)) == -10 >> 1232);
}

test "big.int bitwise and simple" {
    var a = try Int.initSet(testing.allocator, 0xffffffff11111111);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitAnd(a, b);

    testing.expect((try a.to(u64)) == 0xeeeeeeee00000000);
}

test "big.int bitwise and multi-limb" {
    var a = try Int.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, maxInt(Limb));
    defer b.deinit();

    try a.bitAnd(a, b);

    testing.expect((try a.to(u128)) == 0);
}

test "big.int bitwise xor simple" {
    var a = try Int.initSet(testing.allocator, 0xffffffff11111111);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitXor(a, b);

    testing.expect((try a.to(u64)) == 0x1111111133333333);
}

test "big.int bitwise xor multi-limb" {
    var a = try Int.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, maxInt(Limb));
    defer b.deinit();

    try a.bitXor(a, b);

    testing.expect((try a.to(DoubleLimb)) == (maxInt(Limb) + 1) ^ maxInt(Limb));
}

test "big.int bitwise or simple" {
    var a = try Int.initSet(testing.allocator, 0xffffffff11111111);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, 0xeeeeeeee22222222);
    defer b.deinit();

    try a.bitOr(a, b);

    testing.expect((try a.to(u64)) == 0xffffffff33333333);
}

test "big.int bitwise or multi-limb" {
    var a = try Int.initSet(testing.allocator, maxInt(Limb) + 1);
    defer a.deinit();
    var b = try Int.initSet(testing.allocator, maxInt(Limb));
    defer b.deinit();

    try a.bitOr(a, b);

    // TODO: big.int.cpp or is wrong on multi-limb.
    testing.expect((try a.to(DoubleLimb)) == (maxInt(Limb) + 1) + maxInt(Limb));
}

test "big.int var args" {
    var a = try Int.initSet(testing.allocator, 5);
    defer a.deinit();

    const b = try Int.initSet(testing.allocator, 6);
    defer b.deinit();
    try a.add(a, b);
    testing.expect((try a.to(u64)) == 11);

    const c = try Int.initSet(testing.allocator, 11);
    defer c.deinit();
    testing.expect(a.cmp(c) == 0);

    const d = try Int.initSet(testing.allocator, 14);
    defer d.deinit();
    testing.expect(a.cmp(d) <= 0);
}
