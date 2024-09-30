//! Base32 encoding/decoding.

const std = @import("std");
const assert = std.debug.assert;
const mem = std.mem;
const window = mem.window;

pub const Error = error{
    InvalidCharacter,
    InvalidPadding,
};

const decoderProto = *const fn (ignore: []const u8) Base32Decoder;

/// Base32 codecs
pub const Codecs = struct {
    alphabet_chars: [32]u8,
    pad_char: ?u8,
    Encoder: Base32Encoder,
    Decoder: Base32Decoder,
};

pub const standard_hex_alphabet_chars = "0123456789ABCDEFGHIJKLMNOPQRSTUV".*;
pub const standard_alphabet_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".*;
fn standardBase32Decoder(ignore: []const u8) Base32Decoder {
    return Base32Decoder.init(standard_alphabet_chars, '=', ignore);
}

/// Standard Base32 codecs, with padding
pub const standard = Codecs{
    .alphabet_chars = standard_alphabet_chars,
    .pad_char = '=',
    .Encoder = Base32Encoder.init(standard_alphabet_chars, '='),
    .Decoder = Base32Decoder.init(standard_alphabet_chars, '='),
};

/// Standard Base32 codecs, with padding
pub const standard_hex = Codecs{
    .alphabet_chars = standard_hex_alphabet_chars,
    .pad_char = '=',
    .Encoder = Base32Encoder.init(standard_hex_alphabet_chars, '='),
    .Decoder = Base32Decoder.init(standard_hex_alphabet_chars, '='),
};

/// Standard Base32 codecs, without padding
pub const standard_no_pad = Codecs{
    .alphabet_chars = standard_alphabet_chars,
    .pad_char = null,
    .Encoder = Base32Encoder.init(standard_alphabet_chars, null),
    .Decoder = Base32Decoder.init(standard_alphabet_chars, null),
};

pub const Base32Encoder = struct {
    alphabet_chars: [32]u8,
    pad_char: ?u8,

    /// A bunch of assertions, then simply pass the data right through.
    pub fn init(alphabet_chars: [32]u8, pad_char: ?u8) Base32Encoder {
        assert(alphabet_chars.len == 32);
        var char_in_alphabet = [_]bool{false} ** 256;
        for (alphabet_chars) |c| {
            assert(!char_in_alphabet[c]);
            assert(pad_char == null or c != pad_char.?);
            char_in_alphabet[c] = true;
        }
        return Base32Encoder{
            .alphabet_chars = alphabet_chars,
            .pad_char = pad_char,
        };
    }

    /// Compute the encoded length
    pub fn calcSize(encoder: *const Base32Encoder, source_len: usize) usize {
        if (encoder.pad_char != null) {
            return @divTrunc(source_len + 4, 5) * 8;
        } else {
            const leftover = source_len % 5;
            return @divTrunc(source_len, 5) * 8 + @divTrunc(leftover * 8 + 4, 5);
        }
    }

    // dest must be compatible with std.io.Writer's writeAll interface
    pub fn encodeWriter(encoder: *const Base32Encoder, dest: anytype, source: []const u8) !void {
        var chunker = window(u8, source, 3, 3);
        while (chunker.next()) |chunk| {
            var temp: [5]u8 = undefined;
            const s = encoder.encode(&temp, chunk);
            try dest.writeAll(s);
        }
    }

    // destWriter must be compatible with std.io.Writer's writeAll interface
    // sourceReader must be compatible with std.io.Reader's read interface
    pub fn encodeFromReaderToWriter(encoder: *const Base32Encoder, destWriter: anytype, sourceReader: anytype) !void {
        while (true) {
            var tempSource: [3]u8 = undefined;
            const bytesRead = try sourceReader.read(&tempSource);
            if (bytesRead == 0) {
                break;
            }

            var temp: [5]u8 = undefined;
            const s = encoder.encode(&temp, tempSource[0..bytesRead]);
            try destWriter.writeAll(s);
        }
    }

    /// dest.len must at least be what you get from ::calcSize.
    pub fn encode(encoder: *const Base32Encoder, dest: []u8, source: []const u8) []const u8 {
        const out_len = encoder.calcSize(source.len);
        assert(dest.len >= out_len);

        var idx: usize = 0;
        var out_idx: usize = 0;
        const n: usize = (source.len / 5) * 5;

        if (n % 5 == 0) {
            while (idx < n) : ({
                idx += 5;
                out_idx += 8;
            }) {
                const hi: u32 = std.mem.readInt(u32, source[idx..][0..4], .big);

                var shift: u5 = 31;
                inline for (0..6) |i| {
                    shift -= 5;
                    dest[out_idx + i] = encoder.alphabet_chars[(hi >> shift + 1) & 0x1f];
                }

                const lo: u32 = hi << 8 | source[idx + 4];
                dest[out_idx + 6] = encoder.alphabet_chars[(lo >> 5) & 0x1f];
                dest[out_idx + 7] = encoder.alphabet_chars[(lo) & 0x1f];
            }
        }

        var remaining = source.len - idx;
        if (remaining == 0) {
            return dest[0..out_len];
        }

        var val: u32 = 0;
        if (remaining == 4) {
            val |= @as(u32, source[idx + 3]);
            dest[out_idx + 6] = encoder.alphabet_chars[val << 3 & 0x1f];
            dest[out_idx + 5] = encoder.alphabet_chars[val >> 2 & 0x1f];
            remaining -= 1;
        }
        if (remaining == 3) {
            val |= @as(u32, source[idx + 2]) << 8;
            dest[out_idx + 4] = encoder.alphabet_chars[val >> 7 & 0x1f];
            remaining -= 1;
        }
        if (remaining == 2) {
            val |= @as(u32, source[idx + 1]) << 16;
            dest[out_idx + 3] = encoder.alphabet_chars[val >> 12 & 0x1f];
            dest[out_idx + 2] = encoder.alphabet_chars[val >> 17 & 0x1f];
            remaining -= 1;
        }
        if (remaining == 1) {
            val |= @as(u32, source[idx]) << 24;
            dest[out_idx + 1] = encoder.alphabet_chars[val >> 22 & 0x1f];
            dest[out_idx + 0] = encoder.alphabet_chars[val >> 27 & 0x1f];
            remaining -= 1;
        }

        const pad_from: usize = ((source.len - idx) * 8 / 5) + 1 + out_idx;
        if (encoder.pad_char) |pad_char| {
            for (dest[pad_from..out_len]) |*pad| {
                pad.* = pad_char;
            }
        }
        return dest[0..out_len];
    }
};

