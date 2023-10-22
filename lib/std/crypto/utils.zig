const std = @import("../std.zig");
const debug = std.debug;
const mem = std.mem;
const random = std.crypto.random;
const testing = std.testing;

const Endian = std.builtin.Endian;
const Order = std.math.Order;

/// Compares two arrays in constant time (for a given length) and returns whether they are equal.
/// This function was designed to compare short cryptographic secrets (MACs, signatures).
/// For all other applications, use mem.eql() instead.
pub fn timingSafeEql(comptime T: type, a: T, b: T) bool {
    switch (@typeInfo(T)) {
        .Array => |info| {
            const C = info.child;
            if (@typeInfo(C) != .Int) {
                @compileError("Elements to be compared must be integers");
            }
            var acc = @as(C, 0);
            for (a, 0..) |x, i| {
                acc |= x ^ b[i];
            }
            const s = @typeInfo(C).Int.bits;
            const Cu = std.meta.Int(.unsigned, s);
            const Cext = std.meta.Int(.unsigned, s + 1);
            return @as(bool, @bitCast(@as(u1, @truncate((@as(Cext, @as(Cu, @bitCast(acc))) -% 1) >> s))));
        },
        .Vector => |info| {
            const C = info.child;
            if (@typeInfo(C) != .Int) {
                @compileError("Elements to be compared must be integers");
            }
            const acc = @reduce(.Or, a ^ b);
            const s = @typeInfo(C).Int.bits;
            const Cu = std.meta.Int(.unsigned, s);
            const Cext = std.meta.Int(.unsigned, s + 1);
            return @as(bool, @bitCast(@as(u1, @truncate((@as(Cext, @as(Cu, @bitCast(acc))) -% 1) >> s))));
        },
        else => {
            @compileError("Only arrays and vectors can be compared");
        },
    }
}

/// Compare two integers serialized as arrays of the same size, in constant time.
/// Returns .lt if a<b, .gt if a>b and .eq if a=b
pub fn timingSafeCompare(comptime T: type, a: []const T, b: []const T, endian: Endian) Order {
    debug.assert(a.len == b.len);
    const bits = switch (@typeInfo(T)) {
        .Int => |cinfo| if (cinfo.signedness != .unsigned) @compileError("Elements to be compared must be unsigned") else cinfo.bits,
        else => @compileError("Elements to be compared must be integers"),
    };
    const Cext = std.meta.Int(.unsigned, bits + 1);
    var gt: T = 0;
    var eq: T = 1;
    if (endian == .Little) {
        var i = a.len;
        while (i != 0) {
            i -= 1;
            const x1 = a[i];
            const x2 = b[i];
            gt |= @as(T, @truncate((@as(Cext, x2) -% @as(Cext, x1)) >> bits)) & eq;
            eq &= @as(T, @truncate((@as(Cext, (x2 ^ x1)) -% 1) >> bits));
        }
    } else {
        for (a, 0..) |x1, i| {
            const x2 = b[i];
            gt |= @as(T, @truncate((@as(Cext, x2) -% @as(Cext, x1)) >> bits)) & eq;
            eq &= @as(T, @truncate((@as(Cext, (x2 ^ x1)) -% 1) >> bits));
        }
    }
    if (gt != 0) {
        return Order.gt;
    } else if (eq != 0) {
        return Order.eq;
    }
    return Order.lt;
}

/// Add two integers serialized as arrays of the same size, in constant time.
/// The result is stored into `result`, and `true` is returned if an overflow occurred.
pub fn timingSafeAdd(comptime T: type, a: []const T, b: []const T, result: []T, endian: Endian) bool {
    const len = a.len;
    debug.assert(len == b.len and len == result.len);
    var carry: u1 = 0;
    if (endian == .Little) {
        var i: usize = 0;
        while (i < len) : (i += 1) {
            const ov1 = @addWithOverflow(a[i], b[i]);
            const ov2 = @addWithOverflow(ov1[0], carry);
            result[i] = ov2[0];
            carry = ov1[1] | ov2[1];
        }
    } else {
        var i: usize = len;
        while (i != 0) {
            i -= 1;
            const ov1 = @addWithOverflow(a[i], b[i]);
            const ov2 = @addWithOverflow(ov1[0], carry);
            result[i] = ov2[0];
            carry = ov1[1] | ov2[1];
        }
    }
    return @as(bool, @bitCast(carry));
}

