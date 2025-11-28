const std = @import("std");
const builtin = @import("builtin");

/// Result of the Extended Euclidean Algorithm containing the GCD and Bézout coefficients.
/// For inputs a and b, returns gcd, x, y such that: a*x + b*y = gcd
pub fn Result(comptime T: type) type {
    const type_info = @typeInfo(T);
    std.debug.assert(type_info.int.bits < 65535); // u65535 and i65535 are not supported (cannot create i65536 for coefficients)

    // Coefficients need to be signed and potentially wider
    // For both signed and unsigned types, we need an extra bit to avoid overflow issues
    const CoeffType = std.meta.Int(.signed, type_info.int.bits + 1);

    return struct {
        gcd: T,
        x: CoeffType,
        y: CoeffType,
    };
}

/// Computes the Extended GCD of two integers.
/// Returns gcd(a, b) and Bézout coefficients x, y such that: a*x + b*y = gcd(a, b)
///
/// Works for all integer types from u0 to u65534 and i0 to i65534.
/// Note: u65535 and i65535 are not supported as we cannot create i65536 for coefficients.
///
/// Properties:
/// - gcd is always non-negative (following standard mathematical convention)
/// - Exceptions: i1 type (can only represent -1, 0) and minInt(T) values that cannot be negated
pub fn egcd(a: anytype, b: anytype) Result(@TypeOf(a, b)) {
    const T = @TypeOf(a, b);
    const type_info = @typeInfo(T);
    std.debug.assert(type_info == .int);

    const CoeffType = @FieldType(Result(@TypeOf(a, b)), "x");

    // Special case for (0, 0): the general algorithm would return (gcd=0, x=1, y=0),
    // but this fails for types like u0/i0 where CoeffType is i1 and cannot represent 1.
    // Returning (0, 0, 0) is mathematically valid since 0*0 + 0*0 = 0.
    if (a == 0 and b == 0) {
        return .{
            .gcd = 0,
            .x = 0,
            .y = 0,
        };
    }

    var r0: CoeffType = a;
    var r1: CoeffType = b;
    var s0: CoeffType = 1;
    var s1: CoeffType = 0;
    var t0: CoeffType = 0;
    var t1: CoeffType = 1;

    while (r1 != 0) {
        const q = @divTrunc(r0, r1);

        const r_temp = r0 - q * r1;
        r0 = r1;
        r1 = r_temp;

        const s_temp = s0 - q * s1;
        s0 = s1;
        s1 = s_temp;

        const t_temp = t0 - q * t1;
        t0 = t1;
        t1 = t_temp;
    }

    // Normalize gcd to be non-negative (standard mathematical convention)
    // For signed types, make the GCD positive when possible
    // Exception: types like i1 that can't represent positive values, or when gcd = minInt(T)
    if (type_info.int.signedness == .signed and r0 < 0) {
        // Can only negate if the type has more than 1 bit and r0 != minInt(T)
        if (type_info.int.bits > 1 and r0 > std.math.minInt(T)) {
            r0 = -r0;
            s0 = -s0;
            t0 = -t0;
        }
    }

    return .{
        .gcd = @intCast(r0),
        .x = s0,
        .y = t0,
    };
}

test "basic unsigned" {
    const result = egcd(@as(u32, 12), @as(u32, 8));
    try std.testing.expectEqual(@as(u32, 4), result.gcd);
    // 12*x + 8*y = 4
    // One valid solution: x = -1, y = 2 -> 12*(-1) + 8*2 = -12 + 16 = 4
    const verification: i33 = @as(i33, 12) * result.x + @as(i33, 8) * result.y;
    try std.testing.expectEqual(@as(i33, 4), verification);
}

test "zero inputs" {
    const result0 = egcd(@as(u32, 0), @as(u32, 0));
    try std.testing.expectEqual(@as(u32, 0), result0.gcd);
    // For (0, 0), we use special handling to return x=0, y=0
    // This satisfies the Bézout identity: 0*0 + 0*0 = 0
    try std.testing.expectEqual(@as(i33, 0), result0.x);
    try std.testing.expectEqual(@as(i33, 0), result0.y);

    const result1 = egcd(@as(u32, 0), @as(u32, 5));
    try std.testing.expectEqual(@as(u32, 5), result1.gcd);
    try std.testing.expectEqual(@as(i33, 0), result1.x);
    try std.testing.expectEqual(@as(i33, 1), result1.y);

    const result2 = egcd(@as(u32, 7), @as(u32, 0));
    try std.testing.expectEqual(@as(u32, 7), result2.gcd);
    try std.testing.expectEqual(@as(i33, 1), result2.x);
    try std.testing.expectEqual(@as(i33, 0), result2.y);
}

