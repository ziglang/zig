const std = @import("../std.zig");
const math = std.math;
const assert = std.debug.assert;
const expect = std.testing.expect;

/// Returns the next representable value after `x` in the direction of `y`.
///
/// Special cases:
///
/// - If `x == y`, `y` is returned.
/// - For floats, if either `x` or `y` is a NaN, a NaN is returned.
/// - For floats, if `x == 0.0` and `@abs(y) > 0.0`, the smallest subnormal number with the sign of
///   `y` is returned.
///
pub fn nextAfter(comptime T: type, x: T, y: T) T {
    return switch (@typeInfo(T)) {
        .int, .comptime_int => nextAfterInt(T, x, y),
        .float => nextAfterFloat(T, x, y),
        else => @compileError("expected int or non-comptime float, found '" ++ @typeName(T) ++ "'"),
    };
}

fn nextAfterInt(comptime T: type, x: T, y: T) T {
    comptime assert(@typeInfo(T) == .int or @typeInfo(T) == .comptime_int);
    return if (@typeInfo(T) == .int and @bitSizeOf(T) < 2)
        // Special case for `i0`, `u0`, `i1`, and `u1`.
        y
    else if (y > x)
        x + 1
    else if (y < x)
        x - 1
    else
        y;
}

// Based on nextafterf/nextafterl from mingw-w64 which are both public domain.
// <https://github.com/mingw-w64/mingw-w64/blob/e89de847dd3e05bb8e46344378ce3e124f4e7d1c/mingw-w64-crt/math/nextafterf.c>
// <https://github.com/mingw-w64/mingw-w64/blob/e89de847dd3e05bb8e46344378ce3e124f4e7d1c/mingw-w64-crt/math/nextafterl.c>

fn nextAfterFloat(comptime T: type, x: T, y: T) T {
    comptime assert(@typeInfo(T) == .float);
    if (x == y) {
        // Returning `y` ensures that (0.0, -0.0) returns -0.0 and that (-0.0, 0.0) returns 0.0.
        return y;
    }
    if (math.isNan(x) or math.isNan(y)) {
        return math.nan(T);
    }
    if (x == 0.0) {
        return if (y > 0.0)
            math.floatTrueMin(T)
        else
            -math.floatTrueMin(T);
    }
    if (@bitSizeOf(T) == 80) {
        // Unlike other floats, `f80` has an explicitly stored integer bit between the fractional
        // part and the exponent and thus requires special handling. This integer bit *must* be set
        // when the value is normal, an infinity or a NaN and *should* be cleared otherwise.

        const fractional_bits_mask = (1 << math.floatFractionalBits(f80)) - 1;
        const integer_bit_mask = 1 << math.floatFractionalBits(f80);
        const exponent_bits_mask = (1 << math.floatExponentBits(f80)) - 1;

        var x_parts = math.F80.fromFloat(x);

        // Bitwise increment/decrement the fractional part while also taking care to update the
        // exponent if we overflow the fractional part. This might flip the integer bit; this is
        // intentional.
        if ((x > 0.0) == (y > x)) {
            x_parts.fraction +%= 1;
            if (x_parts.fraction & fractional_bits_mask == 0) {
                x_parts.exp += 1;
            }
        } else {
            if (x_parts.fraction & fractional_bits_mask == 0) {
                x_parts.exp -= 1;
            }
            x_parts.fraction -%= 1;
        }

        // If the new value is normal or an infinity (indicated by at least one bit in the exponent
        // being set), the integer bit might have been cleared from an overflow, so we must ensure
        // that it remains set.
        if (x_parts.exp & exponent_bits_mask != 0) {
            x_parts.fraction |= integer_bit_mask;
        }
        // Otherwise, the new value is subnormal and the integer bit will have either flipped from
        // set to cleared (if the old value was normal) or remained cleared (if the old value was
        // subnormal), both of which are the outcomes we want.

        return x_parts.toFloat();
    } else {
        const Bits = std.meta.Int(.unsigned, @bitSizeOf(T));
        var x_bits: Bits = @bitCast(x);
        if ((x > 0.0) == (y > x)) {
            x_bits += 1;
        } else {
            x_bits -= 1;
        }
        return @bitCast(x_bits);
    }
}

