// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const mem = std.mem;

pub const standard_alphabet_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
pub const standard_pad_char = '=';
pub const standard_encoder = Base64Encoder.init(standard_alphabet_chars, standard_pad_char);

pub const Base64Encoder = struct {
    alphabet_chars: []const u8,
    pad_char: u8,

    /// a bunch of assertions, then simply pass the data right through.
    pub fn init(alphabet_chars: []const u8, pad_char: u8) Base64Encoder {
        assert(alphabet_chars.len == 64);
        var char_in_alphabet = [_]bool{false} ** 256;
        for (alphabet_chars) |c| {
            assert(!char_in_alphabet[c]);
            assert(c != pad_char);
            char_in_alphabet[c] = true;
        }

        return Base64Encoder{
            .alphabet_chars = alphabet_chars,
            .pad_char = pad_char,
        };
    }

    /// ceil(source_len * 4/3)
    pub fn calcSize(source_len: usize) usize {
        return @divTrunc(source_len + 2, 3) * 4;
    }

    /// dest.len must be what you get from ::calcSize.
    pub fn encode(encoder: *const Base64Encoder, dest: []u8, source: []const u8) void {
        assert(dest.len == Base64Encoder.calcSize(source.len));

        var i: usize = 0;
        var out_index: usize = 0;
        while (i + 2 < source.len) : (i += 3) {
            dest[out_index] = encoder.alphabet_chars[(source[i] >> 2) & 0x3f];
            out_index += 1;

            dest[out_index] = encoder.alphabet_chars[((source[i] & 0x3) << 4) | ((source[i + 1] & 0xf0) >> 4)];
            out_index += 1;

            dest[out_index] = encoder.alphabet_chars[((source[i + 1] & 0xf) << 2) | ((source[i + 2] & 0xc0) >> 6)];
            out_index += 1;

            dest[out_index] = encoder.alphabet_chars[source[i + 2] & 0x3f];
            out_index += 1;
        }

        if (i < source.len) {
            dest[out_index] = encoder.alphabet_chars[(source[i] >> 2) & 0x3f];
            out_index += 1;

            if (i + 1 == source.len) {
                dest[out_index] = encoder.alphabet_chars[(source[i] & 0x3) << 4];
                out_index += 1;

                dest[out_index] = encoder.pad_char;
                out_index += 1;
            } else {
                dest[out_index] = encoder.alphabet_chars[((source[i] & 0x3) << 4) | ((source[i + 1] & 0xf0) >> 4)];
                out_index += 1;

                dest[out_index] = encoder.alphabet_chars[(source[i + 1] & 0xf) << 2];
                out_index += 1;
            }

            dest[out_index] = encoder.pad_char;
            out_index += 1;
        }
    }
};

pub const standard_decoder = Base64Decoder.init(standard_alphabet_chars, standard_pad_char);

