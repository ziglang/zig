const assert = @import("debug.zig").assert;
const mem = @import("mem.zig");

pub const standard_alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

pub fn encode(dest: []u8, source: []const u8) -> []u8 {
    return encodeWithAlphabet(dest, source, standard_alphabet);
}

pub fn decode(dest: []u8, source: []const u8) -> []u8 {
    return decodeWithAlphabet(dest, source, standard_alphabet);
}

pub fn encodeWithAlphabet(dest: []u8, source: []const u8, alphabet: []const u8) -> []u8 {
    assert(alphabet.len == 65);
    assert(dest.len >= calcEncodedSize(source.len));

    var i: usize = 0;
    var out_index: usize = 0;
    while (i + 2 < source.len) : (i += 3) {
        dest[out_index] = alphabet[(source[i] >> 2) & 0x3f];
        out_index += 1;

        dest[out_index] = alphabet[((source[i] & 0x3) <<% 4) |
                          ((source[i + 1] & 0xf0) >> 4)];
        out_index += 1;

        dest[out_index] = alphabet[((source[i + 1] & 0xf) <<% 2) |
                          ((source[i + 2] & 0xc0) >> 6)];
        out_index += 1;

        dest[out_index] = alphabet[source[i + 2] & 0x3f];
        out_index += 1;
    }

    if (i < source.len) {
        dest[out_index] = alphabet[(source[i] >> 2) & 0x3f];
        out_index += 1;

        if (i + 1 == source.len) {
            dest[out_index] = alphabet[(source[i] & 0x3) <<% 4];
            out_index += 1;

            dest[out_index] = alphabet[64];
            out_index += 1;
        } else {
            dest[out_index] = alphabet[((source[i] & 0x3) <<% 4) |
                              ((source[i + 1] & 0xf0) >> 4)];
            out_index += 1;

            dest[out_index] = alphabet[(source[i + 1] & 0xf) <<% 2];
            out_index += 1;
        }

        dest[out_index] = alphabet[64];
        out_index += 1;
    }

    return dest[0...out_index];
}

pub fn decodeWithAlphabet(dest: []u8, source: []const u8, alphabet: []const u8) -> []u8 {
    assert(alphabet.len == 65);

    var ascii6 = []u8{64} ** 256;
    for (alphabet) |c, i| {
        ascii6[c] = u8(i);
    }

    return decodeWithAscii6BitMap(dest, source, ascii6[0...], alphabet[64]);
}

pub fn decodeWithAscii6BitMap(dest: []u8, source: []const u8, ascii6: []const u8, pad_char: u8) -> []u8 {
    assert(ascii6.len == 256);
    assert(dest.len >= calcExactDecodedSizeWithPadChar(source, pad_char));

    var src_index: usize = 0;
    var dest_index: usize = 0;
    var in_buf_len: usize = source.len;

    while (in_buf_len > 0 and source[in_buf_len - 1] == pad_char) {
        in_buf_len -= 1;
    }

    while (in_buf_len > 4) {
        dest[dest_index] = ascii6[source[src_index + 0]] <<% 2 |
                   ascii6[source[src_index + 1]] >> 4;
        dest_index += 1;

        dest[dest_index] = ascii6[source[src_index + 1]] <<% 4 |
                   ascii6[source[src_index + 2]] >> 2;
        dest_index += 1;

        dest[dest_index] = ascii6[source[src_index + 2]] <<% 6 |
                   ascii6[source[src_index + 3]];
        dest_index += 1;

        src_index += 4;
        in_buf_len -= 4;
    }

    if (in_buf_len > 1) {
        dest[dest_index] = ascii6[source[src_index + 0]] <<% 2 |
                   ascii6[source[src_index + 1]] >> 4;
        dest_index += 1;
    }
    if (in_buf_len > 2) {
        dest[dest_index] = ascii6[source[src_index + 1]] <<% 4 |
                   ascii6[source[src_index + 2]] >> 2;
        dest_index += 1;
    }
    if (in_buf_len > 3) {
        dest[dest_index] = ascii6[source[src_index + 2]] <<% 6 |
                   ascii6[source[src_index + 3]];
        dest_index += 1;
    }

    return dest[0...dest_index];
}

pub fn calcEncodedSize(source_len: usize) -> usize {
    return (((source_len * 4) / 3 + 3) / 4) * 4;
}

/// Computes the upper bound of the decoded size based only on the encoded length.
/// To compute the exact decoded size, see ::calcExactDecodedSize
pub fn calcMaxDecodedSize(encoded_len: usize) -> usize {
    return @divExact(encoded_len * 3,  4);
}

/// Computes the number of decoded bytes there will be. This function must
/// be given the encoded buffer because there might be padding
/// bytes at the end ('=' in the standard alphabet)
pub fn calcExactDecodedSize(encoded: []const u8) -> usize {
    return calcExactDecodedSizeWithAlphabet(encoded, standard_alphabet);
}

pub fn calcExactDecodedSizeWithAlphabet(encoded: []const u8, alphabet: []const u8) -> usize {
    assert(alphabet.len == 65);
    return calcExactDecodedSizeWithPadChar(encoded, alphabet[64]);
}

pub fn calcExactDecodedSizeWithPadChar(encoded: []const u8, pad_char: u8) -> usize {
    var buf_len = encoded.len;

    while (buf_len > 0 and encoded[buf_len - 1] == pad_char) {
        buf_len -= 1;
    }

    return (buf_len * 3) / 4;
}

test "base64" {
    testBase64();
    comptime testBase64();
}

fn testBase64() {
    testBase64Case("", "");
    testBase64Case("f", "Zg==");
    testBase64Case("fo", "Zm8=");
    testBase64Case("foo", "Zm9v");
    testBase64Case("foob", "Zm9vYg==");
    testBase64Case("fooba", "Zm9vYmE=");
    testBase64Case("foobar", "Zm9vYmFy");
}

fn testBase64Case(expected_decoded: []const u8, expected_encoded: []const u8) {
    const calculated_decoded_len = calcExactDecodedSize(expected_encoded);
    assert(calculated_decoded_len == expected_decoded.len);

    const calculated_encoded_len = calcEncodedSize(expected_decoded.len);
    assert(calculated_encoded_len == expected_encoded.len);

    var buf: [100]u8 = undefined;

    const actual_decoded = decode(buf[0...], expected_encoded);
    assert(actual_decoded.len == expected_decoded.len);
    assert(mem.eql(u8, expected_decoded, actual_decoded));

    const actual_encoded = encode(buf[0...], expected_decoded);
    assert(actual_encoded.len == expected_encoded.len);
    assert(mem.eql(u8, expected_encoded, actual_encoded));
}
