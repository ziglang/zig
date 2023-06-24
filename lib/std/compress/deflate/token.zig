// 2 bits: type, can be 0 (literal), 1 (EOF), 2 (Match) or 3 (Unused).
// 8 bits: xlength (length - MIN_MATCH_LENGTH).
// 22 bits: xoffset (offset - MIN_OFFSET_SIZE), or literal.
const length_shift = 22;
const offset_mask = (1 << length_shift) - 1; // 4_194_303
const literal_type = 0 << 30; // 0
pub const match_type = 1 << 30; // 1_073_741_824

// The length code for length X (MIN_MATCH_LENGTH <= X <= MAX_MATCH_LENGTH)
// is length_codes[length - MIN_MATCH_LENGTH]
var length_codes = [_]u32{
    0,  1,  2,  3,  4,  5,  6,  7,  8,  8,
    9,  9,  10, 10, 11, 11, 12, 12, 12, 12,
    13, 13, 13, 13, 14, 14, 14, 14, 15, 15,
    15, 15, 16, 16, 16, 16, 16, 16, 16, 16,
    17, 17, 17, 17, 17, 17, 17, 17, 18, 18,
    18, 18, 18, 18, 18, 18, 19, 19, 19, 19,
    19, 19, 19, 19, 20, 20, 20, 20, 20, 20,
    20, 20, 20, 20, 20, 20, 20, 20, 20, 20,
    21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
    21, 21, 21, 21, 21, 21, 22, 22, 22, 22,
    22, 22, 22, 22, 22, 22, 22, 22, 22, 22,
    22, 22, 23, 23, 23, 23, 23, 23, 23, 23,
    23, 23, 23, 23, 23, 23, 23, 23, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24, 24, 24,
    25, 25, 25, 25, 25, 25, 25, 25, 25, 25,
    25, 25, 25, 25, 25, 25, 25, 25, 25, 25,
    25, 25, 25, 25, 25, 25, 25, 25, 25, 25,
    25, 25, 26, 26, 26, 26, 26, 26, 26, 26,
    26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
    26, 26, 26, 26, 26, 26, 26, 26, 26, 26,
    26, 26, 26, 26, 27, 27, 27, 27, 27, 27,
    27, 27, 27, 27, 27, 27, 27, 27, 27, 27,
    27, 27, 27, 27, 27, 27, 27, 27, 27, 27,
    27, 27, 27, 27, 27, 28,
};

var offset_codes = [_]u32{
    0,  1,  2,  3,  4,  4,  5,  5,  6,  6,  6,  6,  7,  7,  7,  7,
    8,  8,  8,  8,  8,  8,  8,  8,  9,  9,  9,  9,  9,  9,  9,  9,
    10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10,
    11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11, 11,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
    13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13, 13,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14, 14,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
    15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15, 15,
};

pub const Token = u32;

// Convert a literal into a literal token.
pub fn literalToken(lit: u32) Token {
    return literal_type + lit;
}

// Convert a < xlength, xoffset > pair into a match token.
pub fn matchToken(xlength: u32, xoffset: u32) Token {
    return match_type + (xlength << length_shift) + xoffset;
}

// Returns the literal of a literal token
pub fn literal(t: Token) u32 {
    return @as(u32, @intCast(t - literal_type));
}

// Returns the extra offset of a match token
pub fn offset(t: Token) u32 {
    return @as(u32, @intCast(t)) & offset_mask;
}

pub fn length(t: Token) u32 {
    return @as(u32, @intCast((t - match_type) >> length_shift));
}

pub fn lengthCode(len: u32) u32 {
    return length_codes[len];
}

// Returns the offset code corresponding to a specific offset
pub fn offsetCode(off: u32) u32 {
    if (off < @as(u32, @intCast(offset_codes.len))) {
        return offset_codes[off];
    }
    if (off >> 7 < @as(u32, @intCast(offset_codes.len))) {
        return offset_codes[off >> 7] + 14;
    }
    return offset_codes[off >> 14] + 28;
}

test {
    const std = @import("std");
    try std.testing.expectEqual(@as(Token, 3_401_581_099), matchToken(555, 555));
}
