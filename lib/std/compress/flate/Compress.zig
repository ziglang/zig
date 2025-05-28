//! Default compression algorithm. Has two steps: tokenization and token
//! encoding.
//!
//! Tokenization takes uncompressed input stream and produces list of tokens.
//! Each token can be literal (byte of data) or match (backrefernce to previous
//! data with length and distance). Tokenization accumulators 32K tokens, when
//! full or `flush` is called tokens are passed to the `block_writer`. Level
//! defines how hard (how slow) it tries to find match.
//!
//! Block writer will decide which type of deflate block to write (stored, fixed,
//! dynamic) and encode tokens to the output byte stream. Client has to call
//! `finish` to write block with the final bit set.
//!
//! Container defines type of header and footer which can be gzip, zlib or raw.
//! They all share same deflate body. Raw has no header or footer just deflate
//! body.
//!
//! Compression algorithm explained in rfc-1951 (slightly edited for this case):
//!
//!   The compressor uses a chained hash table `lookup` to find duplicated
//!   strings, using a hash function that operates on 4-byte sequences. At any
//!   given point during compression, let XYZW be the next 4 input bytes
//!   (lookahead) to be examined (not necessarily all different, of course).
//!   First, the compressor examines the hash chain for XYZW. If the chain is
//!   empty, the compressor simply writes out X as a literal byte and advances
//!   one byte in the input. If the hash chain is not empty, indicating that the
//!   sequence XYZW (or, if we are unlucky, some other 4 bytes with the same
//!   hash function value) has occurred recently, the compressor compares all
//!   strings on the XYZW hash chain with the actual input data sequence
//!   starting at the current point, and selects the longest match.
//!
//!   To improve overall compression, the compressor defers the selection of
//!   matches ("lazy matching"): after a match of length N has been found, the
//!   compressor searches for a longer match starting at the next input byte. If
//!   it finds a longer match, it truncates the previous match to a length of
//!   one (thus producing a single literal byte) and then emits the longer
//!   match. Otherwise, it emits the original match, and, as described above,
//!   advances N bytes before continuing.
//!
//!
//! Allocates statically ~400K (192K lookup, 128K tokens, 64K window).
const builtin = @import("builtin");
const std = @import("std");
const io = std.io;
const assert = std.debug.assert;
const testing = std.testing;
const expect = testing.expect;
const mem = std.mem;
const math = std.math;

const Compress = @This();
const Token = @import("Token.zig");
const BlockWriter = @import("BlockWriter.zig");
const flate = @import("../flate.zig");
const Container = flate.Container;
const Lookup = @import("Lookup.zig");
const huffman = flate.huffman;

lookup: Lookup = .{},
tokens: Tokens = .{},
/// Asserted to have a buffer capacity of at least `flate.max_window_len`.
input: *std.io.BufferedReader,
block_writer: BlockWriter,
level: LevelArgs,
hasher: Container.Hasher,

// Match and literal at the previous position.
// Used for lazy match finding in processWindow.
prev_match: ?Token = null,
prev_literal: ?u8 = null,

pub fn readable(c: *Compress, buffer: []u8) std.io.BufferedReader {
    return .{
        .unbuffered_reader = .{
            .context = c,
            .vtable = .{ .read = read },
        },
        .buffer = buffer,
    };
}

pub const Options = struct {
    level: Level = .default,
    container: Container = .raw,
};

/// Trades between speed and compression size.
/// Starts with level 4: in [zlib](https://github.com/madler/zlib/blob/abd3d1a28930f89375d4b41408b39f6c1be157b2/deflate.c#L115C1-L117C43)
/// levels 1-3 are using different algorithm to perform faster but with less
/// compression. That is not implemented here.
pub const Level = enum(u4) {
    level_4 = 4,
    level_5 = 5,
    level_6 = 6,
    level_7 = 7,
    level_8 = 8,
    level_9 = 9,

    fast = 0xb,
    default = 0xc,
    best = 0xd,
};

