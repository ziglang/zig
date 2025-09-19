const std = @import("std");
const builtin = @import("builtin");

pub const min_length = 3;
pub const max_length = 258;

pub const min_distance = 1;
pub const max_distance = std.compress.flate.history_len;

pub const codegen_order: [19]u8 = .{
    16, 17, 18,
    0, 8, //
    7, 9,
    6, 10,
    5, 11,
    4, 12,
    3, 13,
    2, 14,
    1, 15,
};

pub const fixed_lit_codes = fixed_lit[0];
pub const fixed_lit_bits = fixed_lit[1];
const fixed_lit = blk: {
    var codes: [286]u16 = undefined;
    var bits: [286]u4 = undefined;

    for (0..143 + 1, 0b00110000..0b10111111 + 1) |i, v| {
        codes[i] = @bitReverse(@as(u8, v));
        bits[i] = 8;
    }
    for (144..255 + 1, 0b110010000..0b111111111 + 1) |i, v| {
        codes[i] = @bitReverse(@as(u9, v));
        bits[i] = 9;
    }
    for (256..279 + 1, 0b0000000..0b0010111 + 1) |i, v| {
        codes[i] = @bitReverse(@as(u7, v));
        bits[i] = 7;
    }
    for (280..287 - 2 + 1, 0b11000000..0b11000111 - 2 + 1) |i, v| {
        codes[i] = @bitReverse(@as(u8, v));
        bits[i] = 8;
    }
    break :blk .{ codes, bits };
};

pub const fixed_dist_codes = fixed_dist[0];
pub const fixed_dist_bits = fixed_dist[1];
const fixed_dist = blk: {
    var codes: [30]u16 = undefined;
    const bits: [30]u4 = @splat(5);

    for (0..30) |i| {
        codes[i] = @bitReverse(@as(u5, i));
    }
    break :blk .{ codes, bits };
};

// All paramters of codes can be derived matchematically, however some are faster to
// do via lookup table. For ReleaseSmall, we do all mathematically to save space.
pub const LenCode = if (builtin.mode != .ReleaseSmall) LookupLenCode else ShortLenCode;
pub const DistCode = if (builtin.mode != .ReleaseSmall) LookupDistCode else ShortDistCode;
const ShortLenCode = ShortCode(u8, u2, u3, true);
const ShortDistCode = ShortCode(u15, u1, u4, false);
/// For length and distance codes, they having this format.
///
/// For example, length code 0b1101 (13 or literal 270) has high_bits=0b01 and high_log2=3
/// and is 1_01_xx (2 extra bits). It is then offsetted by the min length of 3.
///        ^ bit 4 = 2 + high_log2 - 1
///
/// An exception is Length codes, where value 255 is assigned the special zero-bit code 28 or
/// literal 285.
fn ShortCode(Value: type, HighBits: type, HighLog2: type, len_special: bool) type {
    return packed struct(u5) {
        /// Bits preceding high bit or start if none
        high_bits: HighBits,
        /// High bit, 0 means none, otherwise it is at bit `x + high_log2 - 1`
        high_log2: HighLog2,

        pub fn fromVal(v: Value) @This() {
            if (len_special and v == 255) return .fromInt(28);
            const high_bits = @bitSizeOf(HighBits) + 1;
            const bits = @bitSizeOf(Value) - @clz(v);
            if (bits <= high_bits) return @bitCast(@as(u5, @intCast(v)));
            const high = v >> @intCast(bits - high_bits);
            return .{ .high_bits = @truncate(high), .high_log2 = @intCast(bits - high_bits + 1) };
        }

        /// `@ctz(return) >= extraBits()`
        pub fn base(c: @This()) Value {
            if (len_special and c.toInt() == 28) return 255;
            if (c.high_log2 <= 1) return @as(u5, @bitCast(c));
            const high_value = (@as(Value, @intFromBool(c.high_log2 != 0)) << @bitSizeOf(HighBits)) | c.high_bits;
            const high_start = @as(std.math.Log2Int(Value), c.high_log2 - 1);
            return @shlExact(high_value, high_start);
        }

        const max_extra = @bitSizeOf(Value) - (1 + @bitSizeOf(HighLog2));
        pub fn extraBits(c: @This()) std.math.IntFittingRange(0, max_extra) {
            if (len_special and c.toInt() == 28) return 0;
            return @intCast(c.high_log2 -| 1);
        }

        pub fn toInt(c: @This()) u5 {
            return @bitCast(c);
        }

        pub fn fromInt(x: u5) @This() {
            return @bitCast(x);
        }
    };
}

