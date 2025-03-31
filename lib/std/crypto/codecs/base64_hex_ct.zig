//! Hexadecimal and Base64 codecs designed for cryptographic use.
//! Thie file provides (best-effort) constant-time encoding and decoding functions for hexadecimal and Base64 formats.
//! This is designed to be used in cryptographic applications where timing attacks are a concern.
const std = @import("std");
const testing = std.testing;
const StaticBitSet = std.StaticBitSet;

pub const Error = error{
    /// An invalid character was found in the input.
    InvalidCharacter,
    /// The input is not properly padded.
    InvalidPadding,
    /// The input buffer is too small to hold the output.
    NoSpaceLeft,
    /// The input and output buffers are not the same size.
    SizeMismatch,
};

/// (best-effort) constant time hexadecimal encoding and decoding.
pub const Hex = struct {
    /// Encodes a binary buffer into a hexadecimal string.
    /// The output buffer must be twice the size of the input buffer.
    pub fn encode(hex: []u8, bin: []const u8, comptime case: std.fmt.Case) error{SizeMismatch}!void {
        if (hex.len / 2 != bin.len) {
            return error.SizeMismatch;
        }
        for (bin, 0..) |v, i| {
            const b: u16 = v >> 4;
            const c: u16 = v & 0xf;
            const off = if (case == .upper) 32 else 0;
            const x =
                ((87 - off + c + (((c -% 10) >> 8) & ~@as(u16, 38 - off))) & 0xff) << 8 |
                ((87 - off + b + (((b -% 10) >> 8) & ~@as(u16, 38 - off))) & 0xff);
            hex[i * 2] = @truncate(x);
            hex[i * 2 + 1] = @truncate(x >> 8);
        }
    }

    /// Decodes a hexadecimal string into a binary buffer.
    /// The output buffer must be half the size of the input buffer.
    pub fn decode(bin: []u8, hex: []const u8) error{ SizeMismatch, InvalidCharacter, InvalidPadding }!void {
        if (hex.len % 2 != 0) {
            return error.InvalidPadding;
        }
        if (bin.len < hex.len / 2) {
            return error.SizeMismatch;
        }
        _ = decodeAny(bin, hex, null) catch |err| {
            switch (err) {
                error.InvalidCharacter => return error.InvalidCharacter,
                error.InvalidPadding => return error.InvalidPadding,
                else => unreachable,
            }
        };
    }

    /// A decoder that ignores certain characters.
    /// The decoder will skip any characters that are in the ignore list.
    pub const DecoderWithIgnore = struct {
        /// The characters to ignore.
        ignored_chars: StaticBitSet(256) = undefined,

        /// Decodes a hexadecimal string into a binary buffer.
        /// The output buffer must be half the size of the input buffer.
        pub fn decode(
            self: DecoderWithIgnore,
            bin: []u8,
            hex: []const u8,
        ) error{ NoSpaceLeft, InvalidCharacter, InvalidPadding }![]const u8 {
            return decodeAny(bin, hex, self.ignored_chars);
        }

        /// Returns the decoded length of a hexadecimal string, ignoring any characters in the ignore list.
        /// This operation doesn't run im constant time, but shouldn't leak information about the actual hexadecimal string.
        pub fn decodedLenForSlice(Decoder: DecoderWithIgnore, hex: []const u8) !usize {
            var hex_len = hex.len;
            for (hex) |c| {
                if (Decoder.ignored_chars.isSet(c)) hex_len -= 1;
            }
            if (hex_len % 2 != 0) {
                return error.InvalidPadding;
            }
            return hex_len / 2;
        }

        /// Returns the maximum possible decoded size for a given input length after skipping ignored characters.
        pub fn decodedLenUpperBound(hex_len: usize) usize {
            return hex_len / 2;
        }
    };

    /// Creates a new decoder that ignores certain characters.
    /// The decoder will skip any characters that are in the ignore list.
    /// The ignore list must not contain any valid hexadecimal characters.
    pub fn decoderWithIgnore(ignore_chars: []const u8) error{InvalidCharacter}!DecoderWithIgnore {
        var ignored_chars = StaticBitSet(256).initEmpty();
        for (ignore_chars) |c| {
            switch (c) {
                '0'...'9', 'a'...'f', 'A'...'F' => return error.InvalidCharacter,
                else => if (ignored_chars.isSet(c)) return error.InvalidCharacter,
            }
            ignored_chars.set(c);
        }
        return DecoderWithIgnore{ .ignored_chars = ignored_chars };
    }

    fn decodeAny(
        bin: []u8,
        hex: []const u8,
        ignored_chars: ?StaticBitSet(256),
    ) error{ NoSpaceLeft, InvalidCharacter, InvalidPadding }![]const u8 {
        var bin_pos: usize = 0;
        var state: bool = false;
        var c_acc: u8 = 0;
        for (hex) |c| {
            const c_num = c ^ 48;
            const c_num0: u8 = @truncate((@as(u16, c_num) -% 10) >> 8);
            const c_alpha: u8 = (c & ~@as(u8, 32)) -% 55;
            const c_alpha0: u8 = @truncate(((@as(u16, c_alpha) -% 10) ^ (@as(u16, c_alpha) -% 16)) >> 8);
            if ((c_num0 | c_alpha0) == 0) {
                if (ignored_chars) |set| {
                    if (set.isSet(c)) {
                        continue;
                    }
                }
                return error.InvalidCharacter;
            }
            const c_val = (c_num0 & c_num) | (c_alpha0 & c_alpha);
            if (bin_pos >= bin.len) {
                return error.NoSpaceLeft;
            }
            if (!state) {
                c_acc = c_val << 4;
            } else {
                bin[bin_pos] = c_acc | c_val;
                bin_pos += 1;
            }
            state = !state;
        }
        if (state) {
            return error.InvalidPadding;
        }
        return bin[0..bin_pos];
    }
};