/// Number of tokens to accumulate in deflate before starting block encoding.
///
/// In zlib this depends on memlevel: 6 + memlevel, where default memlevel is
/// 8 and max 9 that gives 14 or 15 bits.
pub const n_tokens = 1 << 15;

/// Algorithm knobs for each level.
const LevelArgs = struct {
    good: u16, // Do less lookups if we already have match of this length.
    nice: u16, // Stop looking for better match if we found match with at least this length.
    lazy: u16, // Don't do lazy match find if got match with at least this length.
    chain: u16, // How many lookups for previous match to perform.

    pub fn get(level: Level) LevelArgs {
        return switch (level) {
            .fast, .level_4 => .{ .good = 4, .lazy = 4, .nice = 16, .chain = 16 },
            .level_5 => .{ .good = 8, .lazy = 16, .nice = 32, .chain = 32 },
            .default, .level_6 => .{ .good = 8, .lazy = 16, .nice = 128, .chain = 128 },
            .level_7 => .{ .good = 8, .lazy = 32, .nice = 128, .chain = 256 },
            .level_8 => .{ .good = 32, .lazy = 128, .nice = 258, .chain = 1024 },
            .best, .level_9 => .{ .good = 32, .lazy = 258, .nice = 258, .chain = 4096 },
        };
    }
};

pub fn init(input: *std.io.BufferedReader, options: Options) Compress {
    return .{
        .input = input,
        .block_writer = undefined,
        .level = .get(options.level),
        .hasher = .init(options.container),
        .state = .header,
    };
}

const FlushOption = enum { none, flush, final };

/// Process data in window and create tokens. If token buffer is full
/// flush tokens to the token writer.
///
/// Returns number of bytes consumed from `lh`.
fn tokenizeSlice(c: *Compress, bw: *std.io.BufferedWriter, limit: std.io.Limit, lh: []const u8) !usize {
    _ = bw;
    _ = limit;
    if (true) @panic("TODO");
    var step: u16 = 1; // 1 in the case of literal, match length otherwise
    const pos: u16 = c.win.pos();
    const literal = lh[0]; // literal at current position
    const min_len: u16 = if (c.prev_match) |m| m.length() else 0;

    // Try to find match at least min_len long.
    if (c.findMatch(pos, lh, min_len)) |match| {
        // Found better match than previous.
        try c.addPrevLiteral();

        // Is found match length good enough?
        if (match.length() >= c.level.lazy) {
            // Don't try to lazy find better match, use this.
            step = try c.addMatch(match);
        } else {
            // Store this match.
            c.prev_literal = literal;
            c.prev_match = match;
        }
    } else {
        // There is no better match at current pos then it was previous.
        // Write previous match or literal.
        if (c.prev_match) |m| {
            // Write match from previous position.
            step = try c.addMatch(m) - 1; // we already advanced 1 from previous position
        } else {
            // No match at previous position.
            // Write previous literal if any, and remember this literal.
            try c.addPrevLiteral();
            c.prev_literal = literal;
        }
    }
    // Advance window and add hashes.
    c.windowAdvance(step, lh, pos);
}

fn windowAdvance(self: *Compress, step: u16, lh: []const u8, pos: u16) void {
    // current position is already added in findMatch
    self.lookup.bulkAdd(lh[1..], step - 1, pos + 1);
    self.win.advance(step);
}

// Add previous literal (if any) to the tokens list.
fn addPrevLiteral(self: *Compress) !void {
    if (self.prev_literal) |l| try self.addToken(Token.initLiteral(l));
}

// Add match to the tokens list, reset prev pointers.
// Returns length of the added match.
fn addMatch(self: *Compress, m: Token) !u16 {
    try self.addToken(m);
    self.prev_literal = null;
    self.prev_match = null;
    return m.length();
}