const LookupLenCode = packed struct(u5) {
    code: ShortLenCode,

    const code_table = table: {
        var codes: [256]ShortLenCode = undefined;
        for (0.., &codes) |v, *c| {
            c.* = .fromVal(v);
        }
        break :table codes;
    };

    const base_table = table: {
        var bases: [29]u8 = undefined;
        for (0.., &bases) |c, *b| {
            b.* = ShortLenCode.fromInt(c).base();
        }
        break :table bases;
    };

    pub fn fromVal(v: u8) LookupLenCode {
        return .{ .code = code_table[v] };
    }

    /// `@ctz(return) >= extraBits()`
    pub fn base(c: LookupLenCode) u8 {
        return base_table[c.toInt()];
    }

    pub fn extraBits(c: LookupLenCode) u3 {
        return c.code.extraBits();
    }

    pub fn toInt(c: LookupLenCode) u5 {
        return @bitCast(c);
    }

    pub fn fromInt(x: u5) LookupLenCode {
        return @bitCast(x);
    }
};

const LookupDistCode = packed struct(u5) {
    code: ShortDistCode,

    const base_table = table: {
        var bases: [30]u15 = undefined;
        for (0.., &bases) |c, *b| {
            b.* = ShortDistCode.fromInt(c).base();
        }
        break :table bases;
    };

    pub fn fromVal(v: u15) LookupDistCode {
        return .{ .code = .fromVal(v) };
    }

    /// `@ctz(return) >= extraBits()`
    pub fn base(c: LookupDistCode) u15 {
        return base_table[c.toInt()];
    }

    pub fn extraBits(c: LookupDistCode) u4 {
        return c.code.extraBits();
    }

    pub fn toInt(c: LookupDistCode) u5 {
        return @bitCast(c);
    }

    pub fn fromInt(x: u5) LookupDistCode {
        return @bitCast(x);
    }
};

test LenCode {
    inline for ([_]type{ ShortLenCode, LookupLenCode }) |Code| {
        // Check against the RFC 1951 table
        for (0.., [_]struct {
            base: u8,
            extra_bits: u4,
        }{
            // zig fmt: off
            .{ .base = 3   - min_length, .extra_bits = 0 },
            .{ .base = 4   - min_length, .extra_bits = 0 },
            .{ .base = 5   - min_length, .extra_bits = 0 },
            .{ .base = 6   - min_length, .extra_bits = 0 },
            .{ .base = 7   - min_length, .extra_bits = 0 },
            .{ .base = 8   - min_length, .extra_bits = 0 },
            .{ .base = 9   - min_length, .extra_bits = 0 },
            .{ .base = 10  - min_length, .extra_bits = 0 },
            .{ .base = 11  - min_length, .extra_bits = 1 },
            .{ .base = 13  - min_length, .extra_bits = 1 },
            .{ .base = 15  - min_length, .extra_bits = 1 },
            .{ .base = 17  - min_length, .extra_bits = 1 },
            .{ .base = 19  - min_length, .extra_bits = 2 },
            .{ .base = 23  - min_length, .extra_bits = 2 },
            .{ .base = 27  - min_length, .extra_bits = 2 },
            .{ .base = 31  - min_length, .extra_bits = 2 },
            .{ .base = 35  - min_length, .extra_bits = 3 },
            .{ .base = 43  - min_length, .extra_bits = 3 },
            .{ .base = 51  - min_length, .extra_bits = 3 },
            .{ .base = 59  - min_length, .extra_bits = 3 },
            .{ .base = 67  - min_length, .extra_bits = 4 },
            .{ .base = 83  - min_length, .extra_bits = 4 },
            .{ .base = 99  - min_length, .extra_bits = 4 },
            .{ .base = 115 - min_length, .extra_bits = 4 },
            .{ .base = 131 - min_length, .extra_bits = 5 },
            .{ .base = 163 - min_length, .extra_bits = 5 },
            .{ .base = 195 - min_length, .extra_bits = 5 },
            .{ .base = 227 - min_length, .extra_bits = 5 },
            .{ .base = 258 - min_length, .extra_bits = 0 },
        }) |code, params| {
            // zig fmt: on
            const c: u5 = @intCast(code);
            try std.testing.expectEqual(params.extra_bits, Code.extraBits(.fromInt(@intCast(c))));
            try std.testing.expectEqual(params.base, Code.base(.fromInt(@intCast(c))));
            for (params.base..params.base + @shlExact(@as(u16, 1), params.extra_bits) -
                @intFromBool(c == 27)) |v|
            {
                try std.testing.expectEqual(c, Code.fromVal(@intCast(v)).toInt());
            }
        }
    }
}