test "signed integers" {
    const result = egcd(@as(i32, -12), @as(i32, 8));
    try std.testing.expectEqual(@as(i32, 4), result.gcd);
    const verification: i33 = @as(i33, -12) * result.x + @as(i33, 8) * result.y;
    try std.testing.expectEqual(@as(i33, 4), verification);
}

test "coprime" {
    const result = egcd(@as(u32, 17), @as(u32, 13));
    try std.testing.expectEqual(@as(u32, 1), result.gcd);
    const verification: i33 = @as(i33, 17) * result.x + @as(i33, 13) * result.y;
    try std.testing.expectEqual(@as(i33, 1), verification);
}

test "u0 type" {
    const result = egcd(@as(u0, 0), @as(u0, 0));
    try std.testing.expectEqual(@as(u0, 0), result.gcd);
}

test "i0 type" {
    const result = egcd(@as(i0, 0), @as(i0, 0));
    try std.testing.expectEqual(@as(i0, 0), result.gcd);
}

test "u1 type" {
    // u1 can only be 0 or 1
    const result1 = egcd(@as(u1, 1), @as(u1, 1));
    try std.testing.expectEqual(@as(u1, 1), result1.gcd);
    const verify1: i2 = @as(i2, 1) * result1.x + @as(i2, 1) * result1.y;
    try std.testing.expectEqual(@as(i2, 1), verify1);

    const result2 = egcd(@as(u1, 1), @as(u1, 0));
    try std.testing.expectEqual(@as(u1, 1), result2.gcd);

    const result3 = egcd(@as(u1, 0), @as(u1, 1));
    try std.testing.expectEqual(@as(u1, 1), result3.gcd);
}

test "i1 type" {
    // i1 can only be -1 or 0
    const result1 = egcd(@as(i1, -1), @as(i1, -1));
    try std.testing.expectEqual(@as(i1, -1), result1.gcd);
    const verify1: i2 = @as(i2, -1) * result1.x + @as(i2, -1) * result1.y;
    try std.testing.expectEqual(@as(i2, -1), verify1);

    const result2 = egcd(@as(i1, -1), @as(i1, 0));
    try std.testing.expectEqual(@as(i1, -1), result2.gcd);

    const result3 = egcd(@as(i1, 0), @as(i1, -1));
    try std.testing.expectEqual(@as(i1, -1), result3.gcd);
}

test "u8 small values" {
    const result = egcd(@as(u8, 12), @as(u8, 8));
    try std.testing.expectEqual(@as(u8, 4), result.gcd);
    const verify: i9 = @as(i9, 12) * result.x + @as(i9, 8) * result.y;
    try std.testing.expectEqual(@as(i9, 4), verify);
}

test "u16 medium values" {
    const result = egcd(@as(u16, 1071), @as(u16, 462));
    try std.testing.expectEqual(@as(u16, 21), result.gcd);
    const verify: i17 = @as(i17, 1071) * result.x + @as(i17, 462) * result.y;
    try std.testing.expectEqual(@as(i17, 21), verify);
}

test "u32 large values" {
    const result = egcd(@as(u32, 49865), @as(u32, 69811));
    try std.testing.expectEqual(@as(u32, 9973), result.gcd);
    const verify: i64 = @as(i64, 49865) * @as(i64, result.x) + @as(i64, 69811) * @as(i64, result.y);
    try std.testing.expectEqual(@as(i64, 9973), verify);
}

test "u64 very large values" {
    const result = egcd(@as(u64, 90000000_000_000_000), @as(u64, 30000000_000_000_000));
    try std.testing.expectEqual(@as(u64, 30000000_000_000_000), result.gcd);
    const verify: i128 = @as(i128, 90000000_000_000_000) * @as(i128, result.x) +
        @as(i128, 30000000_000_000_000) * @as(i128, result.y);
    try std.testing.expectEqual(@as(i128, 30000000_000_000_000), verify);
}

test "u128 values" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO: C backend missing big integer helpers
    const a: u128 = 123456789012345678901234567890;
    const b: u128 = 987654321098765432109876543210;
    const result = egcd(a, b);
    // Verify the Bezout identity
    const verify = @as(i129, result.x) * @as(i129, @intCast(a % 1000000)) +
        @as(i129, result.y) * @as(i129, @intCast(b % 1000000));
    const expected = @as(i129, @intCast(result.gcd % 1000000));
    try std.testing.expectEqual(expected, @mod(verify, 1000000));
}

