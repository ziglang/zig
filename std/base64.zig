const assert = @import("debug.zig").assert;
const mem = @import("mem.zig");

pub const standard_alphabet_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
pub const standard_pad_char = '=';

/// ceil(source_len * 4/3)
pub fn calcEncodedSize(source_len: usize) -> usize {
    return @divTrunc(source_len + 2, 3) * 4;
}

/// dest.len must be what you get from ::calcEncodedSize.
/// It is assumed that alphabet_chars and pad_char are all unique characters.
pub fn encode(dest: []u8, source: []const u8, alphabet_chars: []const u8, pad_char: u8) {
    assert(alphabet_chars.len == 64);
    assert(dest.len == calcEncodedSize(source.len));

    var i: usize = 0;
    var out_index: usize = 0;
    while (i + 2 < source.len) : (i += 3) {
        dest[out_index] = alphabet_chars[(source[i] >> 2) & 0x3f];
        out_index += 1;

        dest[out_index] = alphabet_chars[((source[i] & 0x3) << 4) |
                          ((source[i + 1] & 0xf0) >> 4)];
        out_index += 1;

        dest[out_index] = alphabet_chars[((source[i + 1] & 0xf) << 2) |
                          ((source[i + 2] & 0xc0) >> 6)];
        out_index += 1;

        dest[out_index] = alphabet_chars[source[i + 2] & 0x3f];
        out_index += 1;
    }

    if (i < source.len) {
        dest[out_index] = alphabet_chars[(source[i] >> 2) & 0x3f];
        out_index += 1;

        if (i + 1 == source.len) {
            dest[out_index] = alphabet_chars[(source[i] & 0x3) << 4];
            out_index += 1;

            dest[out_index] = pad_char;
            out_index += 1;
        } else {
            dest[out_index] = alphabet_chars[((source[i] & 0x3) << 4) |
                              ((source[i + 1] & 0xf0) >> 4)];
            out_index += 1;

            dest[out_index] = alphabet_chars[(source[i + 1] & 0xf) << 2];
            out_index += 1;
        }

        dest[out_index] = pad_char;
        out_index += 1;
    }
}

pub const standard_alphabet = Base64Alphabet.init(standard_alphabet_chars, standard_pad_char);

/// For use with ::decodeExact.
pub const Base64Alphabet = struct {
    /// e.g. 'A' => 0.
    /// undefined for any value not in the 64 alphabet chars.
    char_to_index: [256]u8,
    /// true only for the 64 chars in the alphabet, not the pad char.
    char_in_alphabet: [256]bool,
    pad_char: u8,

    pub fn init(alphabet_chars: []const u8, pad_char: u8) -> Base64Alphabet {
        assert(alphabet_chars.len == 64);

        var result = Base64Alphabet{
            .char_to_index = undefined,
            .char_in_alphabet = []bool{false} ** 256,
            .pad_char = pad_char,
        };

        for (alphabet_chars) |c, i| {
            assert(!result.char_in_alphabet[c]);
            assert(c != pad_char);

            result.char_to_index[c] = u8(i);
            result.char_in_alphabet[c] = true;
        }

        return result;
    }
};

error InvalidPadding;
/// For use with ::decodeExact.
/// If the encoded buffer is detected to be invalid, returns error.InvalidPadding.
pub fn calcDecodedSizeExact(encoded: []const u8, pad_char: u8) -> %usize {
    if (encoded.len % 4 != 0) return error.InvalidPadding;
    return calcDecodedSizeExactUnsafe(encoded, pad_char);
}

