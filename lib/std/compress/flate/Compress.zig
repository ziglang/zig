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
const assert = std.debug.assert;
const testing = std.testing;
const expect = testing.expect;
const mem = std.mem;
const math = std.math;
const Writer = std.Io.Writer;

const Compress = @This();
const Token = @import("Token.zig");
const BlockWriter = @import("BlockWriter.zig");
const flate = @import("../flate.zig");
const Container = flate.Container;
const Lookup = @import("Lookup.zig");
const HuffmanEncoder = flate.HuffmanEncoder;
const LiteralNode = HuffmanEncoder.LiteralNode;

lookup: Lookup = .{},
tokens: Tokens = .{},
block_writer: BlockWriter,
level: LevelArgs,
hasher: Container.Hasher,
writer: Writer,
state: State,

// Match and literal at the previous position.
// Used for lazy match finding in processWindow.
prev_match: ?Token = null,
prev_literal: ?u8 = null,

pub const State = enum { header, middle, ended };

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

pub const Options = struct {
    level: Level = .default,
    container: Container = .raw,
};

pub fn init(output: *Writer, buffer: []u8, options: Options) Compress {
    return .{
        .block_writer = .{
            .output = output,
            .codegen_freq = undefined,
            .literal_freq = undefined,
            .distance_freq = undefined,
            .codegen = undefined,
            .literal_encoding = undefined,
            .distance_encoding = undefined,
            .codegen_encoding = undefined,
            .fixed_literal_encoding = undefined,
            .fixed_distance_encoding = undefined,
            .huff_distance = undefined,
            .fixed_literal_codes = undefined,
            .fixed_distance_codes = undefined,
            .distance_codes = undefined,
        },
        .level = .get(options.level),
        .hasher = .init(options.container),
        .state = .header,
        .writer = .{
            .buffer = buffer,
            .vtable = &.{ .drain = drain },
        },
    };
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

fn drain(me: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
    _ = data;
    _ = splat;
    const c: *Compress = @fieldParentPtr("writer", me);
    const out = c.block_writer.output;
    switch (c.state) {
        .header => {
            c.state = .middle;
            const header = c.hasher.container().header();
            try out.writeAll(header);
            return header.len;
        },
        .middle => {},
        .ended => unreachable,
    }

    const buffered = me.buffered();
    const min_lookahead = flate.match.min_length + flate.match.max_length;
    const history_plus_lookahead_len = flate.history_len + min_lookahead;
    if (buffered.len < history_plus_lookahead_len) return 0;
    const lookahead = buffered[flate.history_len..];

    _ = lookahead;
    // TODO tokenize
    //c.hasher.update(lookahead[0..n]);
    @panic("TODO");
}

pub fn end(c: *Compress) !void {
    try endUnflushed(c);
    try c.output.flush();
}

pub fn endUnflushed(c: *Compress) !void {
    while (c.writer.end != 0) _ = try drain(&c.writer, &.{""}, 1);
    c.state = .ended;

    const out = c.block_writer.output;

    // TODO flush tokens

    switch (c.hasher) {
        .gzip => |*gzip| {
            // GZIP 8 bytes footer
            //  - 4 bytes, CRC32 (CRC-32)
            //  - 4 bytes, ISIZE (Input SIZE) - size of the original (uncompressed) input data modulo 2^32
            const footer = try out.writableArray(8);
            std.mem.writeInt(u32, footer[0..4], gzip.crc.final(), .little);
            std.mem.writeInt(u32, footer[4..8], @truncate(gzip.count), .little);
        },
        .zlib => |*zlib| {
            // ZLIB (RFC 1950) is big-endian, unlike GZIP (RFC 1952).
            // 4 bytes of ADLER32 (Adler-32 checksum)
            // Checksum value of the uncompressed data (excluding any
            // dictionary data) computed according to Adler-32
            // algorithm.
            std.mem.writeInt(u32, try out.writableArray(4), zlib.final, .big);
        },
        .raw => {},
    }
}

pub const Simple = struct {
    /// Note that store blocks are limited to 65535 bytes.
    buffer: []u8,
    wp: usize,
    block_writer: BlockWriter,
    hasher: Container.Hasher,
    strategy: Strategy,

    pub const Strategy = enum { huffman, store };

    pub fn init(out: *Writer, buffer: []u8, container: Container) !Simple {
        const self: Simple = .{
            .buffer = buffer,
            .wp = 0,
            .block_writer = .init(out),
            .hasher = .init(container),
        };
        try container.writeHeader(self.out);
        return self;
    }

    pub fn flush(self: *Simple) !void {
        try self.flushBuffer(false);
        try self.block_writer.storedBlock("", false);
        try self.block_writer.flush();
    }

    pub fn finish(self: *Simple) !void {
        try self.flushBuffer(true);
        try self.block_writer.flush();
        try self.hasher.container().writeFooter(&self.hasher, self.out);
    }

    fn flushBuffer(self: *Simple, final: bool) !void {
        const buf = self.buffer[0..self.wp];
        switch (self.strategy) {
            .huffman => try self.block_writer.huffmanBlock(buf, final),
            .store => try self.block_writer.storedBlock(buf, final),
        }
        self.wp = 0;
    }
};

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

    var codes: [19]HuffmanEncoder.Code = undefined;
    var enc: HuffmanEncoder = .{ .codes = &codes };
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

            var cw = std.Io.countingWriter(std.Io.null_writer);
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
            var original: std.Io.Reader = .fixed(data);

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
    output: *Writer,
    tokens_count: usize,

    pub fn init(output: *Writer) TokenDecoder {
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
    if (true) return error.SkipZigTest;
    //const data = "Hello world!";
    //const expected = [_]u8{
    //    0x1, // block type 0, final bit set
    //    0xc, 0x0, // len = 12
    //    0xf3, 0xff, // ~len
    //    'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', '!', //
    //    //0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64, 0x21,
    //};

    //var fbs: std.Io.Reader = .fixed(data);
    //var al = std.ArrayList(u8).init(testing.allocator);
    //defer al.deinit();

    //var cmp = try store.compressor(.raw, al.writer());
    //try cmp.compress(&fbs);
    //try cmp.finish();
    //try testing.expectEqualSlices(u8, &expected, al.items);

    //fbs = .fixed(data);
    //try al.resize(0);

    //// huffman only compresoor will also emit store block for this small sample
    //var hc = try huffman.compressor(.raw, al.writer());
    //try hc.compress(&fbs);
    //try hc.finish();
    //try testing.expectEqualSlices(u8, &expected, al.items);
}

test "sliding window match" {
    const data = "Blah blah blah blah blah!";
    var win: Writer = .{};
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
    var win: Writer = .{};
    win.wp = Writer.buffer_len - 11;
    win.rp = Writer.buffer_len - 111;
    win.buffer[win.rp] = 0xab;
    try expect(win.lookahead().len == 100);
    try expect(win.tokensBuffer().?.len == win.rp);

    const n = win.slide();
    try expect(n == 32757);
    try expect(win.buffer[win.rp] == 0xab);
    try expect(win.rp == Writer.hist_len - 111);
    try expect(win.wp == Writer.hist_len - 11);
    try expect(win.lookahead().len == 100);
    try expect(win.tokensBuffer() == null);
}