/// Subtract two integers serialized as arrays of the same size, in constant time.
/// The result is stored into `result`, and `true` is returned if an underflow occurred.
pub fn timingSafeSub(comptime T: type, a: []const T, b: []const T, result: []T, endian: Endian) bool {
    const len = a.len;
    debug.assert(len == b.len and len == result.len);
    var borrow: u1 = 0;
    if (endian == .Little) {
        var i: usize = 0;
        while (i < len) : (i += 1) {
            const ov1 = @subWithOverflow(a[i], b[i]);
            const ov2 = @subWithOverflow(ov1[0], borrow);
            result[i] = ov2[0];
            borrow = ov1[1] | ov2[1];
        }
    } else {
        var i: usize = len;
        while (i != 0) {
            i -= 1;
            const ov1 = @subWithOverflow(a[i], b[i]);
            const ov2 = @subWithOverflow(ov1[0], borrow);
            result[i] = ov2[0];
            borrow = ov1[1] | ov2[1];
        }
    }
    return @as(bool, @bitCast(borrow));
}

/// Sets a slice to zeroes.
/// Prevents the store from being optimized out.
pub inline fn secureZero(comptime T: type, s: []T) void {
    @memset(@as([]volatile T, s), 0);
}

test "crypto.utils.timingSafeEql" {
    var a: [100]u8 = undefined;
    var b: [100]u8 = undefined;
    random.bytes(a[0..]);
    random.bytes(b[0..]);
    try testing.expect(!timingSafeEql([100]u8, a, b));
    a = b;
    try testing.expect(timingSafeEql([100]u8, a, b));
}

test "crypto.utils.timingSafeEql (vectors)" {
    var a: [100]u8 = undefined;
    var b: [100]u8 = undefined;
    random.bytes(a[0..]);
    random.bytes(b[0..]);
    const v1: @Vector(100, u8) = a;
    const v2: @Vector(100, u8) = b;
    try testing.expect(!timingSafeEql(@Vector(100, u8), v1, v2));
    const v3: @Vector(100, u8) = a;
    try testing.expect(timingSafeEql(@Vector(100, u8), v1, v3));
}

test "crypto.utils.timingSafeCompare" {
    var a = [_]u8{10} ** 32;
    var b = [_]u8{10} ** 32;
    try testing.expectEqual(timingSafeCompare(u8, &a, &b, .Big), .eq);
    try testing.expectEqual(timingSafeCompare(u8, &a, &b, .Little), .eq);
    a[31] = 1;
    try testing.expectEqual(timingSafeCompare(u8, &a, &b, .Big), .lt);
    try testing.expectEqual(timingSafeCompare(u8, &a, &b, .Little), .lt);
    a[0] = 20;
    try testing.expectEqual(timingSafeCompare(u8, &a, &b, .Big), .gt);
    try testing.expectEqual(timingSafeCompare(u8, &a, &b, .Little), .lt);
}

test "crypto.utils.timingSafe{Add,Sub}" {
    const len = 32;
    var a: [len]u8 = undefined;
    var b: [len]u8 = undefined;
    var c: [len]u8 = undefined;
    const zero = [_]u8{0} ** len;
    var iterations: usize = 100;
    while (iterations != 0) : (iterations -= 1) {
        random.bytes(&a);
        random.bytes(&b);
        const endian = if (iterations % 2 == 0) Endian.Big else Endian.Little;
        _ = timingSafeSub(u8, &a, &b, &c, endian); // a-b
        _ = timingSafeAdd(u8, &c, &b, &c, endian); // (a-b)+b
        try testing.expectEqualSlices(u8, &c, &a);
        const borrow = timingSafeSub(u8, &c, &a, &c, endian); // ((a-b)+b)-a
        try testing.expectEqualSlices(u8, &c, &zero);
        try testing.expectEqual(borrow, false);
    }
}

test "crypto.utils.secureZero" {
    var a = [_]u8{0xfe} ** 8;
    var b = [_]u8{0xfe} ** 8;

    @memset(a[0..], 0);
    secureZero(u8, b[0..]);

    try testing.expectEqualSlices(u8, a[0..], b[0..]);
}
