//! Token cat be literal: single byte of data or match; reference to the slice of
//! data in the same stream represented with <length, distance>. Where length
//! can be 3 - 258 bytes, and distance 1 - 32768 bytes.
//!
const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const expect = std.testing.expect;
const consts = @import("consts.zig").match;

const Token = @This();

pub const Kind = enum(u1) {
    literal,
    match,
};

// Distance range 1 - 32768, stored in dist as 0 - 32767 (fits u15)
dist: u15 = 0,
// Length range 3 - 258, stored in len_lit as 0 - 255 (fits u8)
len_lit: u8 = 0,
kind: Kind = .literal,

pub fn literal(t: Token) u8 {
    return t.len_lit;
}

pub fn distance(t: Token) u16 {
    return @as(u16, t.dist) + consts.min_distance;
}

pub fn length(t: Token) u16 {
    return @as(u16, t.len_lit) + consts.base_length;
}

pub fn initLiteral(lit: u8) Token {
    return .{ .kind = .literal, .len_lit = lit };
}

// distance range 1 - 32768, stored in dist as 0 - 32767 (u15)
// length range 3 - 258, stored in len_lit as 0 - 255 (u8)
pub fn initMatch(dist: u16, len: u16) Token {
    assert(len >= consts.min_length and len <= consts.max_length);
    assert(dist >= consts.min_distance and dist <= consts.max_distance);
    return .{
        .kind = .match,
        .dist = @intCast(dist - consts.min_distance),
        .len_lit = @intCast(len - consts.base_length),
    };
}

pub fn eql(t: Token, o: Token) bool {
    return t.kind == o.kind and
        t.dist == o.dist and
        t.len_lit == o.len_lit;
}

pub fn lengthCode(t: Token) u16 {
    return match_lengths[match_lengths_index[t.len_lit]].code;
}

pub fn lengthEncoding(t: Token) MatchLength {
    var c = match_lengths[match_lengths_index[t.len_lit]];
    c.extra_length = t.len_lit - c.base_scaled;
    return c;
}

// Returns the distance code corresponding to a specific distance.
// Distance code is in range: 0 - 29.
pub fn distanceCode(t: Token) u8 {
    var dist: u16 = t.dist;
    if (dist < match_distances_index.len) {
        return match_distances_index[dist];
    }
    dist >>= 7;
    if (dist < match_distances_index.len) {
        return match_distances_index[dist] + 14;
    }
    dist >>= 7;
    return match_distances_index[dist] + 28;
}

pub fn distanceEncoding(t: Token) MatchDistance {
    var c = match_distances[t.distanceCode()];
    c.extra_distance = t.dist - c.base_scaled;
    return c;
}

pub fn lengthExtraBits(code: u32) u8 {
    return match_lengths[code - length_codes_start].extra_bits;
}

pub fn matchLength(code: u8) MatchLength {
    return match_lengths[code];
}

pub fn matchDistance(code: u8) MatchDistance {
    return match_distances[code];
}

pub fn distanceExtraBits(code: u32) u8 {
    return match_distances[code].extra_bits;
}

pub fn show(t: Token) void {
    if (t.kind == .literal) {
        print("L('{c}'), ", .{t.literal()});
    } else {
        print("M({d}, {d}), ", .{ t.distance(), t.length() });
    }
}