pub const Base64Decoder = struct {
    /// e.g. 'A' => 0.
    /// undefined for any value not in the 64 alphabet chars.
    char_to_index: [256]u8,

    /// true only for the 64 chars in the alphabet, not the pad char.
    char_in_alphabet: [256]bool,
    pad_char: u8,

    pub fn init(alphabet_chars: []const u8, pad_char: u8) Base64Decoder {
        assert(alphabet_chars.len == 64);

        var result = Base64Decoder{
            .char_to_index = undefined,
            .char_in_alphabet = [_]bool{false} ** 256,
            .pad_char = pad_char,
        };

        for (alphabet_chars) |c, i| {
            assert(!result.char_in_alphabet[c]);
            assert(c != pad_char);

            result.char_to_index[c] = @intCast(u8, i);
            result.char_in_alphabet[c] = true;
        }

        return result;
    }

    /// If the encoded buffer is detected to be invalid, returns error.InvalidPadding.
    pub fn calcSize(decoder: *const Base64Decoder, source: []const u8) !usize {
        if (source.len % 4 != 0) return error.InvalidPadding;
        return calcDecodedSizeExactUnsafe(source, decoder.pad_char);
    }

    /// dest.len must be what you get from ::calcSize.
    /// invalid characters result in error.InvalidCharacter.
    /// invalid padding results in error.InvalidPadding.
    pub fn decode(decoder: *const Base64Decoder, dest: []u8, source: []const u8) !void {
        assert(dest.len == (decoder.calcSize(source) catch unreachable));
        assert(source.len % 4 == 0);

        var src_cursor: usize = 0;
        var dest_cursor: usize = 0;

        while (src_cursor < source.len) : (src_cursor += 4) {
            if (!decoder.char_in_alphabet[source[src_cursor + 0]]) return error.InvalidCharacter;
            if (!decoder.char_in_alphabet[source[src_cursor + 1]]) return error.InvalidCharacter;
            if (src_cursor < source.len - 4 or source[src_cursor + 3] != decoder.pad_char) {
                // common case
                if (!decoder.char_in_alphabet[source[src_cursor + 2]]) return error.InvalidCharacter;
                if (!decoder.char_in_alphabet[source[src_cursor + 3]]) return error.InvalidCharacter;
                dest[dest_cursor + 0] = decoder.char_to_index[source[src_cursor + 0]] << 2 | decoder.char_to_index[source[src_cursor + 1]] >> 4;
                dest[dest_cursor + 1] = decoder.char_to_index[source[src_cursor + 1]] << 4 | decoder.char_to_index[source[src_cursor + 2]] >> 2;
                dest[dest_cursor + 2] = decoder.char_to_index[source[src_cursor + 2]] << 6 | decoder.char_to_index[source[src_cursor + 3]];
                dest_cursor += 3;
            } else if (source[src_cursor + 2] != decoder.pad_char) {
                // one pad char
                if (!decoder.char_in_alphabet[source[src_cursor + 2]]) return error.InvalidCharacter;
                dest[dest_cursor + 0] = decoder.char_to_index[source[src_cursor + 0]] << 2 | decoder.char_to_index[source[src_cursor + 1]] >> 4;
                dest[dest_cursor + 1] = decoder.char_to_index[source[src_cursor + 1]] << 4 | decoder.char_to_index[source[src_cursor + 2]] >> 2;
                if (decoder.char_to_index[source[src_cursor + 2]] << 6 != 0) return error.InvalidPadding;
                dest_cursor += 2;
            } else {
                // two pad chars
                dest[dest_cursor + 0] = decoder.char_to_index[source[src_cursor + 0]] << 2 | decoder.char_to_index[source[src_cursor + 1]] >> 4;
                if (decoder.char_to_index[source[src_cursor + 1]] << 4 != 0) return error.InvalidPadding;
                dest_cursor += 1;
            }
        }

        assert(src_cursor == source.len);
        assert(dest_cursor == dest.len);
    }
};

