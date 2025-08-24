const HuffmanEncoder = @This();
const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

codes: []Code,
// Reusable buffer with the longest possible frequency table.
freq_cache: [max_num_frequencies + 1]LiteralNode,
bit_count: [17]u32,
lns: []LiteralNode, // sorted by literal, stored to avoid repeated allocation in generate
lfs: []LiteralNode, // sorted by frequency, stored to avoid repeated allocation in generate

pub const LiteralNode = struct {
    literal: u16,
    freq: u16,

    pub fn max() LiteralNode {
        return .{
            .literal = std.math.maxInt(u16),
            .freq = std.math.maxInt(u16),
        };
    }
};

pub const Code = struct {
    code: u16 = 0,
    len: u16 = 0,
};

/// The odd order in which the codegen code sizes are written.
pub const codegen_order = [_]u32{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };
/// The number of codegen codes.
pub const codegen_code_count = 19;

/// The largest distance code.
pub const distance_code_count = 30;

/// Maximum number of literals.
pub const max_num_lit = 286;

/// Max number of frequencies used for a Huffman Code
/// Possible lengths are codegen_code_count (19), distance_code_count (30) and max_num_lit (286).
/// The largest of these is max_num_lit.
pub const max_num_frequencies = max_num_lit;

/// Biggest block size for uncompressed block.
pub const max_store_block_size = 65535;
/// The special code used to mark the end of a block.
pub const end_block_marker = 256;

/// Update this Huffman Code object to be the minimum code for the specified frequency count.
///
/// freq  An array of frequencies, in which frequency[i] gives the frequency of literal i.
/// max_bits  The maximum number of bits to use for any literal.
pub fn generate(self: *HuffmanEncoder, freq: []u16, max_bits: u32) void {
    var list = self.freq_cache[0 .. freq.len + 1];
    // Number of non-zero literals
    var count: u32 = 0;
    // Set list to be the set of all non-zero literals and their frequencies
    for (freq, 0..) |f, i| {
        if (f != 0) {
            list[count] = LiteralNode{ .literal = @as(u16, @intCast(i)), .freq = f };
            count += 1;
        } else {
            list[count] = LiteralNode{ .literal = 0x00, .freq = 0 };
            self.codes[i].len = 0;
        }
    }
    list[freq.len] = LiteralNode{ .literal = 0x00, .freq = 0 };

    list = list[0..count];
    if (count <= 2) {
        // Handle the small cases here, because they are awkward for the general case code. With
        // two or fewer literals, everything has bit length 1.
        for (list, 0..) |node, i| {
            // "list" is in order of increasing literal value.
            self.codes[node.literal] = .{
                .code = @intCast(i),
                .len = 1,
            };
        }
        return;
    }
    self.lfs = list;
    std.mem.sort(LiteralNode, self.lfs, {}, byFreq);

    // Get the number of literals for each bit count
    const bit_count = self.bitCounts(list, max_bits);
    // And do the assignment
    self.assignEncodingAndSize(bit_count, list);
}

pub fn bitLength(self: *HuffmanEncoder, freq: []u16) u32 {
    var total: u32 = 0;
    for (freq, 0..) |f, i| {
        if (f != 0) {
            total += @as(u32, @intCast(f)) * @as(u32, @intCast(self.codes[i].len));
        }
    }
    return total;
}

