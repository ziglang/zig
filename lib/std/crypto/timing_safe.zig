//! Please see this accepted proposal for the long-term plans regarding
//! constant-time operations in Zig: https://github.com/ziglang/zig/issues/1776

const std = @import("../std.zig");
const assert = std.debug.assert;
const Endian = std.builtin.Endian;
const Order = std.math.Order;

/// Compares two arrays in constant time (for a given length) and returns whether they are equal.
/// This function was designed to compare short cryptographic secrets (MACs, signatures).
/// For all other applications, use mem.eql() instead.
pub fn eql(comptime T: type, a: T, b: T) bool {
    switch (@typeInfo(T)) {
        .array => |info| {
            const C = info.child;
            if (@typeInfo(C) != .int) {
                @compileError("Elements to be compared must be integers");
            }
            var acc = @as(C, 0);
            for (a, 0..) |x, i| {
                acc |= x ^ b[i];
            }
            const s = @typeInfo(C).int.bits;
            const Cu = std.meta.Int(.unsigned, s);
            const Cext = std.meta.Int(.unsigned, s + 1);
            return @as(bool, @bitCast(@as(u1, @truncate((@as(Cext, @as(Cu, @bitCast(acc))) -% 1) >> s))));
        },
        .vector => |info| {
            const C = info.child;
            if (@typeInfo(C) != .int) {
                @compileError("Elements to be compared must be integers");
            }
            const acc = @reduce(.Or, a ^ b);
            const s = @typeInfo(C).int.bits;
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
pub fn compare(comptime T: type, a: []const T, b: []const T, endian: Endian) Order {
    assert(a.len == b.len);
    const bits = switch (@typeInfo(T)) {
        .int => |cinfo| if (cinfo.signedness != .unsigned) @compileError("Elements to be compared must be unsigned") else cinfo.bits,
        else => @compileError("Elements to be compared must be integers"),
    };
    const Cext = std.meta.Int(.unsigned, bits + 1);
    var gt: T = 0;
    var eq: T = 1;
    if (endian == .little) {
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
pub fn add(comptime T: type, a: []const T, b: []const T, result: []T, endian: Endian) bool {
    const len = a.len;
    assert(len == b.len and len == result.len);
    var carry: u1 = 0;
    if (endian == .little) {
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
pub fn sub(comptime T: type, a: []const T, b: []const T, result: []T, endian: Endian) bool {
    const len = a.len;
    assert(len == b.len and len == result.len);
    var borrow: u1 = 0;
    if (endian == .little) {
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

fn markSecret(ptr: anytype, comptime action: enum { classify, declassify }) void {
    const t = @typeInfo(@TypeOf(ptr));
    if (t != .pointer) @compileError("Pointer expected - Found: " ++ @typeName(@TypeOf(ptr)));
    const p = t.pointer;
    if (p.is_allowzero) @compileError("A nullable pointer is always assumed to leak information via side channels");
    const child = @typeInfo(p.child);

    switch (child) {
        .void, .null, .comptime_int, .comptime_float => return,
        .pointer => {
            if (child.pointer.size == .Slice) {
                @compileError("Found pointer to pointer. If the intent was to pass a slice, maybe remove the leading & in the function call");
            }
            @compileError("A pointer value is always assumed leak information via side channels");
        },
        else => {
            const mem8: *const [@sizeOf(@TypeOf(ptr.*))]u8 = @constCast(@ptrCast(ptr));
            if (action == .classify) {
                std.valgrind.memcheck.makeMemUndefined(mem8);
            } else {
                std.valgrind.memcheck.makeMemDefined(mem8);
            }
        },
    }
}

/// Mark a value as sensitive or secret, helping to detect potential side-channel vulnerabilities.
///
/// When Valgrind is enabled, this function allows for the detection of conditional jumps or lookups
/// that depend on secrets or secret-derived data. Violations are reported by Valgrind as operations
/// relying on uninitialized values.
///
/// If Valgrind is disabled, it has no effect.
///
/// Use this function to verify that cryptographic operations perform constant-time arithmetic on sensitive data,
/// ensuring the confidentiality of secrets and preventing information leakage through side channels.
pub fn classify(ptr: anytype) void {
    markSecret(ptr, .classify);
}

/// Mark a value as non-sensitive or public, indicating it's safe from side-channel attacks.
///
/// Signals that a value has been securely processed and is no longer confidential, allowing for
/// relaxed handling without fear of information leakage through conditional jumps or lookups.
pub fn declassify(ptr: anytype) void {
    markSecret(ptr, .declassify);
}

test eql {
    const random = std.crypto.random;
    const expect = std.testing.expect;
    var a: [100]u8 = undefined;
    var b: [100]u8 = undefined;
    random.bytes(a[0..]);
    random.bytes(b[0..]);
    try expect(!eql([100]u8, a, b));
    a = b;
    try expect(eql([100]u8, a, b));
}

test "eql (vectors)" {
    if (@import("builtin").zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const random = std.crypto.random;
    const expect = std.testing.expect;
    var a: [100]u8 = undefined;
    var b: [100]u8 = undefined;
    random.bytes(a[0..]);
    random.bytes(b[0..]);
    const v1: @Vector(100, u8) = a;
    const v2: @Vector(100, u8) = b;
    try expect(!eql(@Vector(100, u8), v1, v2));
    const v3: @Vector(100, u8) = a;
    try expect(eql(@Vector(100, u8), v1, v3));
}

test compare {
    const expectEqual = std.testing.expectEqual;
    var a = [_]u8{10} ** 32;
    var b = [_]u8{10} ** 32;
    try expectEqual(compare(u8, &a, &b, .big), .eq);
    try expectEqual(compare(u8, &a, &b, .little), .eq);
    a[31] = 1;
    try expectEqual(compare(u8, &a, &b, .big), .lt);
    try expectEqual(compare(u8, &a, &b, .little), .lt);
    a[0] = 20;
    try expectEqual(compare(u8, &a, &b, .big), .gt);
    try expectEqual(compare(u8, &a, &b, .little), .lt);
}

test "add and sub" {
    const expectEqual = std.testing.expectEqual;
    const expectEqualSlices = std.testing.expectEqualSlices;
    const random = std.crypto.random;
    const len = 32;
    var a: [len]u8 = undefined;
    var b: [len]u8 = undefined;
    var c: [len]u8 = undefined;
    const zero = [_]u8{0} ** len;
    var iterations: usize = 100;
    while (iterations != 0) : (iterations -= 1) {
        random.bytes(&a);
        random.bytes(&b);
        const endian = if (iterations % 2 == 0) Endian.big else Endian.little;
        _ = sub(u8, &a, &b, &c, endian); // a-b
        _ = add(u8, &c, &b, &c, endian); // (a-b)+b
        try expectEqualSlices(u8, &c, &a);
        const borrow = sub(u8, &c, &a, &c, endian); // ((a-b)+b)-a
        try expectEqualSlices(u8, &c, &zero);
        try expectEqual(borrow, false);
    }
}

test classify {
    const random = std.crypto.random;
    const expect = std.testing.expect;

    var secret: [32]u8 = undefined;
    random.bytes(&secret);

    // Input of the hash function is marked as secret
    classify(&secret);

    var out: [32]u8 = undefined;
    std.crypto.hash.sha3.TurboShake128(null).hash(&secret, &out, .{});

    // Output of the hash function is derived from secret data, so
    // it will automatically be considered secret as well. But it can be
    // declassified; the input itself will still be considered secret.
    declassify(&out);

    // Comparing public data in non-constant time is acceptable.
    try expect(!std.mem.eql(u8, &out, &[_]u8{0} ** out.len));

    // Comparing secret data must be done in constant time. The result
    // is going to be considered as secret as well.
    var res = std.crypto.utils.timingSafeEql([32]u8, out, secret);

    // If we want to make a conditional jump based on a secret,
    // it has to be declassified.
    declassify(&res);
    try expect(!res);

    // Once a secret has been declassified, a comparison in
    // non-constant time is fine.
    declassify(&secret);
    try expect(!std.mem.eql(u8, &out, &secret));
}
