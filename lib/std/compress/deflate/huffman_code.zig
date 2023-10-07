const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const sort = std.sort;
const testing = std.testing;

const Allocator = std.mem.Allocator;

const bu = @import("bits_utils.zig");
const deflate_const = @import("deflate_const.zig");

const max_bits_limit = 16;

const LiteralNode = struct {
    literal: u16,
    freq: u16,
};

// Describes the state of the constructed tree for a given depth.
const LevelInfo = struct {
    // Our level.  for better printing
    level: u32,

    // The frequency of the last node at this level
    last_freq: u32,

    // The frequency of the next character to add to this level
    next_char_freq: u32,

    // The frequency of the next pair (from level below) to add to this level.
    // Only valid if the "needed" value of the next lower level is 0.
    next_pair_freq: u32,

    // The number of chains remaining to generate for this level before moving
    // up to the next level
    needed: u32,
};

// hcode is a huffman code with a bit code and bit length.
pub const HuffCode = struct {
    code: u16 = 0,
    len: u16 = 0,

    // set sets the code and length of an hcode.
    fn set(self: *HuffCode, code: u16, length: u16) void {
        self.len = length;
        self.code = code;
    }
};

pub const HuffmanEncoder = struct {
    codes: []HuffCode,
    freq_cache: []LiteralNode = undefined,
    bit_count: [17]u32 = undefined,
    lns: []LiteralNode = undefined, // sorted by literal, stored to avoid repeated allocation in generate
    lfs: []LiteralNode = undefined, // sorted by frequency, stored to avoid repeated allocation in generate
    allocator: Allocator,

    pub fn deinit(self: *HuffmanEncoder) void {
        self.allocator.free(self.codes);
        self.allocator.free(self.freq_cache);
    }

    // Update this Huffman Code object to be the minimum code for the specified frequency count.
    //
    // freq  An array of frequencies, in which frequency[i] gives the frequency of literal i.
    // max_bits  The maximum number of bits to use for any literal.
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
                self.codes[node.literal].set(@as(u16, @intCast(i)), 1);
            }
            return;
        }
        self.lfs = list;
        mem.sort(LiteralNode, self.lfs, {}, byFreq);

        // Get the number of literals for each bit count
        var bit_count = self.bitCounts(list, max_bits);
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

    // Return the number of literals assigned to each bit size in the Huffman encoding
    //
    // This method is only called when list.len >= 3
    // The cases of 0, 1, and 2 literals are handled by special case code.
    //
    // list: An array of the literals with non-zero frequencies
    // and their associated frequencies. The array is in order of increasing
    // frequency, and has as its last element a special element with frequency
    // std.math.maxInt(i32)
    //
    // max_bits: The maximum number of bits that should be used to encode any literal.
    // Must be less than 16.
    //
    // Returns an integer array in which array[i] indicates the number of literals
    // that should be encoded in i bits.
    fn bitCounts(self: *HuffmanEncoder, list: []LiteralNode, max_bits_to_use: usize) []u32 {
        var max_bits = max_bits_to_use;
        var n = list.len;

        assert(max_bits < max_bits_limit);

        // The tree can't have greater depth than n - 1, no matter what. This
        // saves a little bit of work in some small cases
        max_bits = @min(max_bits, n - 1);

        // Create information about each of the levels.
        // A bogus "Level 0" whose sole purpose is so that
        // level1.prev.needed == 0.  This makes level1.next_pair_freq
        // be a legitimate value that never gets chosen.
        var levels: [max_bits_limit]LevelInfo = mem.zeroes([max_bits_limit]LevelInfo);
        // leaf_counts[i] counts the number of literals at the left
        // of ancestors of the rightmost node at level i.
        // leaf_counts[i][j] is the number of literals at the left
        // of the level j ancestor.
        var leaf_counts: [max_bits_limit][max_bits_limit]u32 = mem.zeroes([max_bits_limit][max_bits_limit]u32);

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
                    levels[level].next_pair_freq = math.maxInt(i32);
                }
            }
        }

        // We need a total of 2*n - 2 items at top level and have already generated 2.
        levels[max_bits].needed = 2 * @as(u32, @intCast(n)) - 4;

        {
            var level = max_bits;
            while (true) {
                var l = &levels[level];
                if (l.next_pair_freq == math.maxInt(i32) and l.next_char_freq == math.maxInt(i32)) {
                    // We've run out of both leafs and pairs.
                    // End all calculations for this level.
                    // To make sure we never come back to this level or any lower level,
                    // set next_pair_freq impossibly large.
                    l.needed = 0;
                    levels[level + 1].next_pair_freq = math.maxInt(i32);
                    level += 1;
                    continue;
                }

                var prev_freq = l.last_freq;
                if (l.next_char_freq < l.next_pair_freq) {
                    // The next item on this row is a leaf node.
                    var next = leaf_counts[level][level] + 1;
                    l.last_freq = l.next_char_freq;
                    // Lower leaf_counts are the same of the previous node.
                    leaf_counts[level][level] = next;
                    if (next >= list.len) {
                        l.next_char_freq = maxNode().freq;
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
        var counts = &leaf_counts[max_bits];
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

    // Look at the leaves and assign them a bit count and an encoding as specified
    // in RFC 1951 3.2.2
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
            var chunk = list[list.len - @as(u32, @intCast(bits)) ..];

            self.lns = chunk;
            mem.sort(LiteralNode, self.lns, {}, byLiteral);

            for (chunk) |node| {
                self.codes[node.literal] = HuffCode{
                    .code = bu.bitReverse(u16, code, @as(u5, @intCast(n))),
                    .len = @as(u16, @intCast(n)),
                };
                code += 1;
            }
            list = list[0 .. list.len - @as(u32, @intCast(bits))];
        }
    }
};

fn maxNode() LiteralNode {
    return LiteralNode{
        .literal = math.maxInt(u16),
        .freq = math.maxInt(u16),
    };
}

pub fn newHuffmanEncoder(allocator: Allocator, size: u32) !HuffmanEncoder {
    return HuffmanEncoder{
        .codes = try allocator.alloc(HuffCode, size),
        // Allocate a reusable buffer with the longest possible frequency table.
        // (deflate_const.max_num_frequencies).
        .freq_cache = try allocator.alloc(LiteralNode, deflate_const.max_num_frequencies + 1),
        .allocator = allocator,
    };
}

// Generates a HuffmanCode corresponding to the fixed literal table
pub fn generateFixedLiteralEncoding(allocator: Allocator) !HuffmanEncoder {
    var h = try newHuffmanEncoder(allocator, deflate_const.max_num_frequencies);
    var codes = h.codes;
    var ch: u16 = 0;

    while (ch < deflate_const.max_num_frequencies) : (ch += 1) {
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
        codes[ch] = HuffCode{ .code = bu.bitReverse(u16, bits, @as(u5, @intCast(size))), .len = size };
    }
    return h;
}

pub fn generateFixedOffsetEncoding(allocator: Allocator) !HuffmanEncoder {
    var h = try newHuffmanEncoder(allocator, 30);
    var codes = h.codes;
    for (codes, 0..) |_, ch| {
        codes[ch] = HuffCode{ .code = bu.bitReverse(u16, @as(u16, @intCast(ch)), 5), .len = 5 };
    }
    return h;
}

fn byLiteral(context: void, a: LiteralNode, b: LiteralNode) bool {
    _ = context;
    return a.literal < b.literal;
}

fn byFreq(context: void, a: LiteralNode, b: LiteralNode) bool {
    _ = context;
    if (a.freq == b.freq) {
        return a.literal < b.literal;
    }
    return a.freq < b.freq;
}

test "generate a Huffman code from an array of frequencies" {
    var freqs: [19]u16 = [_]u16{
        8, // 0
        1, // 1
        1, // 2
        2, // 3
        5, // 4
        10, // 5
        9, // 6
        1, // 7
        0, // 8
        0, // 9
        0, // 10
        0, // 11
        0, // 12
        0, // 13
        0, // 14
        0, // 15
        1, // 16
        3, // 17
        5, // 18
    };

    var enc = try newHuffmanEncoder(testing.allocator, freqs.len);
    defer enc.deinit();
    enc.generate(freqs[0..], 7);

    try testing.expectEqual(@as(u32, 141), enc.bitLength(freqs[0..]));

    try testing.expectEqual(@as(usize, 3), enc.codes[0].len);
    try testing.expectEqual(@as(usize, 6), enc.codes[1].len);
    try testing.expectEqual(@as(usize, 6), enc.codes[2].len);
    try testing.expectEqual(@as(usize, 5), enc.codes[3].len);
    try testing.expectEqual(@as(usize, 3), enc.codes[4].len);
    try testing.expectEqual(@as(usize, 2), enc.codes[5].len);
    try testing.expectEqual(@as(usize, 2), enc.codes[6].len);
    try testing.expectEqual(@as(usize, 6), enc.codes[7].len);
    try testing.expectEqual(@as(usize, 0), enc.codes[8].len);
    try testing.expectEqual(@as(usize, 0), enc.codes[9].len);
    try testing.expectEqual(@as(usize, 0), enc.codes[10].len);
    try testing.expectEqual(@as(usize, 0), enc.codes[11].len);
    try testing.expectEqual(@as(usize, 0), enc.codes[12].len);
    try testing.expectEqual(@as(usize, 0), enc.codes[13].len);
    try testing.expectEqual(@as(usize, 0), enc.codes[14].len);
    try testing.expectEqual(@as(usize, 0), enc.codes[15].len);
    try testing.expectEqual(@as(usize, 6), enc.codes[16].len);
    try testing.expectEqual(@as(usize, 5), enc.codes[17].len);
    try testing.expectEqual(@as(usize, 3), enc.codes[18].len);

    try testing.expectEqual(@as(u16, 0x0), enc.codes[5].code);
    try testing.expectEqual(@as(u16, 0x2), enc.codes[6].code);
    try testing.expectEqual(@as(u16, 0x1), enc.codes[0].code);
    try testing.expectEqual(@as(u16, 0x5), enc.codes[4].code);
    try testing.expectEqual(@as(u16, 0x3), enc.codes[18].code);
    try testing.expectEqual(@as(u16, 0x7), enc.codes[3].code);
    try testing.expectEqual(@as(u16, 0x17), enc.codes[17].code);
    try testing.expectEqual(@as(u16, 0x0f), enc.codes[1].code);
    try testing.expectEqual(@as(u16, 0x2f), enc.codes[2].code);
    try testing.expectEqual(@as(u16, 0x1f), enc.codes[7].code);
    try testing.expectEqual(@as(u16, 0x3f), enc.codes[16].code);
}

test "generate a Huffman code for the fixed literal table specific to Deflate" {
    var enc = try generateFixedLiteralEncoding(testing.allocator);
    defer enc.deinit();
}

test "generate a Huffman code for the 30 possible relative offsets (LZ77 distances) of Deflate" {
    var enc = try generateFixedOffsetEncoding(testing.allocator);
    defer enc.deinit();
}