/// Return the number of literals assigned to each bit size in the Huffman encoding
///
/// This method is only called when list.len >= 3
/// The cases of 0, 1, and 2 literals are handled by special case code.
///
/// list: An array of the literals with non-zero frequencies
/// and their associated frequencies. The array is in order of increasing
/// frequency, and has as its last element a special element with frequency
/// `math.maxInt(i32)`
///
/// max_bits: The maximum number of bits that should be used to encode any literal.
/// Must be less than 16.
///
/// Returns an integer array in which array[i] indicates the number of literals
/// that should be encoded in i bits.
fn bitCounts(self: *HuffmanEncoder, list: []LiteralNode, max_bits_to_use: usize) []u32 {
    var max_bits = max_bits_to_use;
    const n = list.len;
    const max_bits_limit = 16;

    assert(max_bits < max_bits_limit);

    // The tree can't have greater depth than n - 1, no matter what. This
    // saves a little bit of work in some small cases
    max_bits = @min(max_bits, n - 1);

    // Create information about each of the levels.
    // A bogus "Level 0" whose sole purpose is so that
    // level1.prev.needed == 0.  This makes level1.next_pair_freq
    // be a legitimate value that never gets chosen.
    var levels: [max_bits_limit]LevelInfo = std.mem.zeroes([max_bits_limit]LevelInfo);
    // leaf_counts[i] counts the number of literals at the left
    // of ancestors of the rightmost node at level i.
    // leaf_counts[i][j] is the number of literals at the left
    // of the level j ancestor.
    var leaf_counts: [max_bits_limit][max_bits_limit]u32 = @splat(@splat(0));

    {
        var level = @as(u32, 1);
        while (level <= max_bits) : (level += 1) {
            // For every level, the first two items are the first two characters.
            // We initialize the levels as if we had already figured this out.
            levels[level] = LevelInfo{
                .level = level,
                .last_freq = list[1].freq,
                .next_char_freq = list[2].freq,
                .next_pair_freq = list[0].freq + list[1].freq,
                .needed = 0,
            };
            leaf_counts[level][level] = 2;
            if (level == 1) {
                levels[level].next_pair_freq = std.math.maxInt(i32);
            }
        }
    }

    // We need a total of 2*n - 2 items at top level and have already generated 2.
    levels[max_bits].needed = 2 * @as(u32, @intCast(n)) - 4;

    {
        var level = max_bits;
        while (true) {
            var l = &levels[level];
            if (l.next_pair_freq == std.math.maxInt(i32) and l.next_char_freq == std.math.maxInt(i32)) {
                // We've run out of both leaves and pairs.
                // End all calculations for this level.
                // To make sure we never come back to this level or any lower level,
                // set next_pair_freq impossibly large.
                l.needed = 0;
                levels[level + 1].next_pair_freq = std.math.maxInt(i32);
                level += 1;
                continue;
            }

            const prev_freq = l.last_freq;
            if (l.next_char_freq < l.next_pair_freq) {
                // The next item on this row is a leaf node.
                const next = leaf_counts[level][level] + 1;
                l.last_freq = l.next_char_freq;
                // Lower leaf_counts are the same of the previous node.
                leaf_counts[level][level] = next;
                if (next >= list.len) {
                    l.next_char_freq = LiteralNode.max().freq;
                } else {
                    l.next_char_freq = list[next].freq;
                }
            } else {
                // The next item on this row is a pair from the previous row.
                // next_pair_freq isn't valid until we generate two
                // more values in the level below
                l.last_freq = l.next_pair_freq;
                // Take leaf counts from the lower level, except counts[level] remains the same.
                @memcpy(leaf_counts[level][0..level], leaf_counts[level - 1][0..level]);
                levels[l.level - 1].needed = 2;
            }

            l.needed -= 1;
            if (l.needed == 0) {
                // We've done everything we need to do for this level.
                // Continue calculating one level up. Fill in next_pair_freq
                // of that level with the sum of the two nodes we've just calculated on
                // this level.
                if (l.level == max_bits) {
                    // All done!
                    break;
                }
                levels[l.level + 1].next_pair_freq = prev_freq + l.last_freq;
                level += 1;
            } else {
                // If we stole from below, move down temporarily to replenish it.
                while (levels[level - 1].needed > 0) {
                    level -= 1;
                    if (level == 0) {
                        break;
                    }
                }
            }
        }
    }

    // Somethings is wrong if at the end, the top level is null or hasn't used
    // all of the leaves.
    assert(leaf_counts[max_bits][max_bits] == n);

    var bit_count = self.bit_count[0 .. max_bits + 1];
    var bits: u32 = 1;
    const counts = &leaf_counts[max_bits];
    {
        var level = max_bits;
        while (level > 0) : (level -= 1) {
            // counts[level] gives the number of literals requiring at least "bits"
            // bits to encode.
            bit_count[bits] = counts[level] - counts[level - 1];
            bits += 1;
            if (level == 0) {
                break;
            }
        }
    }
    return bit_count;
}