test "int" {
    try expect(nextAfter(i0, 0, 0) == 0);
    try expect(nextAfter(u0, 0, 0) == 0);
    try expect(nextAfter(i1, 0, 0) == 0);
    try expect(nextAfter(i1, 0, -1) == -1);
    try expect(nextAfter(i1, -1, -1) == -1);
    try expect(nextAfter(i1, -1, 0) == 0);
    try expect(nextAfter(u1, 0, 0) == 0);
    try expect(nextAfter(u1, 0, 1) == 1);
    try expect(nextAfter(u1, 1, 1) == 1);
    try expect(nextAfter(u1, 1, 0) == 0);
    inline for (.{ i8, i16, i32, i64, i128, i333 }) |T| {
        try expect(nextAfter(T, 3, 7) == 4);
        try expect(nextAfter(T, 3, -7) == 2);
        try expect(nextAfter(T, -3, -7) == -4);
        try expect(nextAfter(T, -3, 7) == -2);
        try expect(nextAfter(T, 5, 5) == 5);
        try expect(nextAfter(T, -5, -5) == -5);
        try expect(nextAfter(T, 0, 0) == 0);
        try expect(nextAfter(T, math.minInt(T), math.minInt(T)) == math.minInt(T));
        try expect(nextAfter(T, math.maxInt(T), math.maxInt(T)) == math.maxInt(T));
    }
    inline for (.{ u8, u16, u32, u64, u128, u333 }) |T| {
        try expect(nextAfter(T, 3, 7) == 4);
        try expect(nextAfter(T, 7, 3) == 6);
        try expect(nextAfter(T, 5, 5) == 5);
        try expect(nextAfter(T, 0, 0) == 0);
        try expect(nextAfter(T, math.minInt(T), math.minInt(T)) == math.minInt(T));
        try expect(nextAfter(T, math.maxInt(T), math.maxInt(T)) == math.maxInt(T));
    }
    comptime {
        try expect(nextAfter(comptime_int, 3, 7) == 4);
        try expect(nextAfter(comptime_int, 3, -7) == 2);
        try expect(nextAfter(comptime_int, -3, -7) == -4);
        try expect(nextAfter(comptime_int, -3, 7) == -2);
        try expect(nextAfter(comptime_int, 5, 5) == 5);
        try expect(nextAfter(comptime_int, -5, -5) == -5);
        try expect(nextAfter(comptime_int, 0, 0) == 0);
        try expect(nextAfter(comptime_int, math.maxInt(u512), math.maxInt(u512)) == math.maxInt(u512));
    }
}