// Returns index in match_lengths table for each length in range 0-255.
const match_lengths_index = [_]u8{
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

const MatchLength = struct {
    code: u16,
    base_scaled: u8, // base - 3, scaled to fit into u8 (0-255), same as lit_len field in Token.
    base: u16, // 3-258
    extra_length: u8 = 0,
    extra_bits: u4,
};

// match_lengths represents table from rfc (https://datatracker.ietf.org/doc/html/rfc1951#page-12)
//
//      Extra               Extra               Extra
// Code Bits Length(s) Code Bits Lengths   Code Bits Length(s)
// ---- ---- ------     ---- ---- -------   ---- ---- -------
//  257   0     3       267   1   15,16     277   4   67-82
//  258   0     4       268   1   17,18     278   4   83-98
//  259   0     5       269   2   19-22     279   4   99-114
//  260   0     6       270   2   23-26     280   4  115-130
//  261   0     7       271   2   27-30     281   5  131-162
//  262   0     8       272   2   31-34     282   5  163-194
//  263   0     9       273   3   35-42     283   5  195-226
//  264   0    10       274   3   43-50     284   5  227-257
//  265   1  11,12      275   3   51-58     285   0    258
//  266   1  13,14      276   3   59-66
//
pub const length_codes_start = 257;

const match_lengths = [_]MatchLength{
    .{ .extra_bits = 0, .base_scaled = 0, .base = 3, .code = 257 },
    .{ .extra_bits = 0, .base_scaled = 1, .base = 4, .code = 258 },
    .{ .extra_bits = 0, .base_scaled = 2, .base = 5, .code = 259 },
    .{ .extra_bits = 0, .base_scaled = 3, .base = 6, .code = 260 },
    .{ .extra_bits = 0, .base_scaled = 4, .base = 7, .code = 261 },
    .{ .extra_bits = 0, .base_scaled = 5, .base = 8, .code = 262 },
    .{ .extra_bits = 0, .base_scaled = 6, .base = 9, .code = 263 },
    .{ .extra_bits = 0, .base_scaled = 7, .base = 10, .code = 264 },
    .{ .extra_bits = 1, .base_scaled = 8, .base = 11, .code = 265 },
    .{ .extra_bits = 1, .base_scaled = 10, .base = 13, .code = 266 },
    .{ .extra_bits = 1, .base_scaled = 12, .base = 15, .code = 267 },
    .{ .extra_bits = 1, .base_scaled = 14, .base = 17, .code = 268 },
    .{ .extra_bits = 2, .base_scaled = 16, .base = 19, .code = 269 },
    .{ .extra_bits = 2, .base_scaled = 20, .base = 23, .code = 270 },
    .{ .extra_bits = 2, .base_scaled = 24, .base = 27, .code = 271 },
    .{ .extra_bits = 2, .base_scaled = 28, .base = 31, .code = 272 },
    .{ .extra_bits = 3, .base_scaled = 32, .base = 35, .code = 273 },
    .{ .extra_bits = 3, .base_scaled = 40, .base = 43, .code = 274 },
    .{ .extra_bits = 3, .base_scaled = 48, .base = 51, .code = 275 },
    .{ .extra_bits = 3, .base_scaled = 56, .base = 59, .code = 276 },
    .{ .extra_bits = 4, .base_scaled = 64, .base = 67, .code = 277 },
    .{ .extra_bits = 4, .base_scaled = 80, .base = 83, .code = 278 },
    .{ .extra_bits = 4, .base_scaled = 96, .base = 99, .code = 279 },
    .{ .extra_bits = 4, .base_scaled = 112, .base = 115, .code = 280 },
    .{ .extra_bits = 5, .base_scaled = 128, .base = 131, .code = 281 },
    .{ .extra_bits = 5, .base_scaled = 160, .base = 163, .code = 282 },
    .{ .extra_bits = 5, .base_scaled = 192, .base = 195, .code = 283 },
    .{ .extra_bits = 5, .base_scaled = 224, .base = 227, .code = 284 },
    .{ .extra_bits = 0, .base_scaled = 255, .base = 258, .code = 285 },
};

// Used in distanceCode fn to get index in match_distance table for each distance in range 0-32767.
const match_distances_index = [_]u8{
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

const MatchDistance = struct {
    base_scaled: u16, // base - 1, same as Token dist field
    base: u16,
    extra_distance: u16 = 0,
    code: u8,
    extra_bits: u4,
};

// match_distances represents table from rfc (https://datatracker.ietf.org/doc/html/rfc1951#page-12)
//
//      Extra           Extra               Extra
// Code Bits Dist  Code Bits   Dist     Code Bits Distance
// ---- ---- ----  ---- ----  ------    ---- ---- --------
//   0   0    1     10   4     33-48    20    9   1025-1536
//   1   0    2     11   4     49-64    21    9   1537-2048
//   2   0    3     12   5     65-96    22   10   2049-3072
//   3   0    4     13   5     97-128   23   10   3073-4096
//   4   1   5,6    14   6    129-192   24   11   4097-6144
//   5   1   7,8    15   6    193-256   25   11   6145-8192
//   6   2   9-12   16   7    257-384   26   12  8193-12288
//   7   2  13-16   17   7    385-512   27   12 12289-16384
//   8   3  17-24   18   8    513-768   28   13 16385-24576
//   9   3  25-32   19   8   769-1024   29   13 24577-32768
//
const match_distances = [_]MatchDistance{
    .{ .extra_bits = 0, .base_scaled = 0x0000, .code = 0, .base = 1 },
    .{ .extra_bits = 0, .base_scaled = 0x0001, .code = 1, .base = 2 },
    .{ .extra_bits = 0, .base_scaled = 0x0002, .code = 2, .base = 3 },
    .{ .extra_bits = 0, .base_scaled = 0x0003, .code = 3, .base = 4 },
    .{ .extra_bits = 1, .base_scaled = 0x0004, .code = 4, .base = 5 },
    .{ .extra_bits = 1, .base_scaled = 0x0006, .code = 5, .base = 7 },
    .{ .extra_bits = 2, .base_scaled = 0x0008, .code = 6, .base = 9 },
    .{ .extra_bits = 2, .base_scaled = 0x000c, .code = 7, .base = 13 },
    .{ .extra_bits = 3, .base_scaled = 0x0010, .code = 8, .base = 17 },
    .{ .extra_bits = 3, .base_scaled = 0x0018, .code = 9, .base = 25 },
    .{ .extra_bits = 4, .base_scaled = 0x0020, .code = 10, .base = 33 },
    .{ .extra_bits = 4, .base_scaled = 0x0030, .code = 11, .base = 49 },
    .{ .extra_bits = 5, .base_scaled = 0x0040, .code = 12, .base = 65 },
    .{ .extra_bits = 5, .base_scaled = 0x0060, .code = 13, .base = 97 },
    .{ .extra_bits = 6, .base_scaled = 0x0080, .code = 14, .base = 129 },
    .{ .extra_bits = 6, .base_scaled = 0x00c0, .code = 15, .base = 193 },
    .{ .extra_bits = 7, .base_scaled = 0x0100, .code = 16, .base = 257 },
    .{ .extra_bits = 7, .base_scaled = 0x0180, .code = 17, .base = 385 },
    .{ .extra_bits = 8, .base_scaled = 0x0200, .code = 18, .base = 513 },
    .{ .extra_bits = 8, .base_scaled = 0x0300, .code = 19, .base = 769 },
    .{ .extra_bits = 9, .base_scaled = 0x0400, .code = 20, .base = 1025 },
    .{ .extra_bits = 9, .base_scaled = 0x0600, .code = 21, .base = 1537 },
    .{ .extra_bits = 10, .base_scaled = 0x0800, .code = 22, .base = 2049 },
    .{ .extra_bits = 10, .base_scaled = 0x0c00, .code = 23, .base = 3073 },
    .{ .extra_bits = 11, .base_scaled = 0x1000, .code = 24, .base = 4097 },
    .{ .extra_bits = 11, .base_scaled = 0x1800, .code = 25, .base = 6145 },
    .{ .extra_bits = 12, .base_scaled = 0x2000, .code = 26, .base = 8193 },
    .{ .extra_bits = 12, .base_scaled = 0x3000, .code = 27, .base = 12289 },
    .{ .extra_bits = 13, .base_scaled = 0x4000, .code = 28, .base = 16385 },
    .{ .extra_bits = 13, .base_scaled = 0x6000, .code = 29, .base = 24577 },
};

test "size" {
    try expect(@sizeOf(Token) == 4);
}

// testing table https://datatracker.ietf.org/doc/html/rfc1951#page-12
test "MatchLength" {
    var c = Token.initMatch(1, 4).lengthEncoding();
    try expect(c.code == 258);
    try expect(c.extra_bits == 0);
    try expect(c.extra_length == 0);

    c = Token.initMatch(1, 11).lengthEncoding();
    try expect(c.code == 265);
    try expect(c.extra_bits == 1);
    try expect(c.extra_length == 0);

    c = Token.initMatch(1, 12).lengthEncoding();
    try expect(c.code == 265);
    try expect(c.extra_bits == 1);
    try expect(c.extra_length == 1);

    c = Token.initMatch(1, 130).lengthEncoding();
    try expect(c.code == 280);
    try expect(c.extra_bits == 4);
    try expect(c.extra_length == 130 - 115);
}

test "MatchDistance" {
    var c = Token.initMatch(1, 4).distanceEncoding();
    try expect(c.code == 0);
    try expect(c.extra_bits == 0);
    try expect(c.extra_distance == 0);

    c = Token.initMatch(192, 4).distanceEncoding();
    try expect(c.code == 14);
    try expect(c.extra_bits == 6);
    try expect(c.extra_distance == 192 - 129);
}

test "match_lengths" {
    for (match_lengths, 0..) |ml, i| {
        try expect(@as(u16, ml.base_scaled) + 3 == ml.base);
        try expect(i + 257 == ml.code);
    }

    for (match_distances, 0..) |mo, i| {
        try expect(mo.base_scaled + 1 == mo.base);
        try expect(i == mo.code);
    }
}
