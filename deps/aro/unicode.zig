//! Copied from https://github.com/ziglang/zig/blob/6f0807f50f4e946bb850e746beaa5d6556cf7750/lib/std/unicode.zig
//! with all safety checks removed. These functions must only be called with known-good buffers that have already
//! been validated as being legitimate UTF8-encoded data, otherwise undefined behavior will occur.

pub fn utf8ByteSequenceLength_unsafe(first_byte: u8) u3 {
    return switch (first_byte) {
        0b0000_0000...0b0111_1111 => 1,
        0b1100_0000...0b1101_1111 => 2,
        0b1110_0000...0b1110_1111 => 3,
        0b1111_0000...0b1111_0111 => 4,
        else => unreachable,
    };
}

pub fn utf8Decode2_unsafe(bytes: []const u8) u21 {
    var value: u21 = bytes[0] & 0b00011111;
    value <<= 6;
    return value | (bytes[1] & 0b00111111);
}

pub fn utf8Decode3_unsafe(bytes: []const u8) u21 {
    var value: u21 = bytes[0] & 0b00001111;

    value <<= 6;
    value |= bytes[1] & 0b00111111;

    value <<= 6;
    return value | (bytes[2] & 0b00111111);
}

pub fn utf8Decode4_unsafe(bytes: []const u8) u21 {
    var value: u21 = bytes[0] & 0b00000111;
    value <<= 6;
    value |= bytes[1] & 0b00111111;

    value <<= 6;
    value |= bytes[2] & 0b00111111;

    value <<= 6;
    return value | (bytes[3] & 0b00111111);
}