test "i8 negative values" {
    const result1 = egcd(@as(i8, -12), @as(i8, 8));
    try std.testing.expectEqual(@as(i8, 4), result1.gcd);
    const verify1: i9 = @as(i9, -12) * result1.x + @as(i9, 8) * result1.y;
    try std.testing.expectEqual(@as(i9, 4), verify1);

    const result2 = egcd(@as(i8, 12), @as(i8, -8));
    try std.testing.expectEqual(@as(i8, 4), result2.gcd);
    const verify2: i9 = @as(i9, 12) * result2.x + @as(i9, -8) * result2.y;
    try std.testing.expectEqual(@as(i9, 4), verify2);

    const result3 = egcd(@as(i8, -12), @as(i8, -8));
    try std.testing.expectEqual(@as(i8, 4), result3.gcd);
    const verify3: i9 = @as(i9, -12) * result3.x + @as(i9, -8) * result3.y;
    try std.testing.expectEqual(@as(i9, 4), verify3);
}

test "i32 negative values" {
    const result = egcd(@as(i32, -1071), @as(i32, 462));
    try std.testing.expectEqual(@as(i32, 21), result.gcd);
    const verify: i33 = @as(i33, -1071) * result.x + @as(i33, 462) * result.y;
    try std.testing.expectEqual(@as(i33, 21), verify);
}

test "coprime numbers" {
    const result1 = egcd(@as(u32, 17), @as(u32, 19));
    try std.testing.expectEqual(@as(u32, 1), result1.gcd);

    const result2 = egcd(@as(u32, 101), @as(u32, 103));
    try std.testing.expectEqual(@as(u32, 1), result2.gcd);
}

test "powers of 2" {
    const result1 = egcd(@as(u32, 16), @as(u32, 24));
    try std.testing.expectEqual(@as(u32, 8), result1.gcd);

    const result2 = egcd(@as(u32, 64), @as(u32, 96));
    try std.testing.expectEqual(@as(u32, 32), result2.gcd);
}

test "one is 1" {
    const result1 = egcd(@as(u32, 1), @as(u32, 100));
    try std.testing.expectEqual(@as(u32, 1), result1.gcd);
    try std.testing.expectEqual(@as(i33, 1), result1.x);
    try std.testing.expectEqual(@as(i33, 0), result1.y);

    const result2 = egcd(@as(u32, 100), @as(u32, 1));
    try std.testing.expectEqual(@as(u32, 1), result2.gcd);
}

test "same values" {
    const result1 = egcd(@as(u32, 42), @as(u32, 42));
    try std.testing.expectEqual(@as(u32, 42), result1.gcd);

    const result2 = egcd(@as(i32, -42), @as(i32, -42));
    try std.testing.expectEqual(@as(i32, 42), result2.gcd);
}

test "Fibonacci numbers" {
    // Consecutive Fibonacci numbers are coprime
    const result = egcd(@as(u32, 89), @as(u32, 144));
    try std.testing.expectEqual(@as(u32, 1), result.gcd);
    const verify: i33 = @as(i33, 89) * result.x + @as(i33, 144) * result.y;
    try std.testing.expectEqual(@as(i33, 1), verify);
}

test "u3 type" {
    // u3 can hold 0-7
    const result = egcd(@as(u3, 6), @as(u3, 4));
    try std.testing.expectEqual(@as(u3, 2), result.gcd);
    const verify: i4 = @as(i4, 6) * result.x + @as(i4, 4) * result.y;
    try std.testing.expectEqual(@as(i4, 2), verify);
}

test "i3 type" {
    // i3 can hold -4 to 3
    const result = egcd(@as(i3, -3), @as(i3, 2));
    try std.testing.expectEqual(@as(i3, 1), result.gcd);
    const verify: i4 = @as(i4, -3) * result.x + @as(i4, 2) * result.y;
    try std.testing.expectEqual(@as(i4, 1), verify);
}

test "u7 type" {
    // u7 can hold 0-127
    const result = egcd(@as(u7, 120), @as(u7, 45));
    try std.testing.expectEqual(@as(u7, 15), result.gcd);
    const verify: i16 = @as(i16, 120) * result.x + @as(i16, 45) * result.y;
    try std.testing.expectEqual(@as(i16, 15), verify);
}

test "modular inverse use case" {
    // Common use case: finding modular inverse
    // If gcd(a, m) = 1, then x is the modular inverse of a mod m
    const a: u32 = 17;
    const m: u32 = 43;
    const result = egcd(a, m);
    try std.testing.expectEqual(@as(u32, 1), result.gcd);

    // x should be the modular inverse
    const x_mod = @mod(result.x, @as(i33, m));
    const x_unsigned = if (x_mod < 0) x_mod + @as(i33, m) else x_mod;
    const verify = @mod(@as(u64, a) * @as(u64, @intCast(x_unsigned)), m);
    try std.testing.expectEqual(@as(u64, 1), verify);
}
test "u256 type" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO: C backend missing big integer helpers
    const a: u256 = 123456789012345678901234567890123456789012345678901234567890;
    const b: u256 = 987654321098765432109876543210987654321098765432109876543210;
    const result = egcd(a, b);

    const mod = 1000000000;
    const a_mod = @as(i257, @intCast(a % mod));
    const b_mod = @as(i257, @intCast(b % mod));
    const gcd_mod = @as(i257, @intCast(result.gcd % mod));
    const verify = @mod(a_mod * result.x + b_mod * result.y, mod);
    try std.testing.expectEqual(gcd_mod, @mod(verify, mod));
}