/// Look at the leaves and assign them a bit count and an encoding as specified
/// in RFC 1951 3.2.2
fn assignEncodingAndSize(self: *HuffmanEncoder, bit_count: []u32, list_arg: []LiteralNode) void {
    var code = @as(u16, 0);
    var list = list_arg;

    for (bit_count, 0..) |bits, n| {
        code <<= 1;
        if (n == 0 or bits == 0) {
            continue;
        }
        // The literals list[list.len-bits] .. list[list.len-bits]
        // are encoded using "bits" bits, and get the values
        // code, code + 1, ....  The code values are
        // assigned in literal order (not frequency order).
        const chunk = list[list.len - @as(u32, @intCast(bits)) ..];

        self.lns = chunk;
        std.mem.sort(LiteralNode, self.lns, {}, byLiteral);

        for (chunk) |node| {
            self.codes[node.literal] = .{
                .code = bitReverse(u16, code, @as(u5, @intCast(n))),
                .len = @as(u16, @intCast(n)),
            };
            code += 1;
        }
        list = list[0 .. list.len - @as(u32, @intCast(bits))];
    }
}

fn byFreq(context: void, a: LiteralNode, b: LiteralNode) bool {
    _ = context;
    if (a.freq == b.freq) {
        return a.literal < b.literal;
    }
    return a.freq < b.freq;
}

/// Describes the state of the constructed tree for a given depth.
const LevelInfo = struct {
    /// Our level.  for better printing
    level: u32,
    /// The frequency of the last node at this level
    last_freq: u32,
    /// The frequency of the next character to add to this level
    next_char_freq: u32,
    /// The frequency of the next pair (from level below) to add to this level.
    /// Only valid if the "needed" value of the next lower level is 0.
    next_pair_freq: u32,
    /// The number of chains remaining to generate for this level before moving
    /// up to the next level
    needed: u32,
};

fn byLiteral(context: void, a: LiteralNode, b: LiteralNode) bool {
    _ = context;
    return a.literal < b.literal;
}

/// Reverse bit-by-bit a N-bit code.
fn bitReverse(comptime T: type, value: T, n: usize) T {
    const r = @bitReverse(value);
    return r >> @as(std.math.Log2Int(T), @intCast(@typeInfo(T).int.bits - n));
}

test bitReverse {
    const ReverseBitsTest = struct {
        in: u16,
        bit_count: u5,
        out: u16,
    };

    const reverse_bits_tests = [_]ReverseBitsTest{
        .{ .in = 1, .bit_count = 1, .out = 1 },
        .{ .in = 1, .bit_count = 2, .out = 2 },
        .{ .in = 1, .bit_count = 3, .out = 4 },
        .{ .in = 1, .bit_count = 4, .out = 8 },
        .{ .in = 1, .bit_count = 5, .out = 16 },
        .{ .in = 17, .bit_count = 5, .out = 17 },
        .{ .in = 257, .bit_count = 9, .out = 257 },
        .{ .in = 29, .bit_count = 5, .out = 23 },
    };

    for (reverse_bits_tests) |h| {
        const v = bitReverse(u16, h.in, h.bit_count);
        try std.testing.expectEqual(h.out, v);
    }
}