test "float" {
    @setEvalBranchQuota(4000);

    // normal -> normal
    try expect(nextAfter(f16, 0x1.234p0, 2.0) == 0x1.238p0);
    try expect(nextAfter(f16, 0x1.234p0, -2.0) == 0x1.230p0);
    try expect(nextAfter(f16, 0x1.234p0, 0x1.234p0) == 0x1.234p0);
    try expect(nextAfter(f16, -0x1.234p0, -2.0) == -0x1.238p0);
    try expect(nextAfter(f16, -0x1.234p0, 2.0) == -0x1.230p0);
    try expect(nextAfter(f16, -0x1.234p0, -0x1.234p0) == -0x1.234p0);
    try expect(nextAfter(f32, 0x1.001234p0, 2.0) == 0x1.001236p0);
    try expect(nextAfter(f32, 0x1.001234p0, -2.0) == 0x1.001232p0);
    try expect(nextAfter(f32, 0x1.001234p0, 0x1.001234p0) == 0x1.001234p0);
    try expect(nextAfter(f32, -0x1.001234p0, -2.0) == -0x1.001236p0);
    try expect(nextAfter(f32, -0x1.001234p0, 2.0) == -0x1.001232p0);
    try expect(nextAfter(f32, -0x1.001234p0, -0x1.001234p0) == -0x1.001234p0);
    inline for (.{f64} ++ if (@bitSizeOf(c_longdouble) == 64) .{c_longdouble} else .{}) |T64| {
        try expect(nextAfter(T64, 0x1.0000000001234p0, 2.0) == 0x1.0000000001235p0);
        try expect(nextAfter(T64, 0x1.0000000001234p0, -2.0) == 0x1.0000000001233p0);
        try expect(nextAfter(T64, 0x1.0000000001234p0, 0x1.0000000001234p0) == 0x1.0000000001234p0);
        try expect(nextAfter(T64, -0x1.0000000001234p0, -2.0) == -0x1.0000000001235p0);
        try expect(nextAfter(T64, -0x1.0000000001234p0, 2.0) == -0x1.0000000001233p0);
        try expect(nextAfter(T64, -0x1.0000000001234p0, -0x1.0000000001234p0) == -0x1.0000000001234p0);
    }
    inline for (.{f80} ++ if (@bitSizeOf(c_longdouble) == 80) .{c_longdouble} else .{}) |T80| {
        try expect(nextAfter(T80, 0x1.0000000000001234p0, 2.0) == 0x1.0000000000001236p0);
        try expect(nextAfter(T80, 0x1.0000000000001234p0, -2.0) == 0x1.0000000000001232p0);
        try expect(nextAfter(T80, 0x1.0000000000001234p0, 0x1.0000000000001234p0) == 0x1.0000000000001234p0);
        try expect(nextAfter(T80, -0x1.0000000000001234p0, -2.0) == -0x1.0000000000001236p0);
        try expect(nextAfter(T80, -0x1.0000000000001234p0, 2.0) == -0x1.0000000000001232p0);
        try expect(nextAfter(T80, -0x1.0000000000001234p0, -0x1.0000000000001234p0) == -0x1.0000000000001234p0);
    }
    inline for (.{f128} ++ if (@bitSizeOf(c_longdouble) == 128) .{c_longdouble} else .{}) |T128| {
        try expect(nextAfter(T128, 0x1.0000000000000000000000001234p0, 2.0) == 0x1.0000000000000000000000001235p0);
        try expect(nextAfter(T128, 0x1.0000000000000000000000001234p0, -2.0) == 0x1.0000000000000000000000001233p0);
        try expect(nextAfter(T128, 0x1.0000000000000000000000001234p0, 0x1.0000000000000000000000001234p0) == 0x1.0000000000000000000000001234p0);
        try expect(nextAfter(T128, -0x1.0000000000000000000000001234p0, -2.0) == -0x1.0000000000000000000000001235p0);
        try expect(nextAfter(T128, -0x1.0000000000000000000000001234p0, 2.0) == -0x1.0000000000000000000000001233p0);
        try expect(nextAfter(T128, -0x1.0000000000000000000000001234p0, -0x1.0000000000000000000000001234p0) == -0x1.0000000000000000000000001234p0);
    }

    // subnormal -> subnormal
    try expect(nextAfter(f16, 0x0.234p-14, 1.0) == 0x0.238p-14);
    try expect(nextAfter(f16, 0x0.234p-14, -1.0) == 0x0.230p-14);
    try expect(nextAfter(f16, 0x0.234p-14, 0x0.234p-14) == 0x0.234p-14);
    try expect(nextAfter(f16, -0x0.234p-14, -1.0) == -0x0.238p-14);
    try expect(nextAfter(f16, -0x0.234p-14, 1.0) == -0x0.230p-14);
    try expect(nextAfter(f16, -0x0.234p-14, -0x0.234p-14) == -0x0.234p-14);
    try expect(nextAfter(f32, 0x0.001234p-126, 1.0) == 0x0.001236p-126);
    try expect(nextAfter(f32, 0x0.001234p-126, -1.0) == 0x0.001232p-126);
    try expect(nextAfter(f32, 0x0.001234p-126, 0x0.001234p-126) == 0x0.001234p-126);
    try expect(nextAfter(f32, -0x0.001234p-126, -1.0) == -0x0.001236p-126);
    try expect(nextAfter(f32, -0x0.001234p-126, 1.0) == -0x0.001232p-126);
    try expect(nextAfter(f32, -0x0.001234p-126, -0x0.001234p-126) == -0x0.001234p-126);
    inline for (.{f64} ++ if (@bitSizeOf(c_longdouble) == 64) .{c_longdouble} else .{}) |T64| {
        try expect(nextAfter(T64, 0x0.0000000001234p-1022, 1.0) == 0x0.0000000001235p-1022);
        try expect(nextAfter(T64, 0x0.0000000001234p-1022, -1.0) == 0x0.0000000001233p-1022);
        try expect(nextAfter(T64, 0x0.0000000001234p-1022, 0x0.0000000001234p-1022) == 0x0.0000000001234p-1022);
        try expect(nextAfter(T64, -0x0.0000000001234p-1022, -1.0) == -0x0.0000000001235p-1022);
        try expect(nextAfter(T64, -0x0.0000000001234p-1022, 1.0) == -0x0.0000000001233p-1022);
        try expect(nextAfter(T64, -0x0.0000000001234p-1022, -0x0.0000000001234p-1022) == -0x0.0000000001234p-1022);
    }
    inline for (.{f80} ++ if (@bitSizeOf(c_longdouble) == 80) .{c_longdouble} else .{}) |T80| {
        try expect(nextAfter(T80, 0x0.0000000000001234p-16382, 1.0) == 0x0.0000000000001236p-16382);
        try expect(nextAfter(T80, 0x0.0000000000001234p-16382, -1.0) == 0x0.0000000000001232p-16382);
        try expect(nextAfter(T80, 0x0.0000000000001234p-16382, 0x0.0000000000001234p-16382) == 0x0.0000000000001234p-16382);
        try expect(nextAfter(T80, -0x0.0000000000001234p-16382, -1.0) == -0x0.0000000000001236p-16382);
        try expect(nextAfter(T80, -0x0.0000000000001234p-16382, 1.0) == -0x0.0000000000001232p-16382);
        try expect(nextAfter(T80, -0x0.0000000000001234p-16382, -0x0.0000000000001234p-16382) == -0x0.0000000000001234p-16382);
    }
    inline for (.{f128} ++ if (@bitSizeOf(c_longdouble) == 128) .{c_longdouble} else .{}) |T128| {
        try expect(nextAfter(T128, 0x0.0000000000000000000000001234p-16382, 1.0) == 0x0.0000000000000000000000001235p-16382);
        try expect(nextAfter(T128, 0x0.0000000000000000000000001234p-16382, -1.0) == 0x0.0000000000000000000000001233p-16382);
        try expect(nextAfter(T128, 0x0.0000000000000000000000001234p-16382, 0x0.0000000000000000000000001234p-16382) == 0x0.0000000000000000000000001234p-16382);
        try expect(nextAfter(T128, -0x0.0000000000000000000000001234p-16382, -1.0) == -0x0.0000000000000000000000001235p-16382);
        try expect(nextAfter(T128, -0x0.0000000000000000000000001234p-16382, 1.0) == -0x0.0000000000000000000000001233p-16382);
        try expect(nextAfter(T128, -0x0.0000000000000000000000001234p-16382, -0x0.0000000000000000000000001234p-16382) == -0x0.0000000000000000000000001234p-16382);
    }

    // normal -> normal (change in exponent)
    try expect(nextAfter(f16, 0x1.FFCp3, math.inf(f16)) == 0x1p4);
    try expect(nextAfter(f16, 0x1p4, -math.inf(f16)) == 0x1.FFCp3);
    try expect(nextAfter(f16, -0x1.FFCp3, -math.inf(f16)) == -0x1p4);
    try expect(nextAfter(f16, -0x1p4, math.inf(f16)) == -0x1.FFCp3);
    try expect(nextAfter(f32, 0x1.FFFFFEp3, math.inf(f32)) == 0x1p4);
    try expect(nextAfter(f32, 0x1p4, -math.inf(f32)) == 0x1.FFFFFEp3);
    try expect(nextAfter(f32, -0x1.FFFFFEp3, -math.inf(f32)) == -0x1p4);
    try expect(nextAfter(f32, -0x1p4, math.inf(f32)) == -0x1.FFFFFEp3);
    inline for (.{f64} ++ if (@bitSizeOf(c_longdouble) == 64) .{c_longdouble} else .{}) |T64| {
        try expect(nextAfter(T64, 0x1.FFFFFFFFFFFFFp3, math.inf(T64)) == 0x1p4);
        try expect(nextAfter(T64, 0x1p4, -math.inf(T64)) == 0x1.FFFFFFFFFFFFFp3);
        try expect(nextAfter(T64, -0x1.FFFFFFFFFFFFFp3, -math.inf(T64)) == -0x1p4);
        try expect(nextAfter(T64, -0x1p4, math.inf(T64)) == -0x1.FFFFFFFFFFFFFp3);
    }
    inline for (.{f80} ++ if (@bitSizeOf(c_longdouble) == 80) .{c_longdouble} else .{}) |T80| {
        try expect(nextAfter(T80, 0x1.FFFFFFFFFFFFFFFEp3, math.inf(T80)) == 0x1p4);
        try expect(nextAfter(T80, 0x1p4, -math.inf(T80)) == 0x1.FFFFFFFFFFFFFFFEp3);
        try expect(nextAfter(T80, -0x1.FFFFFFFFFFFFFFFEp3, -math.inf(T80)) == -0x1p4);
        try expect(nextAfter(T80, -0x1p4, math.inf(T80)) == -0x1.FFFFFFFFFFFFFFFEp3);
    }
    inline for (.{f128} ++ if (@bitSizeOf(c_longdouble) == 128) .{c_longdouble} else .{}) |T128| {
        try expect(nextAfter(T128, 0x1.FFFFFFFFFFFFFFFFFFFFFFFFFFFFp3, math.inf(T128)) == 0x1p4);
        try expect(nextAfter(T128, 0x1p4, -math.inf(T128)) == 0x1.FFFFFFFFFFFFFFFFFFFFFFFFFFFFp3);
        try expect(nextAfter(T128, -0x1.FFFFFFFFFFFFFFFFFFFFFFFFFFFFp3, -math.inf(T128)) == -0x1p4);
        try expect(nextAfter(T128, -0x1p4, math.inf(T128)) == -0x1.FFFFFFFFFFFFFFFFFFFFFFFFFFFFp3);
    }

    // normal -> subnormal
    try expect(nextAfter(f16, 0x1p-14, -math.inf(f16)) == 0x0.FFCp-14);
    try expect(nextAfter(f16, -0x1p-14, math.inf(f16)) == -0x0.FFCp-14);
    try expect(nextAfter(f32, 0x1p-126, -math.inf(f32)) == 0x0.FFFFFEp-126);
    try expect(nextAfter(f32, -0x1p-126, math.inf(f32)) == -0x0.FFFFFEp-126);
    inline for (.{f64} ++ if (@bitSizeOf(c_longdouble) == 64) .{c_longdouble} else .{}) |T64| {
        try expect(nextAfter(T64, 0x1p-1022, -math.inf(T64)) == 0x0.FFFFFFFFFFFFFp-1022);
        try expect(nextAfter(T64, -0x1p-1022, math.inf(T64)) == -0x0.FFFFFFFFFFFFFp-1022);
    }
    inline for (.{f80} ++ if (@bitSizeOf(c_longdouble) == 80) .{c_longdouble} else .{}) |T80| {
        try expect(nextAfter(T80, 0x1p-16382, -math.inf(T80)) == 0x0.FFFFFFFFFFFFFFFEp-16382);
        try expect(nextAfter(T80, -0x1p-16382, math.inf(T80)) == -0x0.FFFFFFFFFFFFFFFEp-16382);
    }
    inline for (.{f128} ++ if (@bitSizeOf(c_longdouble) == 128) .{c_longdouble} else .{}) |T128| {
        try expect(nextAfter(T128, 0x1p-16382, -math.inf(T128)) == 0x0.FFFFFFFFFFFFFFFFFFFFFFFFFFFFp-16382);
        try expect(nextAfter(T128, -0x1p-16382, math.inf(T128)) == -0x0.FFFFFFFFFFFFFFFFFFFFFFFFFFFFp-16382);
    }

    // subnormal -> normal
    try expect(nextAfter(f16, 0x0.FFCp-14, math.inf(f16)) == 0x1p-14);
    try expect(nextAfter(f16, -0x0.FFCp-14, -math.inf(f16)) == -0x1p-14);
    try expect(nextAfter(f32, 0x0.FFFFFEp-126, math.inf(f32)) == 0x1p-126);
    try expect(nextAfter(f32, -0x0.FFFFFEp-126, -math.inf(f32)) == -0x1p-126);
    inline for (.{f64} ++ if (@bitSizeOf(c_longdouble) == 64) .{c_longdouble} else .{}) |T64| {
        try expect(nextAfter(T64, 0x0.FFFFFFFFFFFFFp-1022, math.inf(T64)) == 0x1p-1022);
        try expect(nextAfter(T64, -0x0.FFFFFFFFFFFFFp-1022, -math.inf(T64)) == -0x1p-1022);
    }
    inline for (.{f80} ++ if (@bitSizeOf(c_longdouble) == 80) .{c_longdouble} else .{}) |T80| {
        try expect(nextAfter(T80, 0x0.FFFFFFFFFFFFFFFEp-16382, math.inf(T80)) == 0x1p-16382);
        try expect(nextAfter(T80, -0x0.FFFFFFFFFFFFFFFEp-16382, -math.inf(T80)) == -0x1p-16382);
    }
    inline for (.{f128} ++ if (@bitSizeOf(c_longdouble) == 128) .{c_longdouble} else .{}) |T128| {
        try expect(nextAfter(T128, 0x0.FFFFFFFFFFFFFFFFFFFFFFFFFFFFp-16382, math.inf(T128)) == 0x1p-16382);
        try expect(nextAfter(T128, -0x0.FFFFFFFFFFFFFFFFFFFFFFFFFFFFp-16382, -math.inf(T128)) == -0x1p-16382);
    }

    // special values
    inline for (.{ f16, f32, f64, f80, f128, c_longdouble }) |T| {
        try expect(bitwiseEqual(T, nextAfter(T, 0.0, 0.0), 0.0));
        try expect(bitwiseEqual(T, nextAfter(T, 0.0, -0.0), -0.0));
        try expect(bitwiseEqual(T, nextAfter(T, -0.0, -0.0), -0.0));
        try expect(bitwiseEqual(T, nextAfter(T, -0.0, 0.0), 0.0));
        try expect(nextAfter(T, 0.0, math.inf(T)) == math.floatTrueMin(T));
        try expect(nextAfter(T, 0.0, -math.inf(T)) == -math.floatTrueMin(T));
        try expect(nextAfter(T, -0.0, -math.inf(T)) == -math.floatTrueMin(T));
        try expect(nextAfter(T, -0.0, math.inf(T)) == math.floatTrueMin(T));
        try expect(bitwiseEqual(T, nextAfter(T, math.floatTrueMin(T), 0.0), 0.0));
        try expect(bitwiseEqual(T, nextAfter(T, math.floatTrueMin(T), -0.0), 0.0));
        try expect(bitwiseEqual(T, nextAfter(T, math.floatTrueMin(T), -math.inf(T)), 0.0));
        try expect(bitwiseEqual(T, nextAfter(T, -math.floatTrueMin(T), -0.0), -0.0));
        try expect(bitwiseEqual(T, nextAfter(T, -math.floatTrueMin(T), 0.0), -0.0));
        try expect(bitwiseEqual(T, nextAfter(T, -math.floatTrueMin(T), math.inf(T)), -0.0));
        try expect(nextAfter(T, math.inf(T), math.inf(T)) == math.inf(T));
        try expect(nextAfter(T, math.inf(T), -math.inf(T)) == math.floatMax(T));
        try expect(nextAfter(T, math.floatMax(T), math.inf(T)) == math.inf(T));
        try expect(nextAfter(T, -math.inf(T), -math.inf(T)) == -math.inf(T));
        try expect(nextAfter(T, -math.inf(T), math.inf(T)) == -math.floatMax(T));
        try expect(nextAfter(T, -math.floatMax(T), -math.inf(T)) == -math.inf(T));
        try expect(math.isNan(nextAfter(T, 1.0, math.nan(T))));
        try expect(math.isNan(nextAfter(T, math.nan(T), 1.0)));
        try expect(math.isNan(nextAfter(T, math.nan(T), math.nan(T))));
        try expect(math.isNan(nextAfter(T, math.inf(T), math.nan(T))));
        try expect(math.isNan(nextAfter(T, -math.inf(T), math.nan(T))));
        try expect(math.isNan(nextAfter(T, math.nan(T), math.inf(T))));
        try expect(math.isNan(nextAfter(T, math.nan(T), -math.inf(T))));
    }
}

/// Helps ensure that 0.0 doesn't compare equal to -0.0.
fn bitwiseEqual(comptime T: type, x: T, y: T) bool {
    comptime assert(@typeInfo(T) == .float);
    const Bits = std.meta.Int(.unsigned, @bitSizeOf(T));
    return @as(Bits, @bitCast(x)) == @as(Bits, @bitCast(y));
}
