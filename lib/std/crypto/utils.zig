const std = @import("../std.zig");
const debug = std.debug;
const mem = std.mem;
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
            for (a) |x, i| {
                acc |= x ^ b[i];
            }
            const s = @typeInfo(C).Int.bits;
            const Cu = std.meta.Int(.unsigned, s);
            const Cext = std.meta.Int(.unsigned, s + 1);
            return @bitCast(bool, @truncate(u1, (@as(Cext, @bitCast(Cu, acc)) -% 1) >> s));
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
            return @bitCast(bool, @truncate(u1, (@as(Cext, @bitCast(Cu, acc)) -% 1) >> s));
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
            gt |= @truncate(T, (@as(Cext, x2) -% @as(Cext, x1)) >> bits) & eq;
            eq &= @truncate(T, (@as(Cext, (x2 ^ x1)) -% 1) >> bits);
        }
    } else {
        for (a) |x1, i| {
            const x2 = b[i];
            gt |= @truncate(T, (@as(Cext, x2) -% @as(Cext, x1)) >> bits) & eq;
            eq &= @truncate(T, (@as(Cext, (x2 ^ x1)) -% 1) >> bits);
        }
    }
    if (gt != 0) {
        return Order.gt;
    } else if (eq != 0) {
        return Order.eq;
    }
    return Order.lt;
}

/// Sets a slice to zeroes.
/// Prevents the store from being optimized out.
pub fn secureZero(comptime T: type, s: []T) void {
    // NOTE: We do not use a volatile slice cast here since LLVM cannot
    // see that it can be replaced by a memset.
    const ptr = @ptrCast([*]volatile u8, s.ptr);
    const length = s.len * @sizeOf(T);
    @memset(ptr, 0, length);
}

test "crypto.utils.timingSafeEql" {
    var a: [100]u8 = undefined;
    var b: [100]u8 = undefined;
    std.crypto.random.bytes(a[0..]);
    std.crypto.random.bytes(b[0..]);
    try testing.expect(!timingSafeEql([100]u8, a, b));
    mem.copy(u8, a[0..], b[0..]);
    try testing.expect(timingSafeEql([100]u8, a, b));
}

test "crypto.utils.timingSafeEql (vectors)" {
    var a: [100]u8 = undefined;
    var b: [100]u8 = undefined;
    std.crypto.random.bytes(a[0..]);
    std.crypto.random.bytes(b[0..]);
    const v1: std.meta.Vector(100, u8) = a;
    const v2: std.meta.Vector(100, u8) = b;
    try testing.expect(!timingSafeEql(std.meta.Vector(100, u8), v1, v2));
    const v3: std.meta.Vector(100, u8) = a;
    try testing.expect(timingSafeEql(std.meta.Vector(100, u8), v1, v3));
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

test "crypto.utils.secureZero" {
    var a = [_]u8{0xfe} ** 8;
    var b = [_]u8{0xfe} ** 8;

    mem.set(u8, a[0..], 0);
    secureZero(u8, b[0..]);

    try testing.expectEqualSlices(u8, a[0..], b[0..]);
}