/// Generates a HuffmanCode corresponding to the fixed literal table
pub fn fixedLiteralEncoder(codes: *[max_num_frequencies]Code) HuffmanEncoder {
    var h: HuffmanEncoder = undefined;
    h.codes = codes;
    var ch: u16 = 0;

    while (ch < max_num_frequencies) : (ch += 1) {
        var bits: u16 = undefined;
        var size: u16 = undefined;
        switch (ch) {
            0...143 => {
                // size 8, 000110000  .. 10111111
                bits = ch + 48;
                size = 8;
            },
            144...255 => {
                // size 9, 110010000 .. 111111111
                bits = ch + 400 - 144;
                size = 9;
            },
            256...279 => {
                // size 7, 0000000 .. 0010111
                bits = ch - 256;
                size = 7;
            },
            else => {
                // size 8, 11000000 .. 11000111
                bits = ch + 192 - 280;
                size = 8;
            },
        }
        h.codes[ch] = .{ .code = bitReverse(u16, bits, @as(u5, @intCast(size))), .len = size };
    }
    return h;
}

pub fn fixedDistanceEncoder(codes: *[distance_code_count]Code) HuffmanEncoder {
    var h: HuffmanEncoder = undefined;
    h.codes = codes;
    for (h.codes, 0..) |_, ch| {
        h.codes[ch] = .{ .code = bitReverse(u16, @as(u16, @intCast(ch)), 5), .len = 5 };
    }
    return h;
}

pub fn huffmanDistanceEncoder(codes: *[distance_code_count]Code) HuffmanEncoder {
    var distance_freq: [distance_code_count]u16 = @splat(0);
    distance_freq[0] = 1;
    // huff_distance is a static distance encoder used for huffman only encoding.
    // It can be reused since we will not be encoding distance values.
    var h: HuffmanEncoder = .{};
    h.codes = codes;
    h.generate(distance_freq[0..], 15);
    return h;
}

test "generate a Huffman code for the fixed literal table specific to Deflate" {
    var codes: [max_num_frequencies]Code = undefined;
    const enc: HuffmanEncoder = .fixedLiteralEncoder(&codes);
    for (enc.codes) |c| {
        switch (c.len) {
            7 => {
                const v = @bitReverse(@as(u7, @intCast(c.code)));
                try testing.expect(v <= 0b0010111);
            },
            8 => {
                const v = @bitReverse(@as(u8, @intCast(c.code)));
                try testing.expect((v >= 0b000110000 and v <= 0b10111111) or
                    (v >= 0b11000000 and v <= 11000111));
            },
            9 => {
                const v = @bitReverse(@as(u9, @intCast(c.code)));
                try testing.expect(v >= 0b110010000 and v <= 0b111111111);
            },
            else => unreachable,
        }
    }
}

test "generate a Huffman code for the 30 possible relative distances (LZ77 distances) of Deflate" {
    var codes: [distance_code_count]Code = undefined;
    const enc = fixedDistanceEncoder(&codes);
    for (enc.codes) |c| {
        const v = @bitReverse(@as(u5, @intCast(c.code)));
        try testing.expect(v <= 29);
        try testing.expect(c.len == 5);
    }
}