/// (best-effort) constant time base64 encoding and decoding.
pub const Base64 = struct {
    /// The base64 variant to use.
    pub const Variant = packed struct {
        /// Use the URL-safe alphabet instead of the standard alphabet.
        urlsafe_alphabet: bool = false,
        /// Enable padding with '=' characters.
        padding: bool = true,

        /// The standard base64 variant.
        pub const standard = Variant{ .urlsafe_alphabet = false, .padding = true };
        /// The URL-safe base64 variant.
        pub const urlsafe = Variant{ .urlsafe_alphabet = true, .padding = true };
        /// The standard base64 variant without padding.
        pub const standard_nopad = Variant{ .urlsafe_alphabet = false, .padding = false };
        /// The URL-safe base64 variant without padding.
        pub const urlsafe_nopad = Variant{ .urlsafe_alphabet = true, .padding = false };
    };

    /// Returns the length of the encoded base64 string for a given length.
    pub fn encodedLen(bin_len: usize, variant: Variant) usize {
        if (variant.padding) {
            return (bin_len + 2) / 3 * 4;
        } else {
            const leftover = bin_len % 3;
            return bin_len / 3 * 4 + (leftover * 4 + 2) / 3;
        }
    }

    /// Returns the maximum possible decoded size for a given input length - The actual length may be less if the input includes padding.
    /// `InvalidPadding` is returned if the input length is not valid.
    pub fn decodedLen(b64_len: usize, variant: Variant) !usize {
        var result = b64_len / 4 * 3;
        const leftover = b64_len % 4;
        if (variant.padding) {
            if (leftover % 4 != 0) return error.InvalidPadding;
        } else {
            if (leftover % 4 == 1) return error.InvalidPadding;
            result += leftover * 3 / 4;
        }
        return result;
    }

    /// Encodes a binary buffer into a base64 string.
    /// The output buffer must be at least `encodedLen(bin.len)` bytes long.
    pub fn encode(b64: []u8, bin: []const u8, comptime variant: Variant) error{NoSpaceLeft}![]const u8 {
        var acc_len: u4 = 0;
        var b64_pos: usize = 0;
        var acc: u16 = 0;
        const nibbles = bin.len / 3;
        const remainder = bin.len - 3 * nibbles;
        var b64_len = nibbles * 4;
        if (remainder != 0) {
            b64_len += if (variant.padding) 4 else 2 + (remainder >> 1);
        }
        if (b64.len < b64_len) {
            return error.NoSpaceLeft;
        }
        const urlsafe = variant.urlsafe_alphabet;
        for (bin) |v| {
            acc = (acc << 8) + v;
            acc_len += 8;
            while (acc_len >= 6) {
                acc_len -= 6;
                b64[b64_pos] = charFromByte(@as(u6, @truncate(acc >> acc_len)), urlsafe);
                b64_pos += 1;
            }
        }
        if (acc_len > 0) {
            b64[b64_pos] = charFromByte(@as(u6, @truncate(acc << (6 - acc_len))), urlsafe);
            b64_pos += 1;
        }
        while (b64_pos < b64_len) {
            b64[b64_pos] = '=';
            b64_pos += 1;
        }
        return b64[0..b64_pos];
    }

    /// Decodes a base64 string into a binary buffer.
    /// The output buffer must be at least `decodedLenUpperBound(b64.len)` bytes long.
    pub fn decode(bin: []u8, b64: []const u8, comptime variant: Variant) error{ InvalidCharacter, InvalidPadding }![]const u8 {
        return decodeAny(bin, b64, variant, null) catch |err| {
            switch (err) {
                error.InvalidCharacter => return error.InvalidCharacter,
                error.InvalidPadding => return error.InvalidPadding,
                else => unreachable,
            }
        };
    }

    //// A decoder that ignores certain characters.
    pub const DecoderWithIgnore = struct {
        /// The characters to ignore.
        ignored_chars: StaticBitSet(256) = undefined,

        /// Decodes a base64 string into a binary buffer.
        /// The output buffer must be at least `decodedLenUpperBound(b64.len)` bytes long.
        pub fn decode(
            self: DecoderWithIgnore,
            bin: []u8,
            b64: []const u8,
            comptime variant: Variant,
        ) error{ NoSpaceLeft, InvalidCharacter, InvalidPadding }![]const u8 {
            return decodeAny(bin, b64, variant, self.ignored_chars);
        }

        /// Returns the decoded length of a base64 string, ignoring any characters in the ignore list.
        /// This operation doesn't run im constant time, but shouldn't leak information about the actual base64 string.
        pub fn decodedLenForSlice(Decoder: DecoderWithIgnore, b64: []const u8, variant: Variant) !usize {
            var b64_len = b64.len;
            for (b64) |c| {
                if (Decoder.ignored_chars.isSet(c)) b64_len -= 1;
            }
            return Base64.decodedLen(b64_len, variant);
        }

        /// Returns the maximum possible decoded size for a given input length after skipping ignored characters.
        pub fn decodedLenUpperBound(b64_len: usize) usize {
            return b64_len / 3 * 4;
        }
    };

    /// Creates a new decoder that ignores certain characters.
    pub fn decoderWithIgnore(ignore_chars: []const u8) error{InvalidCharacter}!DecoderWithIgnore {
        var ignored_chars = StaticBitSet(256).initEmpty();
        for (ignore_chars) |c| {
            switch (c) {
                'A'...'Z', 'a'...'z', '0'...'9' => return error.InvalidCharacter,
                else => if (ignored_chars.isSet(c)) return error.InvalidCharacter,
            }
            ignored_chars.set(c);
        }
        return DecoderWithIgnore{ .ignored_chars = ignored_chars };
    }

    inline fn eq(x: u8, y: u8) u8 {
        return ~@as(u8, @truncate((0 -% (@as(u16, x) ^ @as(u16, y))) >> 8));
    }

    inline fn gt(x: u8, y: u8) u8 {
        return @truncate((@as(u16, y) -% @as(u16, x)) >> 8);
    }

    inline fn ge(x: u8, y: u8) u8 {
        return ~gt(y, x);
    }

    inline fn lt(x: u8, y: u8) u8 {
        return gt(y, x);
    }

    inline fn le(x: u8, y: u8) u8 {
        return ge(y, x);
    }

    inline fn charFromByte(x: u8, comptime urlsafe: bool) u8 {
        return (lt(x, 26) & (x +% 'A')) |
            (ge(x, 26) & lt(x, 52) & (x +% 'a' -% 26)) |
            (ge(x, 52) & lt(x, 62) & (x +% '0' -% 52)) |
            (eq(x, 62) & '+') | (eq(x, 63) & if (urlsafe) '_' else '/');
    }

    inline fn byteFromChar(c: u8, comptime urlsafe: bool) u8 {
        const x =
            (ge(c, 'A') & le(c, 'Z') & (c -% 'A')) |
            (ge(c, 'a') & le(c, 'z') & (c -% 'a' +% 26)) |
            (ge(c, '0') & le(c, '9') & (c -% '0' +% 52)) |
            (eq(c, '+') & 62) | (eq(c, if (urlsafe) '_' else '/') & 63);
        return x | (eq(x, 0) & ~eq(c, 'A'));
    }

    fn skipPadding(
        b64: []const u8,
        padding_len: usize,
        ignored_chars: ?StaticBitSet(256),
    ) error{InvalidPadding}![]const u8 {
        var b64_pos: usize = 0;
        var i = padding_len;
        while (i > 0) {
            if (b64_pos >= b64.len) {
                return error.InvalidPadding;
            }
            const c = b64[b64_pos];
            if (c == '=') {
                i -= 1;
            } else if (ignored_chars) |set| {
                if (!set.isSet(c)) {
                    return error.InvalidPadding;
                }
            }
            b64_pos += 1;
        }
        return b64[b64_pos..];
    }

    fn decodeAny(
        bin: []u8,
        b64: []const u8,
        comptime variant: Variant,
        ignored_chars: ?StaticBitSet(256),
    ) error{ NoSpaceLeft, InvalidCharacter, InvalidPadding }![]const u8 {
        var acc: u16 = 0;
        var acc_len: u4 = 0;
        var bin_pos: usize = 0;
        var premature_end: ?usize = null;
        const urlsafe = variant.urlsafe_alphabet;
        for (b64, 0..) |c, b64_pos| {
            const d = byteFromChar(c, urlsafe);
            if (d == 0xff) {
                if (ignored_chars) |set| {
                    if (set.isSet(c)) continue;
                }
                premature_end = b64_pos;
                break;
            }
            acc = (acc << 6) + d;
            acc_len += 6;
            if (acc_len >= 8) {
                acc_len -= 8;
                if (bin_pos >= bin.len) {
                    return error.NoSpaceLeft;
                }
                bin[bin_pos] = @truncate(acc >> acc_len);
                bin_pos += 1;
            }
        }
        if (acc_len > 4 or (acc & ((@as(u16, 1) << acc_len) -% 1)) != 0) {
            return error.InvalidCharacter;
        }
        const padding_len = acc_len / 2;
        if (premature_end) |pos| {
            const remaining =
                if (variant.padding)
                    try skipPadding(b64[pos..], padding_len, ignored_chars)
                else
                    b64[pos..];
            if (ignored_chars) |set| {
                for (remaining) |c| {
                    if (!set.isSet(c)) {
                        return error.InvalidCharacter;
                    }
                }
            } else if (remaining.len != 0) {
                return error.InvalidCharacter;
            }
        } else if (variant.padding and padding_len != 0) {
            return error.InvalidPadding;
        }
        return bin[0..bin_pos];
    }
};