fn addToken(self: *Compress, token: Token) !void {
    self.tokens.add(token);
    if (self.tokens.full()) try self.flushTokens(.none);
}

// Finds largest match in the history window with the data at current pos.
fn findMatch(self: *Compress, pos: u16, lh: []const u8, min_len: u16) ?Token {
    var len: u16 = min_len;
    // Previous location with the same hash (same 4 bytes).
    var prev_pos = self.lookup.add(lh, pos);
    // Last found match.
    var match: ?Token = null;

    // How much back-references to try, performance knob.
    var chain: usize = self.level.chain;
    if (len >= self.level.good) {
        // If we've got a match that's good enough, only look in 1/4 the chain.
        chain >>= 2;
    }

    // Hot path loop!
    while (prev_pos > 0 and chain > 0) : (chain -= 1) {
        const distance = pos - prev_pos;
        if (distance > flate.match.max_distance)
            break;

        const new_len = self.win.match(prev_pos, pos, len);
        if (new_len > len) {
            match = Token.initMatch(@intCast(distance), new_len);
            if (new_len >= self.level.nice) {
                // The match is good enough that we don't try to find a better one.
                return match;
            }
            len = new_len;
        }
        prev_pos = self.lookup.prev(prev_pos);
    }

    return match;
}

fn flushTokens(self: *Compress, flush_opt: FlushOption) !void {
    // Pass tokens to the token writer
    try self.block_writer.write(self.tokens.tokens(), flush_opt == .final, self.win.tokensBuffer());
    // Stored block ensures byte alignment.
    // It has 3 bits (final, block_type) and then padding until byte boundary.
    // After that everything is aligned to the boundary in the stored block.
    // Empty stored block is Ob000 + (0-7) bits of padding + 0x00 0x00 0xFF 0xFF.
    // Last 4 bytes are byte aligned.
    if (flush_opt == .flush) {
        try self.block_writer.storedBlock("", false);
    }
    if (flush_opt != .none) {
        // Safe to call only when byte aligned or it is OK to add
        // padding bits (on last byte of the final block).
        try self.block_writer.flush();
    }
    // Reset internal tokens store.
    self.tokens.reset();
    // Notify win that tokens are flushed.
    self.win.flush();
}

// Slide win and if needed lookup tables.
fn slide(self: *Compress) void {
    const n = self.win.slide();
    self.lookup.slide(n);
}

/// Flushes internal buffers to the output writer. Outputs empty stored
/// block to sync bit stream to the byte boundary, so that the
/// decompressor can get all input data available so far.
///
/// It is useful mainly in compressed network protocols, to ensure that
/// deflate bit stream can be used as byte stream. May degrade
/// compression so it should be used only when necessary.
///
/// Completes the current deflate block and follows it with an empty
/// stored block that is three zero bits plus filler bits to the next
/// byte, followed by four bytes (00 00 ff ff).
///
pub fn flush(c: *Compress) !void {
    try c.tokenize(.flush);
}

/// Completes deflate bit stream by writing any pending data as deflate
/// final deflate block. HAS to be called once all data are written to
/// the compressor as a signal that next block has to have final bit
/// set.
///
pub fn finish(c: *Compress) !void {
    _ = c;
    @panic("TODO");
}

/// Use another writer while preserving history. Most probably flush
/// should be called on old writer before setting new.
pub fn setWriter(self: *Compress, new_writer: *std.io.BufferedWriter) void {
    self.block_writer.setWriter(new_writer);
    self.output = new_writer;
}

// Tokens store
const Tokens = struct {
    list: [n_tokens]Token = undefined,
    pos: usize = 0,

    fn add(self: *Tokens, t: Token) void {
        self.list[self.pos] = t;
        self.pos += 1;
    }

    fn full(self: *Tokens) bool {
        return self.pos == self.list.len;
    }

    fn reset(self: *Tokens) void {
        self.pos = 0;
    }

    fn tokens(self: *Tokens) []const Token {
        return self.list[0..self.pos];
    }
};