test "base32test" {
    const TestPair = struct {
        input: []const u8,
        expected: []const u8,
        hexpected: []const u8,
    };
    const pairs = [_]TestPair{
        // RFC 4648 examples
        .{ .input = "", .expected = "", .hexpected = "" },
        .{ .input = "f", .expected = "MY======", .hexpected = "CO======" },
        .{ .input = "fo", .expected = "MZXQ====", .hexpected = "CPNG====" },
        .{ .input = "foo", .expected = "MZXW6===", .hexpected = "CPNMU===" },
        .{ .input = "foob", .expected = "MZXW6YQ=", .hexpected = "CPNMUOG=" },
        .{ .input = "fooba", .expected = "MZXW6YTB", .hexpected = "CPNMUOJ1" },
        .{ .input = "foobafooba", .expected = "MZXW6YTBMZXW6YTB", .hexpected = "CPNMUOJ1CPNMUOJ1" },
        .{ .input = "foobar", .expected = "MZXW6YTBOI======", .hexpected = "CPNMUOJ1E8======" },

        // Wikipedia examples, converted to base32
        .{ .input = "sure.", .expected = "ON2XEZJO", .hexpected = "EDQN4P9E" },
        .{ .input = "sure", .expected = "ON2XEZI=", .hexpected = "EDQN4P8=" },
        .{ .input = "sur", .expected = "ON2XE===", .hexpected = "EDQN4===" },
        .{ .input = "su", .expected = "ON2Q====", .hexpected = "EDQG====" },
        .{ .input = "leasure.", .expected = "NRSWC43VOJSS4===", .hexpected = "DHIM2SRLE9IIS===" },
        .{ .input = "easure.", .expected = "MVQXG5LSMUXA====", .hexpected = "CLGN6TBICKN0====" },
        .{ .input = "asure.", .expected = "MFZXK4TFFY======", .hexpected = "C5PNASJ55O======" },
        .{ .input = "sure.", .expected = "ON2XEZJO", .hexpected = "EDQN4P9E" },

        // Big test
        .{
            .input = "Twas brillig, and the slithy toves",
            .expected = "KR3WC4ZAMJZGS3DMNFTSYIDBNZSCA5DIMUQHG3DJORUHSIDUN53GK4Y=",
            .hexpected = "AHRM2SP0C9P6IR3CD5JIO831DPI20T38CKG76R39EHK7I83KDTR6ASO=",
        },
    };

    for (pairs) |pair| {
        var buffer: [256]u8 = undefined;
        var res = standard.Encoder.encode(&buffer, pair.input);
        try std.testing.expectEqualStrings(pair.expected, res);

        buffer = undefined;
        res = standard_hex.Encoder.encode(&buffer, pair.input);
        try std.testing.expectEqualStrings(pair.hexpected, res);
    }
}