test DistCode {
    inline for ([_]type{ ShortDistCode, LookupDistCode }) |Code| {
        for (0.., [_]struct {
            base: u15,
            extra_bits: u4,
        }{
            // zig fmt: off
            .{ .base = 1     - min_distance, .extra_bits =  0 },
            .{ .base = 2     - min_distance, .extra_bits =  0 },
            .{ .base = 3     - min_distance, .extra_bits =  0 },
            .{ .base = 4     - min_distance, .extra_bits =  0 },
            .{ .base = 5     - min_distance, .extra_bits =  1 },
            .{ .base = 7     - min_distance, .extra_bits =  1 },
            .{ .base = 9     - min_distance, .extra_bits =  2 },
            .{ .base = 13    - min_distance, .extra_bits =  2 },
            .{ .base = 17    - min_distance, .extra_bits =  3 },
            .{ .base = 25    - min_distance, .extra_bits =  3 },
            .{ .base = 33    - min_distance, .extra_bits =  4 },
            .{ .base = 49    - min_distance, .extra_bits =  4 },
            .{ .base = 65    - min_distance, .extra_bits =  5 },
            .{ .base = 97    - min_distance, .extra_bits =  5 },
            .{ .base = 129   - min_distance, .extra_bits =  6 },
            .{ .base = 193   - min_distance, .extra_bits =  6 },
            .{ .base = 257   - min_distance, .extra_bits =  7 },
            .{ .base = 385   - min_distance, .extra_bits =  7 },
            .{ .base = 513   - min_distance, .extra_bits =  8 },
            .{ .base = 769   - min_distance, .extra_bits =  8 },
            .{ .base = 1025  - min_distance, .extra_bits =  9 },
            .{ .base = 1537  - min_distance, .extra_bits =  9 },
            .{ .base = 2049  - min_distance, .extra_bits = 10 },
            .{ .base = 3073  - min_distance, .extra_bits = 10 },
            .{ .base = 4097  - min_distance, .extra_bits = 11 },
            .{ .base = 6145  - min_distance, .extra_bits = 11 },
            .{ .base = 8193  - min_distance, .extra_bits = 12 },
            .{ .base = 12289 - min_distance, .extra_bits = 12 },
            .{ .base = 16385 - min_distance, .extra_bits = 13 },
            .{ .base = 24577 - min_distance, .extra_bits = 13 },
        }) |code, params| {
            // zig fmt: on
            const c: u5 = @intCast(code);
            try std.testing.expectEqual(params.extra_bits, Code.extraBits(.fromInt(@intCast(c))));
            try std.testing.expectEqual(params.base, Code.base(.fromInt(@intCast(c))));
            for (params.base..params.base + @shlExact(@as(u16, 1), params.extra_bits)) |v| {
                try std.testing.expectEqual(c, Code.fromVal(@intCast(v)).toInt());
            }
        }
    }
}