error InvalidCharacter;
/// dest.len must be what you get from ::calcDecodedSizeExact.
/// invalid characters result in error.InvalidCharacter.
/// invalid padding results in error.InvalidPadding.
pub fn decodeExact(dest: []u8, source: []const u8, alphabet: &const Base64Alphabet) -> %void {
    assert(dest.len == %%calcDecodedSizeExact(source, alphabet.pad_char));
    assert(source.len % 4 == 0);

    var src_cursor: usize = 0;
    var dest_cursor: usize = 0;

    while (src_cursor < source.len) : (src_cursor += 4) {
        if (!alphabet.char_in_alphabet[source[src_cursor + 0]]) return error.InvalidCharacter;
        if (!alphabet.char_in_alphabet[source[src_cursor + 1]]) return error.InvalidCharacter;
        if (src_cursor < source.len - 4 or source[src_cursor + 3] != alphabet.pad_char) {
            // common case
            if (!alphabet.char_in_alphabet[source[src_cursor + 2]]) return error.InvalidCharacter;
            if (!alphabet.char_in_alphabet[source[src_cursor + 3]]) return error.InvalidCharacter;
            dest[dest_cursor + 0] = alphabet.char_to_index[source[src_cursor + 0]] << 2 |
                                    alphabet.char_to_index[source[src_cursor + 1]] >> 4;
            dest[dest_cursor + 1] = alphabet.char_to_index[source[src_cursor + 1]] << 4 |
                                    alphabet.char_to_index[source[src_cursor + 2]] >> 2;
            dest[dest_cursor + 2] = alphabet.char_to_index[source[src_cursor + 2]] << 6 |
                                    alphabet.char_to_index[source[src_cursor + 3]];
            dest_cursor += 3;
        } else if (source[src_cursor + 2] != alphabet.pad_char) {
            // one pad char
            if (!alphabet.char_in_alphabet[source[src_cursor + 2]]) return error.InvalidCharacter;
            dest[dest_cursor + 0] = alphabet.char_to_index[source[src_cursor + 0]] << 2 |
                                    alphabet.char_to_index[source[src_cursor + 1]] >> 4;
            dest[dest_cursor + 1] = alphabet.char_to_index[source[src_cursor + 1]] << 4 |
                                    alphabet.char_to_index[source[src_cursor + 2]] >> 2;
            if (alphabet.char_to_index[source[src_cursor + 2]] << 6 != 0) return error.InvalidPadding;
            dest_cursor += 2;
        } else {
            // two pad chars
            dest[dest_cursor + 0] = alphabet.char_to_index[source[src_cursor + 0]] << 2 |
                                    alphabet.char_to_index[source[src_cursor + 1]] >> 4;
            if (alphabet.char_to_index[source[src_cursor + 1]] << 4 != 0) return error.InvalidPadding;
            dest_cursor += 1;
        }
    }

    assert(src_cursor == source.len);
    assert(dest_cursor == dest.len);
}

/// For use with ::decodeWithIgnore.
pub const Base64AlphabetWithIgnore = struct {
    alphabet: Base64Alphabet,
    char_is_ignored: [256]bool,
    pub fn init(alphabet_chars: []const u8, pad_char: u8, ignore_chars: []const u8) -> Base64AlphabetWithIgnore {
        var result = Base64AlphabetWithIgnore {
            .alphabet = Base64Alphabet.init(alphabet_chars, pad_char),
            .char_is_ignored = []bool{false} ** 256,
        };

        for (ignore_chars) |c| {
            assert(!result.alphabet.char_in_alphabet[c]);
            assert(!result.char_is_ignored[c]);
            assert(result.alphabet.pad_char != c);
            result.char_is_ignored[c] = true;
        }

        return result;
    }
};

/// For use with ::decodeWithIgnore.
/// If no characters end up being ignored, this will be the exact decoded size.
pub fn calcDecodedSizeUpperBound(encoded_len: usize) -> %usize {
    return @divTrunc(encoded_len, 4) * 3;
}