pub const Base32Decoder = struct {
    const invalid_char: u8 = 0xff;
    const invalid_char_tst: u32 = 0xff000000;

    /// e.g. 'A' => 0.
    /// `invalid_char` for any value not in the 32 alphabet chars.
    char_to_index: [256]u8,
    fast_char_to_index: [4][256]u32,
    pad_char: ?u8,

    pub fn init(alphabet_chars: [32]u8, pad_char: ?u8) Base32Decoder {
        var result = Base32Decoder{
            .char_to_index = [_]u8{invalid_char} ** 256,
            .fast_char_to_index = .{[_]u32{invalid_char_tst} ** 256} ** 4,
            .pad_char = pad_char,
        };

        var char_in_alphabet = [_]bool{false} ** 256;
        for (alphabet_chars, 0..) |c, i| {
            assert(!char_in_alphabet[c]);
            assert(pad_char == null or c != pad_char.?);

            const ci = @as(u32, @intCast(i));
            result.fast_char_to_index[0][c] = ci << 2;
            result.fast_char_to_index[1][c] = (ci >> 4) | ((ci & 0x0f) << 12);
            result.fast_char_to_index[2][c] = ((ci & 0x3) << 22) | ((ci & 0x3c) << 6);
            result.fast_char_to_index[3][c] = ci << 16;

            result.char_to_index[c] = @as(u8, @intCast(i));
            char_in_alphabet[c] = true;
        }
        return result;
    }

    /// Return the maximum possible decoded size for a given input length - The actual length may be less if the input includes padding.
    /// `InvalidPadding` is returned if the input length is not valid.
    pub fn calcSizeUpperBound(decoder: *const Base32Decoder, source_len: usize) Error!usize {
        var result = source_len / 8 * 5;
        const leftover = source_len % 8;
        if (decoder.pad_char != null) {
            if (leftover == 7) return error.InvalidPadding;
            if (leftover == 5) return error.InvalidPadding;
            if (leftover == 2) return error.InvalidPadding;
        } else {
            result += leftover * 8 / 5;
        }
        return result;
    }

    /// Return the exact decoded size for a slice.
    /// `InvalidPadding` is returned if the input length is not valid.
    pub fn calcSizeForSlice(decoder: *const Base32Decoder, source: []const u8) Error!usize {
        const source_len = source.len;
        if (decoder.pad_char != null and source.len % 8 != 0) {
            return error.InvalidPadding;
        }

        var result = try decoder.calcSizeUpperBound(source_len);
        if (decoder.pad_char) |pad_char| {
            if (source_len > 0) {
                if (source[source_len - 1] == pad_char) {
                    result -= 1;
                }
                if (source[source_len - 3] == pad_char) {
                    result -= 1;
                }
                if (source[source_len - 4] == pad_char) {
                    result -= 1;
                }
                if (source[source_len - 6] == pad_char) {
                    result -= 1;
                }
            }
        }
        return result;
    }

    /// dest.len must be what you get from ::calcSize.
    /// Invalid characters result in `error.InvalidCharacter`.
    /// Invalid padding results in `error.InvalidPadding`.
    pub fn decode(decoder: *const Base32Decoder, dest: []u8, source: []const u8) Error!void {
        if (decoder.pad_char != null and source.len % 8 != 0) {
            return error.InvalidPadding;
        }

        var dest_idx: usize = 0;
        var source_idx: usize = 0;
        const cti = decoder.char_to_index;

        if (source.len > 0) {
            while (dest_idx < dest.len) : ({
                dest_idx += 5;
                source_idx += 8;
            }) {
                var remaining: usize = 0;

                check: for (0..8) |i| {
                    if (source[source_idx + i] == decoder.pad_char) {
                        break :check;
                    }
                    if (cti[source[source_idx + i]] == 0xff) {
                        return error.InvalidCharacter;
                    }
                    remaining += 1;
                }

                while (remaining > 0) {
                    const s_idx = source_idx + remaining;
                    switch (remaining) {
                        8 => {
                            dest[dest_idx + 4] = cti[source[s_idx - 2]] << 5 | cti[source[s_idx - 1]];
                            remaining -= 1;
                        },
                        7 => {
                            dest[dest_idx + 3] = cti[source[s_idx - 3]] << 7 | cti[source[s_idx - 2]] << 2 | cti[source[s_idx - 1]] >> 3;
                            remaining -= 2;
                        },
                        5 => {
                            dest[dest_idx + 2] = cti[source[s_idx - 2]] << 4 | cti[source[s_idx - 1]] >> 1;
                            remaining -= 1;
                        },
                        4 => {
                            dest[dest_idx + 1] = cti[source[s_idx - 3]] << 6 | cti[source[s_idx - 2]] << 1 | cti[source[s_idx - 1]] >> 4;
                            remaining -= 2;
                        },
                        2 => {
                            dest[dest_idx + 0] = cti[source[s_idx - 2]] << 3 | cti[source[s_idx - 1]] >> 2;
                            remaining -= 2;
                        },
                        else => return error.InvalidPadding,
                    }
                }
            }
        }
    }
};