pub const Base64DecoderWithIgnore = struct {
    decoder: Base64Decoder,
    char_is_ignored: [256]bool,
    pub fn init(alphabet_chars: []const u8, pad_char: u8, ignore_chars: []const u8) Base64DecoderWithIgnore {
        var result = Base64DecoderWithIgnore{
            .decoder = Base64Decoder.init(alphabet_chars, pad_char),
            .char_is_ignored = [_]bool{false} ** 256,
        };

        for (ignore_chars) |c| {
            assert(!result.decoder.char_in_alphabet[c]);
            assert(!result.char_is_ignored[c]);
            assert(result.decoder.pad_char != c);
            result.char_is_ignored[c] = true;
        }

        return result;
    }

    /// If no characters end up being ignored or padding, this will be the exact decoded size.
    pub fn calcSizeUpperBound(encoded_len: usize) usize {
        return @divTrunc(encoded_len, 4) * 3;
    }

    /// Invalid characters that are not ignored result in error.InvalidCharacter.
    /// Invalid padding results in error.InvalidPadding.
    /// Decoding more data than can fit in dest results in error.OutputTooSmall. See also ::calcSizeUpperBound.
    /// Returns the number of bytes written to dest.
    pub fn decode(decoder_with_ignore: *const Base64DecoderWithIgnore, dest: []u8, source: []const u8) !usize {
        const decoder = &decoder_with_ignore.decoder;

        var src_cursor: usize = 0;
        var dest_cursor: usize = 0;

        while (true) {
            // get the next 4 chars, if available
            var next_4_chars: [4]u8 = undefined;
            var available_chars: usize = 0;
            var pad_char_count: usize = 0;
            while (available_chars < 4 and src_cursor < source.len) {
                var c = source[src_cursor];
                src_cursor += 1;

                if (decoder.char_in_alphabet[c]) {
                    // normal char
                    next_4_chars[available_chars] = c;
                    available_chars += 1;
                } else if (decoder_with_ignore.char_is_ignored[c]) {
                    // we're told to skip this one
                    continue;
                } else if (c == decoder.pad_char) {
                    // the padding has begun. count the pad chars.
                    pad_char_count += 1;
                    while (src_cursor < source.len) {
                        c = source[src_cursor];
                        src_cursor += 1;
                        if (c == decoder.pad_char) {
                            pad_char_count += 1;
                            if (pad_char_count > 2) return error.InvalidCharacter;
                        } else if (decoder_with_ignore.char_is_ignored[c]) {
                            // we can even ignore chars during the padding
                            continue;
                        } else
                            return error.InvalidCharacter;
                    }
                    break;
                } else
                    return error.InvalidCharacter;
            }

            switch (available_chars) {
                4 => {
                    // common case
                    if (dest_cursor + 3 > dest.len) return error.OutputTooSmall;
                    assert(pad_char_count == 0);
                    dest[dest_cursor + 0] = decoder.char_to_index[next_4_chars[0]] << 2 | decoder.char_to_index[next_4_chars[1]] >> 4;
                    dest[dest_cursor + 1] = decoder.char_to_index[next_4_chars[1]] << 4 | decoder.char_to_index[next_4_chars[2]] >> 2;
                    dest[dest_cursor + 2] = decoder.char_to_index[next_4_chars[2]] << 6 | decoder.char_to_index[next_4_chars[3]];
                    dest_cursor += 3;
                    continue;
                },
                3 => {
                    if (dest_cursor + 2 > dest.len) return error.OutputTooSmall;
                    if (pad_char_count != 1) return error.InvalidPadding;
                    dest[dest_cursor + 0] = decoder.char_to_index[next_4_chars[0]] << 2 | decoder.char_to_index[next_4_chars[1]] >> 4;
                    dest[dest_cursor + 1] = decoder.char_to_index[next_4_chars[1]] << 4 | decoder.char_to_index[next_4_chars[2]] >> 2;
                    if (decoder.char_to_index[next_4_chars[2]] << 6 != 0) return error.InvalidPadding;
                    dest_cursor += 2;
                    break;
                },
                2 => {
                    if (dest_cursor + 1 > dest.len) return error.OutputTooSmall;
                    if (pad_char_count != 2) return error.InvalidPadding;
                    dest[dest_cursor + 0] = decoder.char_to_index[next_4_chars[0]] << 2 | decoder.char_to_index[next_4_chars[1]] >> 4;
                    if (decoder.char_to_index[next_4_chars[1]] << 4 != 0) return error.InvalidPadding;
                    dest_cursor += 1;
                    break;
                },
                1 => {
                    return error.InvalidPadding;
                },
                0 => {
                    if (pad_char_count != 0) return error.InvalidPadding;
                    break;
                },
                else => unreachable,
            }
        }

        assert(src_cursor == source.len);

        return dest_cursor;
    }
};

pub const standard_decoder_unsafe = Base64DecoderUnsafe.init(standard_alphabet_chars, standard_pad_char);

