const std = @import("../std.zig");
const builtin = @import("builtin");
const math = std.math;
const testing = std.testing;
const maxInt = std.math.maxInt;
const assert = std.debug.assert;
const Log2Int = std.math.Log2Int;

/// Returns the base-10 logarithm of x.
///
/// Special Cases:
///  - log10(+inf)  = +inf
///  - log10(0)     = -inf
///  - log10(x)     = nan if x < 0
///  - log10(nan)   = nan
pub fn log10(x: anytype) @TypeOf(x) {
    const T = @TypeOf(x);
    switch (@typeInfo(T)) {
        .ComptimeFloat => {
            return @as(comptime_float, @log10(x));
        },
        .Float => return @log10(x),
        .ComptimeInt => {
            return @as(comptime_int, @floor(@log10(@as(f64, x))));
        },
        .Int => |IntType| switch (IntType.signedness) {
            .signed => @compileError("log10 not implemented for signed integers"),
            .unsigned => return log10_int(x),
        },
        else => @compileError("log10 not implemented for " ++ @typeName(T)),
    }
}

// Based on Rust, which is licensed under the MIT license.
// https://github.com/rust-lang/rust/blob/f63ccaf25f74151a5d8ce057904cd944074b01d2/LICENSE-MIT
//
// https://github.com/rust-lang/rust/blob/f63ccaf25f74151a5d8ce057904cd944074b01d2/library/core/src/num/int_log10.rs

/// Return the log base 10 of integer value x, rounding down to the
/// nearest integer.
pub fn log10_int(x: anytype) Log2Int(@TypeOf(x)) {
    const T = @TypeOf(x);
    const OutT = Log2Int(T);
    if (@typeInfo(T) != .Int or @typeInfo(T).Int.signedness != .unsigned)
        @compileError("log10_int requires an unsigned integer, found " ++ @typeName(T));

    assert(x != 0);

    const bit_size = @typeInfo(T).Int.bits;

    if (bit_size <= 8) {
        return @as(OutT, @intCast(log10_int_u8(x)));
    } else if (bit_size <= 16) {
        return @as(OutT, @intCast(less_than_5(x)));
    }

    var val = x;
    var log: u32 = 0;

    inline for (0..11) |i| {
        // Unnecessary branches should be removed by the compiler
        if (bit_size > (1 << (11 - i)) * 5 * @log2(10.0) and val >= pow10((1 << (11 - i)) * 5)) {
            const num_digits = (1 << (11 - i)) * 5;
            val /= pow10(num_digits);
            log += num_digits;
        }
    }

    if (val >= pow10(5)) {
        val /= pow10(5);
        log += 5;
    }

    return @as(OutT, @intCast(log + less_than_5(@as(u32, @intCast(val)))));
}

fn pow10(comptime y: comptime_int) comptime_int {
    if (y == 0) return 1;

    var squaring = 0;
    var s = 1;

    while (s <= y) : (s <<= 1) {
        squaring += 1;
    }

    squaring -= 1;

    var result = 10;

    for (0..squaring) |_| {
        result *= result;
    }

    const rest_exp = y - (1 << squaring);

    return result * pow10(rest_exp);
}

inline fn log10_int_u8(x: u8) u32 {
    // For better performance, avoid branches by assembling the solution
    // in the bits above the low 8 bits.

    // Adding c1 to val gives 10 in the top bits for val < 10, 11 for val >= 10
    const C1: u32 = 0b11_00000000 - 10; // 758
    // Adding c2 to val gives 01 in the top bits for val < 100, 10 for val >= 100
    const C2: u32 = 0b10_00000000 - 100; // 412

    // Value of top bits:
    //            +c1  +c2  1&2
    //     0..=9   10   01   00 = 0
    //   10..=99   11   01   01 = 1
    // 100..=255   11   10   10 = 2
    return ((x + C1) & (x + C2)) >> 8;
}

inline fn less_than_5(x: u32) u32 {
    // Similar to log10u8, when adding one of these constants to val,
    // we get two possible bit patterns above the low 17 bits,
    // depending on whether val is below or above the threshold.
    const C1: u32 = 0b011_00000000000000000 - 10; // 393206
    const C2: u32 = 0b100_00000000000000000 - 100; // 524188
    const C3: u32 = 0b111_00000000000000000 - 1000; // 916504
    const C4: u32 = 0b100_00000000000000000 - 10000; // 514288

    // Value of top bits:
    //                +c1  +c2  1&2  +c3  +c4  3&4   ^
    //         0..=9  010  011  010  110  011  010  000 = 0
    //       10..=99  011  011  011  110  011  010  001 = 1
    //     100..=999  011  100  000  110  011  010  010 = 2
    //   1000..=9999  011  100  000  111  011  011  011 = 3
    // 10000..=99999  011  100  000  111  100  100  100 = 4
    return (((x + C1) & (x + C2)) ^ ((x + C3) & (x + C4))) >> 17;
}

fn oldlog10(x: anytype) u8 {
    return @as(u8, @intFromFloat(@log10(@as(f64, @floatFromInt(x)))));
}

test "oldlog10 doesn't work" {
    try testing.expect(14 != oldlog10(pow10(15) - 1));

    // log10(10**15 -1) should indeed be 14
    try testing.expect(14 == log10_int(@as(u64, pow10(15) - 1)));
}

test "log10_int vs old implementation" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_llvm and comptime builtin.target.isWasm()) return error.SkipZigTest; // TODO

    const int_types = .{ u8, u16, u32, u64, u128 };

    inline for (int_types) |T| {
        const last = @min(maxInt(T), 100_000);
        for (1..last) |i| {
            const x = @as(T, @intCast(i));
            try testing.expectEqual(oldlog10(x), log10_int(x));
        }

        const max_int: T = maxInt(T);
        try testing.expectEqual(oldlog10(max_int), log10_int(max_int));
    }
}

test "log10_int close to powers of 10" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_llvm and comptime builtin.target.isWasm()) return error.SkipZigTest; // TODO

    const int_types = .{ u8, u16, u32, u64, u128, u256, u512 };
    const max_log_values: [7]usize = .{ 2, 4, 9, 19, 38, 77, 154 };

    inline for (int_types, max_log_values) |T, expected_max_ilog| {
        const max_val: T = maxInt(T);

        try testing.expectEqual(expected_max_ilog, log10_int(max_val));

        for (0..(expected_max_ilog + 1)) |idx| {
            const i = @as(T, @intCast(idx));
            const p: T = try math.powi(T, 10, i);

            const b = @as(Log2Int(T), @intCast(i));

            if (p >= 10) {
                try testing.expectEqual(b - 1, log10_int(p - 9));
                try testing.expectEqual(b - 1, log10_int(p - 1));
            }

            try testing.expectEqual(b, log10_int(p));
            try testing.expectEqual(b, log10_int(p + 1));
            if (p >= 10) {
                try testing.expectEqual(b, log10_int(p + 9));
            }
        }
    }
}