test "base32 decode" {
    const TestPair = struct {
        input: []const u8,
        expected: []const u8,
        expected_len: u8,
    };
    const pairs = [_]TestPair{
        // RFC 4648 examples
        .{ .expected = "", .input = "", .expected_len = 0 },
        .{ .expected = "f", .input = "MY======", .expected_len = 1 },
        .{ .expected = "fo", .input = "MZXQ====", .expected_len = 2 },
        .{ .expected = "foo", .input = "MZXW6===", .expected_len = 3 },
        .{ .expected = "foob", .input = "MZXW6YQ=", .expected_len = 4 },

        .{ .expected = "fooba", .input = "MZXW6YTB", .expected_len = 5 },
        .{ .expected = "foobafooba", .input = "MZXW6YTBMZXW6YTB", .expected_len = 10 },
        .{ .expected = "foobar", .input = "MZXW6YTBOI======", .expected_len = 6 },

        // Wikipedia examples, converted to base32
        .{ .expected = "sure.", .input = "ON2XEZJO", .expected_len = 5 },
        .{ .expected = "sure", .input = "ON2XEZI=", .expected_len = 4 },
        .{ .expected = "sur", .input = "ON2XE===", .expected_len = 3 },
        .{ .expected = "su", .input = "ON2Q====", .expected_len = 2 },
        .{ .expected = "leasure.", .input = "NRSWC43VOJSS4===", .expected_len = 8 },
        .{ .expected = "easure.", .input = "MVQXG5LSMUXA====", .expected_len = 7 },
        .{ .expected = "asure.", .input = "MFZXK4TFFY======", .expected_len = 6 },
        .{ .expected = "sure.", .input = "ON2XEZJO", .expected_len = 5 },

        // Big test
        .{
            .expected = "Twas brillig, and the slithy toves",
            .input = "KR3WC4ZAMJZGS3DMNFTSYIDBNZSCA5DIMUQHG3DJORUHSIDUN53GK4Y=",
            .expected_len = 34,
        },
    };

    for (pairs) |pair| {
        var buffer: [0x100]u8 = undefined;
        const len = try standard.Decoder.calcSizeForSlice(pair.input);

        try std.testing.expectEqual(pair.expected_len, len);

        const decoded = buffer[0..len];
        try standard.Decoder.decode(decoded, pair.input);
        try std.testing.expectEqualSlices(u8, pair.expected, decoded);
    }
}

test "base32 size errors" {
    const TestPair = struct {
        input: []const u8,
        expected_error: anyerror,
    };
    const pairs = [_]TestPair{
        .{ .expected_error = error.InvalidPadding, .input = "MY=====" },
        .{ .expected_error = error.InvalidPadding, .input = "MY====" },
        .{ .expected_error = error.InvalidPadding, .input = "MZXW6YTBOI==" },
    };

    for (pairs) |pair| {
        const len = standard.Decoder.calcSizeForSlice(pair.input);

        try std.testing.expectError(pair.expected_error, len);
    }
}

test "base32 decode errors" {
    const TestPair = struct {
        input: []const u8,
        expected_len: u8,
        expected_error: anyerror,
    };
    const pairs = [_]TestPair{
        .{ .expected_error = error.InvalidCharacter, .input = "MZXWYTB9", .expected_len = 5 },
    };

    for (pairs) |pair| {
        var buffer: [0x100]u8 = undefined;
        const len = try standard.Decoder.calcSizeForSlice(pair.input);

        try std.testing.expectEqual(pair.expected_len, len);

        const decoded = buffer[0..len];
        try std.testing.expectError(pair.expected_error, standard.Decoder.decode(decoded, pair.input));
    }
}