pub const Base64DecoderUnsafe = struct {
    /// e.g. 'A' => 0.
    /// undefined for any value not in the 64 alphabet chars.
    char_to_index: [256]u8,
    pad_char: u8,

    pub fn init(alphabet_chars: []const u8, pad_char: u8) Base64DecoderUnsafe {
        assert(alphabet_chars.len == 64);
        var result = Base64DecoderUnsafe{
            .char_to_index = undefined,
            .pad_char = pad_char,
        };
        for (alphabet_chars) |c, i| {
            assert(c != pad_char);
            result.char_to_index[c] = @intCast(u8, i);
        }
        return result;
    }

    /// The source buffer must be valid.
    pub fn calcSize(decoder: *const Base64DecoderUnsafe, source: []const u8) usize {
        return calcDecodedSizeExactUnsafe(source, decoder.pad_char);
    }

    /// dest.len must be what you get from ::calcDecodedSizeExactUnsafe.
    /// invalid characters or padding will result in undefined values.
    pub fn decode(decoder: *const Base64DecoderUnsafe, dest: []u8, source: []const u8) void {
        assert(dest.len == decoder.calcSize(source));

        var src_index: usize = 0;
        var dest_index: usize = 0;
        var in_buf_len: usize = source.len;

        while (in_buf_len > 0 and source[in_buf_len - 1] == decoder.pad_char) {
            in_buf_len -= 1;
        }

        while (in_buf_len > 4) {
            dest[dest_index] = decoder.char_to_index[source[src_index + 0]] << 2 | decoder.char_to_index[source[src_index + 1]] >> 4;
            dest_index += 1;

            dest[dest_index] = decoder.char_to_index[source[src_index + 1]] << 4 | decoder.char_to_index[source[src_index + 2]] >> 2;
            dest_index += 1;

            dest[dest_index] = decoder.char_to_index[source[src_index + 2]] << 6 | decoder.char_to_index[source[src_index + 3]];
            dest_index += 1;

            src_index += 4;
            in_buf_len -= 4;
        }

        if (in_buf_len > 1) {
            dest[dest_index] = decoder.char_to_index[source[src_index + 0]] << 2 | decoder.char_to_index[source[src_index + 1]] >> 4;
            dest_index += 1;
        }
        if (in_buf_len > 2) {
            dest[dest_index] = decoder.char_to_index[source[src_index + 1]] << 4 | decoder.char_to_index[source[src_index + 2]] >> 2;
            dest_index += 1;
        }
        if (in_buf_len > 3) {
            dest[dest_index] = decoder.char_to_index[source[src_index + 2]] << 6 | decoder.char_to_index[source[src_index + 3]];
            dest_index += 1;
        }
    }
};

fn calcDecodedSizeExactUnsafe(source: []const u8, pad_char: u8) usize {
    if (source.len == 0) return 0;
    var result = @divExact(source.len, 4) * 3;
    if (source[source.len - 1] == pad_char) {
        result -= 1;
        if (source[source.len - 2] == pad_char) {
            result -= 1;
        }
    }
    return result;
}

test "base64" {
    @setEvalBranchQuota(8000);
    testBase64() catch unreachable;
    comptime (testBase64() catch unreachable);
}

fn testBase64() !void {
    try testAllApis("", "");
    try testAllApis("f", "Zg==");
    try testAllApis("fo", "Zm8=");
    try testAllApis("foo", "Zm9v");
    try testAllApis("foob", "Zm9vYg==");
    try testAllApis("fooba", "Zm9vYmE=");
    try testAllApis("foobar", "Zm9vYmFy");

    try testDecodeIgnoreSpace("", " ");
    try testDecodeIgnoreSpace("f", "Z g= =");
    try testDecodeIgnoreSpace("fo", "    Zm8=");
    try testDecodeIgnoreSpace("foo", "Zm9v    ");
    try testDecodeIgnoreSpace("foob", "Zm9vYg = = ");
    try testDecodeIgnoreSpace("fooba", "Zm9v YmE=");
    try testDecodeIgnoreSpace("foobar", " Z m 9 v Y m F y ");

    // test getting some api errors
    try testError("A", error.InvalidPadding);
    try testError("AA", error.InvalidPadding);
    try testError("AAA", error.InvalidPadding);
    try testError("A..A", error.InvalidCharacter);
    try testError("AA=A", error.InvalidCharacter);
    try testError("AA/=", error.InvalidPadding);
    try testError("A/==", error.InvalidPadding);
    try testError("A===", error.InvalidCharacter);
    try testError("====", error.InvalidCharacter);

    try testOutputTooSmallError("AA==");
    try testOutputTooSmallError("AAA=");
    try testOutputTooSmallError("AAAA");
    try testOutputTooSmallError("AAAAAA==");
}