test "hex" {
    var default_rng = std.Random.DefaultPrng.init(testing.random_seed);
    var rng = default_rng.random();
    var bin_buf: [1000]u8 = undefined;
    rng.bytes(&bin_buf);
    var bin2_buf: [bin_buf.len]u8 = undefined;
    var hex_buf: [bin_buf.len * 2]u8 = undefined;
    for (0..1000) |_| {
        const bin_len = rng.intRangeAtMost(usize, 0, bin_buf.len);
        const bin = bin_buf[0..bin_len];
        const bin2 = bin2_buf[0..bin_len];
        inline for (.{ .lower, .upper }) |case| {
            const hex_len = bin_len * 2;
            const hex = hex_buf[0..hex_len];
            try Hex.encode(hex, bin, case);
            try Hex.decode(bin2, hex);
            try testing.expectEqualSlices(u8, bin, bin2);
        }
    }
}

test "base64" {
    var default_rng = std.Random.DefaultPrng.init(testing.random_seed);
    var rng = default_rng.random();
    var bin_buf: [1000]u8 = undefined;
    rng.bytes(&bin_buf);
    var bin2_buf: [bin_buf.len]u8 = undefined;
    var b64_buf: [(bin_buf.len + 3) / 3 * 4]u8 = undefined;
    for (0..1000) |_| {
        const bin_len = rng.intRangeAtMost(usize, 0, bin_buf.len);
        const bin = bin_buf[0..bin_len];
        const bin2 = bin2_buf[0..bin_len];
        inline for ([_]Base64.Variant{
            .standard,
            .standard_nopad,
            .urlsafe,
            .urlsafe_nopad,
        }) |variant| {
            const b64_len = Base64.encodedLen(bin_len, variant);
            const b64 = b64_buf[0..b64_len];
            const encoded = try Base64.encode(b64, bin, variant);
            const decoded = try Base64.decode(bin2, encoded, variant);
            try testing.expectEqualSlices(u8, bin, decoded);
        }
    }
}

test "hex with ignored chars" {
    const hex = "01020304050607\n08090A0B0C0D0E0F\n";
    const expected = [_]u8{ 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F };
    var bin_buf: [hex.len / 2]u8 = undefined;
    try testing.expectError(error.InvalidCharacter, Hex.decode(&bin_buf, hex));
    const bin = try (try Hex.decoderWithIgnore("\r\n")).decode(&bin_buf, hex);
    try testing.expectEqualSlices(u8, &expected, bin);
}

test "base64 with ignored chars" {
    const b64 = "dGVzdCBi\r\nYXNlNjQ=\n";
    const expected = "test base64";
    var bin_buf: [Base64.DecoderWithIgnore.decodedLenUpperBound(b64.len)]u8 = undefined;
    try testing.expectError(error.InvalidCharacter, Base64.decode(&bin_buf, b64, .standard));
    const bin = try (try Base64.decoderWithIgnore("\r\n")).decode(&bin_buf, b64, .standard);
    try testing.expectEqualSlices(u8, expected, bin);
}