test "u512 type" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO: C backend missing big integer helpers
    const a: u512 = 999999999999999999;
    const b: u512 = 888888888888888888;
    const result = egcd(a, b);

    // Full verification for these smaller values
    const verify: i513 = @as(i513, a) * result.x + @as(i513, b) * result.y;
    try std.testing.expectEqual(@as(i513, result.gcd), verify);
}

test "i256 type" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO: C backend missing big integer helpers
    const a: i256 = -123456789012345678901234567890;
    const b: i256 = 987654321098765432109876543210;
    const result = egcd(a, b);

    const mod = 1000000000;
    const a_mod = @as(i257, @intCast(@mod(a, mod)));
    const b_mod = @as(i257, @intCast(@mod(b, mod)));
    const gcd_mod = @as(i257, @intCast(@mod(result.gcd, mod)));
    const verify = @mod(a_mod * result.x + b_mod * result.y, mod);
    try std.testing.expectEqual(@mod(gcd_mod, mod), @mod(verify, mod));
}

test "u1024 type" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO: C backend missing big integer helpers
    // Test that very large types compile and work
    const a: u1024 = 12345678901234567890;
    const b: u1024 = 9876543210987654321;
    const result = egcd(a, b);

    // Verify
    const verify: i1025 = @as(i1025, a) * result.x + @as(i1025, b) * result.y;
    try std.testing.expectEqual(@as(i1025, result.gcd), verify);
}

test "u4096" {
    if (true) return error.SkipZigTest; // Codegen error on some platforms
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO: C backend missing big integer helpers
    const a: u4096 = 100;
    const b: u4096 = 50;
    const result = egcd(a, b);
    try std.testing.expectEqual(@as(u4096, 50), result.gcd);
}

test "Bezout identity for a=0, b<0" {
    // When a=0 and b<0, the GCD is normalized to positive
    const result = egcd(@as(i32, 0), @as(i32, -5));
    try std.testing.expectEqual(@as(i32, 5), result.gcd);
    try std.testing.expectEqual(@as(i33, 0), result.x);
    try std.testing.expectEqual(@as(i33, -1), result.y);

    // Verify Bézout identity: a*x + b*y = gcd
    const left_side: i33 = @as(i33, 0) * result.x + @as(i33, -5) * result.y;
    try std.testing.expectEqual(@as(i33, 5), left_side);
}

test "Bezout identity for a<0, b=0" {
    // Verify the symmetric case: when a<0 and b=0, GCD is normalized to positive
    const result = egcd(@as(i32, -7), @as(i32, 0));
    try std.testing.expectEqual(@as(i32, 7), result.gcd);
    try std.testing.expectEqual(@as(i33, -1), result.x);
    try std.testing.expectEqual(@as(i33, 0), result.y);

    // Verify Bézout identity: a*x + b*y = gcd
    const left_side: i33 = @as(i33, -7) * result.x + @as(i33, 0) * result.y;
    try std.testing.expectEqual(@as(i33, 7), left_side);
}

test "Bezout identity for all zero-argument cases" {
    // Positive b
    {
        const result = egcd(@as(i16, 0), @as(i16, 10));
        try std.testing.expectEqual(@as(i16, 10), result.gcd);
        const verify: i17 = @as(i17, 0) * result.x + @as(i17, 10) * result.y;
        try std.testing.expectEqual(@as(i17, 10), verify);
    }

    // Negative b - GCD normalized to positive
    {
        const result = egcd(@as(i16, 0), @as(i16, -10));
        try std.testing.expectEqual(@as(i16, 10), result.gcd);
        const verify: i17 = @as(i17, 0) * result.x + @as(i17, -10) * result.y;
        try std.testing.expectEqual(@as(i17, 10), verify);
    }

    // Positive a
    {
        const result = egcd(@as(i16, 10), @as(i16, 0));
        try std.testing.expectEqual(@as(i16, 10), result.gcd);
        const verify: i17 = @as(i17, 10) * result.x + @as(i17, 0) * result.y;
        try std.testing.expectEqual(@as(i17, 10), verify);
    }

    // Negative a - GCD normalized to positive
    {
        const result = egcd(@as(i16, -10), @as(i16, 0));
        try std.testing.expectEqual(@as(i16, 10), result.gcd);
        const verify: i17 = @as(i17, -10) * result.x + @as(i17, 0) * result.y;
        try std.testing.expectEqual(@as(i17, 10), verify);
    }
}