/// Creates huffman only deflate blocks. Disables Lempel-Ziv match searching and
/// only performs Huffman entropy encoding. Results in faster compression, much
/// less memory requirements during compression but bigger compressed sizes.
pub const Huffman = SimpleCompressor(.huffman, .raw);

/// Creates store blocks only. Data are not compressed only packed into deflate
/// store blocks. That adds 9 bytes of header for each block. Max stored block
/// size is 64K. Block is emitted when flush is called on on finish.
pub const store = struct {
    pub fn compress(comptime container: Container, reader: anytype, writer: anytype) !void {
        var c = try store.compressor(container, writer);
        try c.compress(reader);
        try c.finish();
    }

    pub fn Compressor(comptime container: Container, comptime WriterType: type) type {
        return SimpleCompressor(.store, container, WriterType);
    }

    pub fn compressor(comptime container: Container, writer: anytype) !store.Compressor(container, @TypeOf(writer)) {
        return try store.Compressor(container, @TypeOf(writer)).init(writer);
    }
};

const SimpleCompressorKind = enum {
    huffman,
    store,
};

fn simpleCompressor(
    comptime kind: SimpleCompressorKind,
    comptime container: Container,
    writer: anytype,
) !SimpleCompressor(kind, container, @TypeOf(writer)) {
    return try SimpleCompressor(kind, container, @TypeOf(writer)).init(writer);
}

fn SimpleCompressor(
    comptime kind: SimpleCompressorKind,
    comptime container: Container,
    comptime WriterType: type,
) type {
    const BlockWriterType = BlockWriter(WriterType);
    return struct {
        buffer: [65535]u8 = undefined, // because store blocks are limited to 65535 bytes
        wp: usize = 0,

        output: WriterType,
        block_writer: BlockWriterType,
        hasher: container.Hasher() = .{},

        const Self = @This();

        pub fn init(output: WriterType) !Self {
            const self = Self{
                .output = output,
                .block_writer = BlockWriterType.init(output),
            };
            try container.writeHeader(self.output);
            return self;
        }

        pub fn flush(self: *Self) !void {
            try self.flushBuffer(false);
            try self.block_writer.storedBlock("", false);
            try self.block_writer.flush();
        }

        pub fn finish(self: *Self) !void {
            try self.flushBuffer(true);
            try self.block_writer.flush();
            try container.writeFooter(&self.hasher, self.output);
        }

        fn flushBuffer(self: *Self, final: bool) !void {
            const buf = self.buffer[0..self.wp];
            switch (kind) {
                .huffman => try self.block_writer.huffmanBlock(buf, final),
                .store => try self.block_writer.storedBlock(buf, final),
            }
            self.wp = 0;
        }
    };
}

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