pub const fixed_codes = [_]u8{
    0b00001100, 0b10001100, 0b01001100, 0b11001100, 0b00101100, 0b10101100, 0b01101100, 0b11101100,
    0b00011100, 0b10011100, 0b01011100, 0b11011100, 0b00111100, 0b10111100, 0b01111100, 0b11111100,
    0b00000010, 0b10000010, 0b01000010, 0b11000010, 0b00100010, 0b10100010, 0b01100010, 0b11100010,
    0b00010010, 0b10010010, 0b01010010, 0b11010010, 0b00110010, 0b10110010, 0b01110010, 0b11110010,
    0b00001010, 0b10001010, 0b01001010, 0b11001010, 0b00101010, 0b10101010, 0b01101010, 0b11101010,
    0b00011010, 0b10011010, 0b01011010, 0b11011010, 0b00111010, 0b10111010, 0b01111010, 0b11111010,
    0b00000110, 0b10000110, 0b01000110, 0b11000110, 0b00100110, 0b10100110, 0b01100110, 0b11100110,
    0b00010110, 0b10010110, 0b01010110, 0b11010110, 0b00110110, 0b10110110, 0b01110110, 0b11110110,
    0b00001110, 0b10001110, 0b01001110, 0b11001110, 0b00101110, 0b10101110, 0b01101110, 0b11101110,
    0b00011110, 0b10011110, 0b01011110, 0b11011110, 0b00111110, 0b10111110, 0b01111110, 0b11111110,
    0b00000001, 0b10000001, 0b01000001, 0b11000001, 0b00100001, 0b10100001, 0b01100001, 0b11100001,
    0b00010001, 0b10010001, 0b01010001, 0b11010001, 0b00110001, 0b10110001, 0b01110001, 0b11110001,
    0b00001001, 0b10001001, 0b01001001, 0b11001001, 0b00101001, 0b10101001, 0b01101001, 0b11101001,
    0b00011001, 0b10011001, 0b01011001, 0b11011001, 0b00111001, 0b10111001, 0b01111001, 0b11111001,
    0b00000101, 0b10000101, 0b01000101, 0b11000101, 0b00100101, 0b10100101, 0b01100101, 0b11100101,
    0b00010101, 0b10010101, 0b01010101, 0b11010101, 0b00110101, 0b10110101, 0b01110101, 0b11110101,
    0b00001101, 0b10001101, 0b01001101, 0b11001101, 0b00101101, 0b10101101, 0b01101101, 0b11101101,
    0b00011101, 0b10011101, 0b01011101, 0b11011101, 0b00111101, 0b10111101, 0b01111101, 0b11111101,
    0b00010011, 0b00100110, 0b01001110, 0b10011010, 0b00111100, 0b01100101, 0b11101010, 0b10110100,
    0b11101001, 0b00110011, 0b01100110, 0b11001110, 0b10011010, 0b00111101, 0b01100111, 0b11101110,
    0b10111100, 0b11111001, 0b00001011, 0b00010110, 0b00101110, 0b01011010, 0b10111100, 0b01100100,
    0b11101001, 0b10110010, 0b11100101, 0b00101011, 0b01010110, 0b10101110, 0b01011010, 0b10111101,
    0b01100110, 0b11101101, 0b10111010, 0b11110101, 0b00011011, 0b00110110, 0b01101110, 0b11011010,
    0b10111100, 0b01100101, 0b11101011, 0b10110110, 0b11101101, 0b00111011, 0b01110110, 0b11101110,
    0b11011010, 0b10111101, 0b01100111, 0b11101111, 0b10111110, 0b11111101, 0b00000111, 0b00001110,
    0b00011110, 0b00111010, 0b01111100, 0b11100100, 0b11101000, 0b10110001, 0b11100011, 0b00100111,
    0b01001110, 0b10011110, 0b00111010, 0b01111101, 0b11100110, 0b11101100, 0b10111001, 0b11110011,
    0b00010111, 0b00101110, 0b01011110, 0b10111010, 0b01111100, 0b11100101, 0b11101010, 0b10110101,
    0b11101011, 0b00110111, 0b01101110, 0b11011110, 0b10111010, 0b01111101, 0b11100111, 0b11101110,
    0b10111101, 0b11111011, 0b00001111, 0b00011110, 0b00111110, 0b01111010, 0b11111100, 0b11100100,
    0b11101001, 0b10110011, 0b11100111, 0b00101111, 0b01011110, 0b10111110, 0b01111010, 0b11111101,
    0b11100110, 0b11101101, 0b10111011, 0b11110111, 0b00011111, 0b00111110, 0b01111110, 0b11111010,
    0b11111100, 0b11100101, 0b11101011, 0b10110111, 0b11101111, 0b00111111, 0b01111110, 0b11111110,
    0b11111010, 0b11111101, 0b11100111, 0b11101111, 0b10111111, 0b11111111, 0b00000000, 0b00100000,
    0b00001000, 0b00001100, 0b10000001, 0b11000010, 0b11100000, 0b00001000, 0b00100100, 0b00001010,
    0b10001101, 0b11000001, 0b11100010, 0b11110000, 0b00000100, 0b00100010, 0b10001001, 0b01001100,
    0b10100001, 0b11010010, 0b11101000, 0b00000011, 0b10000011, 0b01000011, 0b11000011, 0b00100011,
    0b10100011,
};