fn testAllApis(expected_decoded: []const u8, expected_encoded: []const u8) !void {
    // Base64Encoder
    {
        var buffer: [0x100]u8 = undefined;
        var encoded = buffer[0..Base64Encoder.calcSize(expected_decoded.len)];
        standard_encoder.encode(encoded, expected_decoded);
        testing.expectEqualSlices(u8, expected_encoded, encoded);
    }

    // Base64Decoder
    {
        var buffer: [0x100]u8 = undefined;
        var decoded = buffer[0..try standard_decoder.calcSize(expected_encoded)];
        try standard_decoder.decode(decoded, expected_encoded);
        testing.expectEqualSlices(u8, expected_decoded, decoded);
    }

    // Base64DecoderWithIgnore
    {
        const standard_decoder_ignore_nothing = Base64DecoderWithIgnore.init(standard_alphabet_chars, standard_pad_char, "");
        var buffer: [0x100]u8 = undefined;
        var decoded = buffer[0..Base64DecoderWithIgnore.calcSizeUpperBound(expected_encoded.len)];
        var written = try standard_decoder_ignore_nothing.decode(decoded, expected_encoded);
        testing.expect(written <= decoded.len);
        testing.expectEqualSlices(u8, expected_decoded, decoded[0..written]);
    }

    // Base64DecoderUnsafe
    {
        var buffer: [0x100]u8 = undefined;
        var decoded = buffer[0..standard_decoder_unsafe.calcSize(expected_encoded)];
        standard_decoder_unsafe.decode(decoded, expected_encoded);
        testing.expectEqualSlices(u8, expected_decoded, decoded);
    }
}

fn testDecodeIgnoreSpace(expected_decoded: []const u8, encoded: []const u8) !void {
    const standard_decoder_ignore_space = Base64DecoderWithIgnore.init(standard_alphabet_chars, standard_pad_char, " ");
    var buffer: [0x100]u8 = undefined;
    var decoded = buffer[0..Base64DecoderWithIgnore.calcSizeUpperBound(encoded.len)];
    var written = try standard_decoder_ignore_space.decode(decoded, encoded);
    testing.expectEqualSlices(u8, expected_decoded, decoded[0..written]);
}

fn testError(encoded: []const u8, expected_err: anyerror) !void {
    const standard_decoder_ignore_space = Base64DecoderWithIgnore.init(standard_alphabet_chars, standard_pad_char, " ");
    var buffer: [0x100]u8 = undefined;
    if (standard_decoder.calcSize(encoded)) |decoded_size| {
        var decoded = buffer[0..decoded_size];
        if (standard_decoder.decode(decoded, encoded)) |_| {
            return error.ExpectedError;
        } else |err| if (err != expected_err) return err;
    } else |err| if (err != expected_err) return err;

    if (standard_decoder_ignore_space.decode(buffer[0..], encoded)) |_| {
        return error.ExpectedError;
    } else |err| if (err != expected_err) return err;
}

fn testOutputTooSmallError(encoded: []const u8) !void {
    const standard_decoder_ignore_space = Base64DecoderWithIgnore.init(standard_alphabet_chars, standard_pad_char, " ");
    var buffer: [0x100]u8 = undefined;
    var decoded = buffer[0 .. calcDecodedSizeExactUnsafe(encoded, standard_pad_char) - 1];
    if (standard_decoder_ignore_space.decode(decoded, encoded)) |_| {
        return error.ExpectedError;
    } else |err| if (err != error.OutputTooSmall) return err;
}