pub fn HuffmanEncoder(comptime size: usize) type {
    return struct {
        codes: [size]HuffCode = undefined,
        // Reusable buffer with the longest possible frequency table.
        freq_cache: [huffman.max_num_frequencies + 1]LiteralNode = undefined,
        bit_count: [17]u32 = undefined,
        lns: []LiteralNode = undefined, // sorted by literal, stored to avoid repeated allocation in generate
        lfs: []LiteralNode = undefined, // sorted by frequency, stored to avoid repeated allocation in generate

        const Self = @This();

        // Update this Huffman Code object to be the minimum code for the specified frequency count.
        //
        // freq  An array of frequencies, in which frequency[i] gives the frequency of literal i.
        // max_bits  The maximum number of bits to use for any literal.
        pub fn generate(self: *Self, freq: []u16, max_bits: u32) void {
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
            const bit_count = self.bitCounts(list, max_bits);
            // And do the assignment
            self.assignEncodingAndSize(bit_count, list);
        }

        pub fn bitLength(self: *Self, freq: []u16) u32 {
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
        // `math.maxInt(i32)`
        //
        // max_bits: The maximum number of bits that should be used to encode any literal.
        // Must be less than 16.
        //
        // Returns an integer array in which array[i] indicates the number of literals
        // that should be encoded in i bits.
        fn bitCounts(self: *Self, list: []LiteralNode, max_bits_to_use: usize) []u32 {
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
                        // We've run out of both leaves and pairs.
                        // End all calculations for this level.
                        // To make sure we never come back to this level or any lower level,
                        // set next_pair_freq impossibly large.
                        l.needed = 0;
                        levels[level + 1].next_pair_freq = math.maxInt(i32);
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

        // Look at the leaves and assign them a bit count and an encoding as specified
        // in RFC 1951 3.2.2
        fn assignEncodingAndSize(self: *Self, bit_count: []u32, list_arg: []LiteralNode) void {
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
                mem.sort(LiteralNode, self.lns, {}, byLiteral);

                for (chunk) |node| {
                    self.codes[node.literal] = HuffCode{
                        .code = bitReverse(u16, code, @as(u5, @intCast(n))),
                        .len = @as(u16, @intCast(n)),
                    };
                    code += 1;
                }
                list = list[0 .. list.len - @as(u32, @intCast(bits))];
            }
        }
    };
}

fn maxNode() LiteralNode {
    return LiteralNode{
        .literal = math.maxInt(u16),
        .freq = math.maxInt(u16),
    };
}

pub fn huffmanEncoder(comptime size: u32) HuffmanEncoder(size) {
    return .{};
}

pub const LiteralEncoder = HuffmanEncoder(huffman.max_num_frequencies);
pub const DistanceEncoder = HuffmanEncoder(huffman.distance_code_count);
pub const CodegenEncoder = HuffmanEncoder(19);

// Generates a HuffmanCode corresponding to the fixed literal table
pub fn fixedLiteralEncoder() LiteralEncoder {
    var h: LiteralEncoder = undefined;
    var ch: u16 = 0;

    while (ch < huffman.max_num_frequencies) : (ch += 1) {
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
        h.codes[ch] = HuffCode{ .code = bitReverse(u16, bits, @as(u5, @intCast(size))), .len = size };
    }
    return h;
}

pub fn fixedDistanceEncoder() DistanceEncoder {
    var h: DistanceEncoder = undefined;
    for (h.codes, 0..) |_, ch| {
        h.codes[ch] = HuffCode{ .code = bitReverse(u16, @as(u16, @intCast(ch)), 5), .len = 5 };
    }
    return h;
}

pub fn huffmanDistanceEncoder() DistanceEncoder {
    var distance_freq = [1]u16{0} ** huffman.distance_code_count;
    distance_freq[0] = 1;
    // huff_distance is a static distance encoder used for huffman only encoding.
    // It can be reused since we will not be encoding distance values.
    var h: DistanceEncoder = .{};
    h.generate(distance_freq[0..], 15);
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

fn read(
    context: ?*anyopaque,
    bw: *std.io.BufferedWriter,
    limit: std.io.Reader.Limit,
) std.io.Reader.RwError!usize {
    const c: *Compress = @ptrCast(@alignCast(context));
    switch (c.state) {
        .header => |i| {
            const header = c.hasher.container().header();
            const n = try bw.write(header[i..]);
            if (header.len - i - n == 0) {
                c.state = .middle;
            } else {
                c.state.header += n;
            }
            return n;
        },
        .middle => {
            c.input.fillMore() catch |err| switch (err) {
                error.EndOfStream => {
                    c.state = .final;
                    return 0;
                },
                else => |e| return e,
            };
            const buffer_contents = c.input.bufferContents();
            const min_lookahead = flate.match.min_length + flate.match.max_length;
            const history_plus_lookahead_len = flate.history_len + min_lookahead;
            if (buffer_contents.len < history_plus_lookahead_len) return 0;
            const lookahead = buffer_contents[flate.history_len..];
            const start = bw.count;
            const n = try c.tokenizeSlice(bw, limit, lookahead) catch |err| switch (err) {
                error.WriteFailed => return error.WriteFailed,
            };
            c.hasher.update(lookahead[0..n]);
            c.input.toss(n);
            return bw.count - start;
        },
        .final => {
            const buffer_contents = c.input.bufferContents();
            const start = bw.count;
            const n = c.tokenizeSlice(bw, limit, buffer_contents) catch |err| switch (err) {
                error.WriteFailed => return error.WriteFailed,
            };
            if (buffer_contents.len - n == 0) {
                c.hasher.update(buffer_contents);
                c.input.tossAll();
                {
                    // In the case of flushing, last few lookahead buffers were
                    // smaller than min match len, so only last literal can be
                    // unwritten.
                    assert(c.prev_match == null);
                    try c.addPrevLiteral();
                    c.prev_literal = null;

                    try c.flushTokens(.final);
                }
                switch (c.hasher) {
                    .gzip => |*gzip| {
                        // GZIP 8 bytes footer
                        //  - 4 bytes, CRC32 (CRC-32)
                        //  - 4 bytes, ISIZE (Input SIZE) - size of the original (uncompressed) input data modulo 2^32
                        comptime assert(c.footer_buffer.len == 8);
                        std.mem.writeInt(u32, c.footer_buffer[0..4], gzip.final(), .little);
                        std.mem.writeInt(u32, c.footer_buffer[4..8], gzip.bytes_read, .little);
                        c.state = .{ .footer = 0 };
                    },
                    .zlib => |*zlib| {
                        // ZLIB (RFC 1950) is big-endian, unlike GZIP (RFC 1952).
                        // 4 bytes of ADLER32 (Adler-32 checksum)
                        // Checksum value of the uncompressed data (excluding any
                        // dictionary data) computed according to Adler-32
                        // algorithm.
                        comptime assert(c.footer_buffer.len == 8);
                        std.mem.writeInt(u32, c.footer_buffer[4..8], zlib.final, .big);
                        c.state = .{ .footer = 4 };
                    },
                    .raw => {
                        c.state = .ended;
                    },
                }
            }
            return bw.count - start;
        },
        .ended => return error.EndOfStream,
        .footer => |i| {
            const remaining = c.footer_buffer[i..];
            const n = try bw.write(limit.slice(remaining));
            c.state = if (n == remaining) .ended else .{ .footer = i - n };
            return n;
        },
    }
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

    var enc = huffmanEncoder(19);
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
    const enc = fixedLiteralEncoder();
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
    const enc = fixedDistanceEncoder();
    for (enc.codes) |c| {
        const v = @bitReverse(@as(u5, @intCast(c.code)));
        try testing.expect(v <= 29);
        try testing.expect(c.len == 5);
    }
}

// Reverse bit-by-bit a N-bit code.
fn bitReverse(comptime T: type, value: T, n: usize) T {
    const r = @bitReverse(value);
    return r >> @as(math.Log2Int(T), @intCast(@typeInfo(T).int.bits - n));
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

test "fixedLiteralEncoder codes" {
    var al = std.ArrayList(u8).init(testing.allocator);
    defer al.deinit();
    var bw = std.io.bitWriter(.little, al.writer());

    const f = fixedLiteralEncoder();
    for (f.codes) |c| {
        try bw.writeBits(c.code, c.len);
    }
    try testing.expectEqualSlices(u8, &fixed_codes, al.items);
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

test "tokenization" {
    const L = Token.initLiteral;
    const M = Token.initMatch;

    const cases = [_]struct {
        data: []const u8,
        tokens: []const Token,
    }{
        .{
            .data = "Blah blah blah blah blah!",
            .tokens = &[_]Token{ L('B'), L('l'), L('a'), L('h'), L(' '), L('b'), M(5, 18), L('!') },
        },
        .{
            .data = "ABCDEABCD ABCDEABCD",
            .tokens = &[_]Token{
                L('A'), L('B'),   L('C'), L('D'), L('E'), L('A'), L('B'), L('C'), L('D'), L(' '),
                L('A'), M(10, 8),
            },
        },
    };

    for (cases) |c| {
        inline for (Container.list) |container| { // for each wrapping

            var cw = io.countingWriter(io.null_writer);
            const cww = cw.writer();
            var df = try Compress(container, @TypeOf(cww), TestTokenWriter).init(cww, .{});

            _ = try df.write(c.data);
            try df.flush();

            // df.token_writer.show();
            try expect(df.block_writer.pos == c.tokens.len); // number of tokens written
            try testing.expectEqualSlices(Token, df.block_writer.get(), c.tokens); // tokens match

            try testing.expectEqual(container.headerSize(), cw.bytes_written);
            try df.finish();
            try testing.expectEqual(container.size(), cw.bytes_written);
        }
    }
}

// Tests that tokens written are equal to expected token list.
const TestTokenWriter = struct {
    const Self = @This();

    pos: usize = 0,
    actual: [128]Token = undefined,

    pub fn init(_: anytype) Self {
        return .{};
    }
    pub fn write(self: *Self, tokens: []const Token, _: bool, _: ?[]const u8) !void {
        for (tokens) |t| {
            self.actual[self.pos] = t;
            self.pos += 1;
        }
    }

    pub fn storedBlock(_: *Self, _: []const u8, _: bool) !void {}

    pub fn get(self: *Self) []Token {
        return self.actual[0..self.pos];
    }

    pub fn show(self: *Self) void {
        std.debug.print("\n", .{});
        for (self.get()) |t| {
            t.show();
        }
    }

    pub fn flush(_: *Self) !void {}
};

test "file tokenization" {
    const levels = [_]Level{ .level_4, .level_5, .level_6, .level_7, .level_8, .level_9 };
    const cases = [_]struct {
        data: []const u8, // uncompressed content
        // expected number of tokens producet in deflate tokenization
        tokens_count: [levels.len]usize = .{0} ** levels.len,
    }{
        .{
            .data = @embedFile("testdata/rfc1951.txt"),
            .tokens_count = .{ 7675, 7672, 7599, 7594, 7598, 7599 },
        },

        .{
            .data = @embedFile("testdata/block_writer/huffman-null-max.input"),
            .tokens_count = .{ 257, 257, 257, 257, 257, 257 },
        },
        .{
            .data = @embedFile("testdata/block_writer/huffman-pi.input"),
            .tokens_count = .{ 2570, 2564, 2564, 2564, 2564, 2564 },
        },
        .{
            .data = @embedFile("testdata/block_writer/huffman-text.input"),
            .tokens_count = .{ 235, 234, 234, 234, 234, 234 },
        },
        .{
            .data = @embedFile("testdata/fuzz/roundtrip1.input"),
            .tokens_count = .{ 333, 331, 331, 331, 331, 331 },
        },
        .{
            .data = @embedFile("testdata/fuzz/roundtrip2.input"),
            .tokens_count = .{ 334, 334, 334, 334, 334, 334 },
        },
    };

    for (cases) |case| { // for each case
        const data = case.data;

        for (levels, 0..) |level, i| { // for each compression level
            var original: std.io.BufferedReader = undefined;
            original.initFixed(data);

            // buffer for decompressed data
            var al = std.ArrayList(u8).init(testing.allocator);
            defer al.deinit();
            const writer = al.writer();

            // create compressor
            const WriterType = @TypeOf(writer);
            const TokenWriter = TokenDecoder(@TypeOf(writer));
            var cmp = try Compress(.raw, WriterType, TokenWriter).init(writer, .{ .level = level });

            // Stream uncompressed `original` data to the compressor. It will
            // produce tokens list and pass that list to the TokenDecoder. This
            // TokenDecoder uses CircularBuffer from inflate to convert list of
            // tokens back to the uncompressed stream.
            try cmp.compress(original.reader());
            try cmp.flush();
            const expected_count = case.tokens_count[i];
            const actual = cmp.block_writer.tokens_count;
            if (expected_count == 0) {
                std.debug.print("actual token count {d}\n", .{actual});
            } else {
                try testing.expectEqual(expected_count, actual);
            }

            try testing.expectEqual(data.len, al.items.len);
            try testing.expectEqualSlices(u8, data, al.items);
        }
    }
}

const TokenDecoder = struct {
    output: *std.io.BufferedWriter,
    tokens_count: usize,

    pub fn init(output: *std.io.BufferedWriter) TokenDecoder {
        return .{
            .output = output,
            .tokens_count = 0,
        };
    }

    pub fn write(self: *TokenDecoder, tokens: []const Token, _: bool, _: ?[]const u8) !void {
        self.tokens_count += tokens.len;
        for (tokens) |t| {
            switch (t.kind) {
                .literal => self.hist.write(t.literal()),
                .match => try self.hist.writeMatch(t.length(), t.distance()),
            }
            if (self.hist.free() < 285) try self.flushWin();
        }
        try self.flushWin();
    }

    fn flushWin(self: *TokenDecoder) !void {
        while (true) {
            const buf = self.hist.read();
            if (buf.len == 0) break;
            try self.output.writeAll(buf);
        }
    }
};

test "store simple compressor" {
    const data = "Hello world!";
    const expected = [_]u8{
        0x1, // block type 0, final bit set
        0xc, 0x0, // len = 12
        0xf3, 0xff, // ~len
        'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', '!', //
        //0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x21,
    };

    var fbs: std.io.BufferedReader = undefined;
    fbs.initFixed(data);
    var al = std.ArrayList(u8).init(testing.allocator);
    defer al.deinit();

    var cmp = try store.compressor(.raw, al.writer());
    try cmp.compress(&fbs);
    try cmp.finish();
    try testing.expectEqualSlices(u8, &expected, al.items);

    fbs.initFixed(data);
    try al.resize(0);

    // huffman only compresoor will also emit store block for this small sample
    var hc = try huffman.compressor(.raw, al.writer());
    try hc.compress(&fbs);
    try hc.finish();
    try testing.expectEqualSlices(u8, &expected, al.items);
}

test "sliding window match" {
    const data = "Blah blah blah blah blah!";
    var win: std.io.BufferedWriter = .{};
    try expect(win.write(data) == data.len);
    try expect(win.wp == data.len);
    try expect(win.rp == 0);

    // length between l symbols
    try expect(win.match(1, 6, 0) == 18);
    try expect(win.match(1, 11, 0) == 13);
    try expect(win.match(1, 16, 0) == 8);
    try expect(win.match(1, 21, 0) == 0);

    // position 15 = "blah blah!"
    // position 20 = "blah!"
    try expect(win.match(15, 20, 0) == 4);
    try expect(win.match(15, 20, 3) == 4);
    try expect(win.match(15, 20, 4) == 0);
}

test "sliding window slide" {
    var win: std.io.BufferedWriter = .{};
    win.wp = std.io.BufferedWriter.buffer_len - 11;
    win.rp = std.io.BufferedWriter.buffer_len - 111;
    win.buffer[win.rp] = 0xab;
    try expect(win.lookahead().len == 100);
    try expect(win.tokensBuffer().?.len == win.rp);

    const n = win.slide();
    try expect(n == 32757);
    try expect(win.buffer[win.rp] == 0xab);
    try expect(win.rp == std.io.BufferedWriter.hist_len - 111);
    try expect(win.wp == std.io.BufferedWriter.hist_len - 11);
    try expect(win.lookahead().len == 100);
    try expect(win.tokensBuffer() == null);
}