error OutputTooSmall;
/// Invalid characters that are not ignored results in error.InvalidCharacter.
/// Invalid padding results in error.InvalidPadding.
/// Decoding more data than can fit in dest results in error.OutputTooSmall. See also ::calcDecodedSizeUpperBound.
/// Returns the number of bytes writen to dest.
pub fn decodeWithIgnore(dest: []u8, source: []const u8, alphabet_with_ignore: &const Base64AlphabetWithIgnore) -> %usize {
    const alphabet = &const alphabet_with_ignore.alphabet;

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

            if (alphabet.char_in_alphabet[c]) {
                // normal char
                next_4_chars[available_chars] = c;
                available_chars += 1;
            } else if (alphabet_with_ignore.char_is_ignored[c]) {
                // we're told to skip this one
                continue;
            } else if (c == alphabet.pad_char) {
                // the padding has begun. count the pad chars.
                pad_char_count += 1;
                while (src_cursor < source.len) {
                    c = source[src_cursor];
                    src_cursor += 1;
                    if (c == alphabet.pad_char) {
                        pad_char_count += 1;
                        if (pad_char_count > 2) return error.InvalidCharacter;
                    } else if (alphabet_with_ignore.char_is_ignored[c]) {
                        // we can even ignore chars during the padding
                        continue;
                    } else return error.InvalidCharacter;
                }
                break;
            } else return error.InvalidCharacter;
        }

        switch (available_chars) {
            4 => {
                // common case
                if (dest_cursor + 3 > dest.len) return error.OutputTooSmall;
                assert(pad_char_count == 0);
                dest[dest_cursor + 0] = alphabet.char_to_index[next_4_chars[0]] << 2 |
                                        alphabet.char_to_index[next_4_chars[1]] >> 4;
                dest[dest_cursor + 1] = alphabet.char_to_index[next_4_chars[1]] << 4 |
                                        alphabet.char_to_index[next_4_chars[2]] >> 2;
                dest[dest_cursor + 2] = alphabet.char_to_index[next_4_chars[2]] << 6 |
                                        alphabet.char_to_index[next_4_chars[3]];
                dest_cursor += 3;
                continue;
            },
            3 => {
                if (dest_cursor + 2 > dest.len) return error.OutputTooSmall;
                if (pad_char_count != 1) return error.InvalidPadding;
                dest[dest_cursor + 0] = alphabet.char_to_index[next_4_chars[0]] << 2 |
                                        alphabet.char_to_index[next_4_chars[1]] >> 4;
                dest[dest_cursor + 1] = alphabet.char_to_index[next_4_chars[1]] << 4 |
                                        alphabet.char_to_index[next_4_chars[2]] >> 2;
                if (alphabet.char_to_index[next_4_chars[2]] << 6 != 0) return error.InvalidPadding;
                dest_cursor += 2;
                break;
            },
            2 => {
                if (dest_cursor + 1 > dest.len) return error.OutputTooSmall;
                if (pad_char_count != 2) return error.InvalidPadding;
                dest[dest_cursor + 0] = alphabet.char_to_index[next_4_chars[0]] << 2 |
                                        alphabet.char_to_index[next_4_chars[1]] >> 4;
                if (alphabet.char_to_index[next_4_chars[1]] << 4 != 0) return error.InvalidPadding;
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

pub const standard_alphabet_unsafe = Base64AlphabetUnsafe.init(standard_alphabet_chars, standard_pad_char);

/// For use with ::decodeExactUnsafe.
pub const Base64AlphabetUnsafe = struct {
    /// e.g. 'A' => 0.
    /// undefined for any value not in the 64 alphabet chars.
    char_to_index: [256]u8,
    pad_char: u8,

    pub fn init(alphabet_chars: []const u8, pad_char: u8) -> Base64AlphabetUnsafe {
        assert(alphabet_chars.len == 64);
        var result = Base64AlphabetUnsafe {
            .char_to_index = undefined,
            .pad_char = pad_char,
        };
        for (alphabet_chars) |c, i| {
            assert(c != pad_char);
            result.char_to_index[c] = u8(i);
        }
        return result;
    }
};

/// For use with ::decodeExactUnsafe.
/// The encoded buffer must be valid.
pub fn calcDecodedSizeExactUnsafe(encoded: []const u8, pad_char: u8) -> usize {
    if (encoded.len == 0) return 0;
    var result = @divExact(encoded.len, 4) * 3;
    if (encoded[encoded.len - 1] == pad_char) {
        result -= 1;
        if (encoded[encoded.len - 2] == pad_char) {
            result -= 1;
        }
    }
    return result;
}

/// dest.len must be what you get from ::calcDecodedSizeExactUnsafe.
/// invalid characters or padding will result in undefined values.
pub fn decodeExactUnsafe(dest: []u8, source: []const u8, alphabet: &const Base64AlphabetUnsafe) {
    assert(dest.len == calcDecodedSizeExactUnsafe(source, alphabet.pad_char));

    var src_index: usize = 0;
    var dest_index: usize = 0;
    var in_buf_len: usize = source.len;

    while (in_buf_len > 0 and source[in_buf_len - 1] == alphabet.pad_char) {
        in_buf_len -= 1;
    }

    while (in_buf_len > 4) {
        dest[dest_index] = alphabet.char_to_index[source[src_index + 0]] << 2 |
                           alphabet.char_to_index[source[src_index + 1]] >> 4;
        dest_index += 1;

        dest[dest_index] = alphabet.char_to_index[source[src_index + 1]] << 4 |
                           alphabet.char_to_index[source[src_index + 2]] >> 2;
        dest_index += 1;

        dest[dest_index] = alphabet.char_to_index[source[src_index + 2]] << 6 |
                           alphabet.char_to_index[source[src_index + 3]];
        dest_index += 1;

        src_index += 4;
        in_buf_len -= 4;
    }

    if (in_buf_len > 1) {
        dest[dest_index] = alphabet.char_to_index[source[src_index + 0]] << 2 |
                           alphabet.char_to_index[source[src_index + 1]] >> 4;
        dest_index += 1;
    }
    if (in_buf_len > 2) {
        dest[dest_index] = alphabet.char_to_index[source[src_index + 1]] << 4 |
                           alphabet.char_to_index[source[src_index + 2]] >> 2;
        dest_index += 1;
    }
    if (in_buf_len > 3) {
        dest[dest_index] = alphabet.char_to_index[source[src_index + 2]] << 6 |
                           alphabet.char_to_index[source[src_index + 3]];
        dest_index += 1;
    }
}

test "base64" {
    @setEvalBranchQuota(5000);
    %%testBase64();
    comptime %%testBase64();
}

fn testBase64() -> %void {
    %return testAllApis("",       "");
    %return testAllApis("f",      "Zg==");
    %return testAllApis("fo",     "Zm8=");
    %return testAllApis("foo",    "Zm9v");
    %return testAllApis("foob",   "Zm9vYg==");
    %return testAllApis("fooba",  "Zm9vYmE=");
    %return testAllApis("foobar", "Zm9vYmFy");

    %return testDecodeIgnoreSpace("",       " ");
    %return testDecodeIgnoreSpace("f",      "Z g= =");
    %return testDecodeIgnoreSpace("fo",     "    Zm8=");
    %return testDecodeIgnoreSpace("foo",    "Zm9v    ");
    %return testDecodeIgnoreSpace("foob",   "Zm9vYg = = ");
    %return testDecodeIgnoreSpace("fooba",  "Zm9v YmE=");
    %return testDecodeIgnoreSpace("foobar", " Z m 9 v Y m F y ");

    // test getting some api errors
    %return testError("A",    error.InvalidPadding);
    %return testError("AA",   error.InvalidPadding);
    %return testError("AAA",  error.InvalidPadding);
    %return testError("A..A", error.InvalidCharacter);
    %return testError("AA=A", error.InvalidCharacter);
    %return testError("AA/=", error.InvalidPadding);
    %return testError("A/==", error.InvalidPadding);
    %return testError("A===", error.InvalidCharacter);
    %return testError("====", error.InvalidCharacter);

    %return testOutputTooSmallError("AA==");
    %return testOutputTooSmallError("AAA=");
    %return testOutputTooSmallError("AAAA");
    %return testOutputTooSmallError("AAAAAA==");
}

fn testAllApis(expected_decoded: []const u8, expected_encoded: []const u8) -> %void {
    // encode
    {
        var buffer: [0x100]u8 = undefined;
        var encoded = buffer[0..calcEncodedSize(expected_decoded.len)];
        encode(encoded, expected_decoded, standard_alphabet_chars, standard_pad_char);
        assert(mem.eql(u8, encoded, expected_encoded));
    }

    // decodeExact
    {
        var buffer: [0x100]u8 = undefined;
        var decoded = buffer[0..%return calcDecodedSizeExact(expected_encoded, standard_pad_char)];
        %return decodeExact(decoded, expected_encoded, standard_alphabet);
        assert(mem.eql(u8, decoded, expected_decoded));
    }

    // decodeWithIgnore
    {
        const standard_alphabet_ignore_nothing = Base64AlphabetWithIgnore.init(
            standard_alphabet_chars, standard_pad_char, "");
        var buffer: [0x100]u8 = undefined;
        var decoded = buffer[0..%return calcDecodedSizeUpperBound(expected_encoded.len)];
        var written = %return decodeWithIgnore(decoded, expected_encoded, standard_alphabet_ignore_nothing);
        assert(written <= decoded.len);
        assert(mem.eql(u8, decoded[0..written], expected_decoded));
    }

    // decodeExactUnsafe
    {
        var buffer: [0x100]u8 = undefined;
        var decoded = buffer[0..calcDecodedSizeExactUnsafe(expected_encoded, standard_pad_char)];
        decodeExactUnsafe(decoded, expected_encoded, standard_alphabet_unsafe);
        assert(mem.eql(u8, decoded, expected_decoded));
    }
}

fn testDecodeIgnoreSpace(expected_decoded: []const u8, encoded: []const u8) -> %void {
    const standard_alphabet_ignore_space = Base64AlphabetWithIgnore.init(
        standard_alphabet_chars, standard_pad_char, " ");
    var buffer: [0x100]u8 = undefined;
    var decoded = buffer[0..%return calcDecodedSizeUpperBound(encoded.len)];
    var written = %return decodeWithIgnore(decoded, encoded, standard_alphabet_ignore_space);
    assert(mem.eql(u8, decoded[0..written], expected_decoded));
}

error ExpectedError;
fn testError(encoded: []const u8, expected_err: error) -> %void {
    const standard_alphabet_ignore_space = Base64AlphabetWithIgnore.init(
        standard_alphabet_chars, standard_pad_char, " ");
    var buffer: [0x100]u8 = undefined;
    if (calcDecodedSizeExact(encoded, standard_pad_char)) |decoded_size| {
        var decoded = buffer[0..decoded_size];
        if (decodeExact(decoded, encoded, standard_alphabet)) |_| {
            return error.ExpectedError;
        } else |err| if (err != expected_err) return err;
    } else |err| if (err != expected_err) return err;

    if (decodeWithIgnore(buffer[0..], encoded, standard_alphabet_ignore_space)) |_| {
        return error.ExpectedError;
    } else |err| if (err != expected_err) return err;
}

fn testOutputTooSmallError(encoded: []const u8) -> %void {
    const standard_alphabet_ignore_space = Base64AlphabetWithIgnore.init(
        standard_alphabet_chars, standard_pad_char, " ");
    var buffer: [0x100]u8 = undefined;
    var decoded = buffer[0..calcDecodedSizeExactUnsafe(encoded, standard_pad_char) - 1];
    if (decodeWithIgnore(decoded, encoded, standard_alphabet_ignore_space)) |_| {
        return error.ExpectedError;
    } else |err| if (err != error.OutputTooSmall) return err;
}
