const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

const hfd = @import("huffman_decoder.zig");
const CircularBuffer = @import("CircularBuffer.zig");
const Container = @import("container.zig").Container;
const Token = @import("Token.zig");
const codegen_order = @import("consts.zig").huffman.codegen_order;

/// Decompresses deflate bit stream `reader` and writes uncompressed data to the
/// `writer` stream.
pub fn decompress(comptime container: Container, reader: *std.io.BufferedReader, writer: *std.io.BufferedWriter) !void {
    var d = decompressor(container, reader);
    try d.decompress(writer);
}

/// Inflate decompressor for the reader type.
pub fn decompressor(comptime container: Container, reader: *std.io.BufferedReader) Decompressor(container) {
    return Decompressor(container).init(reader);
}

pub fn Decompressor(comptime container: Container) type {
    // zlib has 4 bytes footer, lookahead of 4 bytes ensures that we will not overshoot.
    // gzip has 8 bytes footer so we will not overshoot even with 8 bytes of lookahead.
    // For raw deflate there is always possibility of overshot so we use 8 bytes lookahead.
    const lookahead: type = if (container == .zlib) u32 else u64;
    return Inflate(container, lookahead);
}

/// Inflate decompresses deflate bit stream. Reads compressed data from reader
/// provided in init. Decompressed data are stored in internal hist buffer and
/// can be accesses iterable `next` or reader interface.
///
/// Container defines header/footer wrapper around deflate bit stream. Can be
/// gzip or zlib.
///
/// Deflate bit stream consists of multiple blocks. Block can be one of three types:
///   * stored, non compressed, max 64k in size
///   * fixed, huffman codes are predefined
///   * dynamic, huffman code tables are encoded at the block start
///
/// `step` function runs decoder until internal `hist` buffer is full. Client
/// than needs to read that data in order to proceed with decoding.
///
/// Allocates 74.5K of internal buffers, most important are:
///   * 64K for history (CircularBuffer)
///   * ~10K huffman decoders (Literal and DistanceDecoder)
///
pub fn Inflate(comptime container: Container, comptime Lookahead: type) type {
    assert(Lookahead == u32 or Lookahead == u64);
    const LookaheadBitReader = BitReader(Lookahead);

    return struct {
        bits: LookaheadBitReader,
        hist: CircularBuffer = .{},
        // Hashes, produces checksum, of uncompressed data for gzip/zlib footer.
        hasher: container.Hasher() = .{},

        // dynamic block huffman code decoders
        lit_dec: hfd.LiteralDecoder = .{}, // literals
        dst_dec: hfd.DistanceDecoder = .{}, // distances

        // current read state
        bfinal: u1 = 0,
        block_type: u2 = 0b11,
        state: ReadState = .protocol_header,

        const ReadState = enum {
            protocol_header,
            block_header,
            block,
            protocol_footer,
            end,
        };

        const Self = @This();

        pub const Error = anyerror || Container.Error || hfd.Error || error{
            InvalidCode,
            InvalidMatch,
            InvalidBlockType,
            WrongStoredBlockNlen,
            InvalidDynamicBlockHeader,
        };

        pub fn init(bw: *std.io.BufferedReader) Self {
            return .{ .bits = LookaheadBitReader.init(bw) };
        }

        fn blockHeader(self: *Self) anyerror!void {
            self.bfinal = try self.bits.read(u1);
            self.block_type = try self.bits.read(u2);
        }

        fn storedBlock(self: *Self) !bool {
            self.bits.alignToByte(); // skip padding until byte boundary
            // everything after this is byte aligned in stored block
            var len = try self.bits.read(u16);
            const nlen = try self.bits.read(u16);
            if (len != ~nlen) return error.WrongStoredBlockNlen;

            while (len > 0) {
                const buf = self.hist.getWritable(len);
                try self.bits.readAll(buf);
                len -= @intCast(buf.len);
            }
            return true;
        }

        fn fixedBlock(self: *Self) !bool {
            while (!self.hist.full()) {
                const code = try self.bits.readFixedCode();
                switch (code) {
                    0...255 => self.hist.write(@intCast(code)),
                    256 => return true, // end of block
                    257...285 => try self.fixedDistanceCode(@intCast(code - 257)),
                    else => return error.InvalidCode,
                }
            }
            return false;
        }

        // Handles fixed block non literal (length) code.
        // Length code is followed by 5 bits of distance code.
        fn fixedDistanceCode(self: *Self, code: u8) !void {
            try self.bits.fill(5 + 5 + 13);
            const length = try self.decodeLength(code);
            const distance = try self.decodeDistance(try self.bits.readF(u5, .{
                .buffered = true,
                .reverse = true,
            }));
            try self.hist.writeMatch(length, distance);
        }

        inline fn decodeLength(self: *Self, code: u8) !u16 {
            if (code > 28) return error.InvalidCode;
            const ml = Token.matchLength(code);
            return if (ml.extra_bits == 0) // 0 - 5 extra bits
                ml.base
            else
                ml.base + try self.bits.readN(ml.extra_bits, .{ .buffered = true });
        }

        fn decodeDistance(self: *Self, code: u8) !u16 {
            if (code > 29) return error.InvalidCode;
            const md = Token.matchDistance(code);
            return if (md.extra_bits == 0) // 0 - 13 extra bits
                md.base
            else
                md.base + try self.bits.readN(md.extra_bits, .{ .buffered = true });
        }

        fn dynamicBlockHeader(self: *Self) !void {
            const hlit: u16 = @as(u16, try self.bits.read(u5)) + 257; // number of ll code entries present - 257
            const hdist: u16 = @as(u16, try self.bits.read(u5)) + 1; // number of distance code entries - 1
            const hclen: u8 = @as(u8, try self.bits.read(u4)) + 4; // hclen + 4 code lengths are encoded

            if (hlit > 286 or hdist > 30)
                return error.InvalidDynamicBlockHeader;

            // lengths for code lengths
            var cl_lens = [_]u4{0} ** 19;
            for (0..hclen) |i| {
                cl_lens[codegen_order[i]] = try self.bits.read(u3);
            }
            var cl_dec: hfd.CodegenDecoder = .{};
            try cl_dec.generate(&cl_lens);

            // decoded code lengths
            var dec_lens = [_]u4{0} ** (286 + 30);
            var pos: usize = 0;
            while (pos < hlit + hdist) {
                const sym = try cl_dec.find(try self.bits.peekF(u7, .{ .reverse = true }));
                try self.bits.shift(sym.code_bits);
                pos += try self.dynamicCodeLength(sym.symbol, &dec_lens, pos);
            }
            if (pos > hlit + hdist) {
                return error.InvalidDynamicBlockHeader;
            }

            // literal code lengths to literal decoder
            try self.lit_dec.generate(dec_lens[0..hlit]);

            // distance code lengths to distance decoder
            try self.dst_dec.generate(dec_lens[hlit .. hlit + hdist]);
        }

        // Decode code length symbol to code length. Writes decoded length into
        // lens slice starting at position pos. Returns number of positions
        // advanced.
        fn dynamicCodeLength(self: *Self, code: u16, lens: []u4, pos: usize) !usize {
            if (pos >= lens.len)
                return error.InvalidDynamicBlockHeader;

            switch (code) {
                0...15 => {
                    // Represent code lengths of 0 - 15
                    lens[pos] = @intCast(code);
                    return 1;
                },
                16 => {
                    // Copy the previous code length 3 - 6 times.
                    // The next 2 bits indicate repeat length
                    const n: u8 = @as(u8, try self.bits.read(u2)) + 3;
                    if (pos == 0 or pos + n > lens.len)
                        return error.InvalidDynamicBlockHeader;
                    for (0..n) |i| {
                        lens[pos + i] = lens[pos + i - 1];
                    }
                    return n;
                },
                // Repeat a code length of 0 for 3 - 10 times. (3 bits of length)
                17 => return @as(u8, try self.bits.read(u3)) + 3,
                // Repeat a code length of 0 for 11 - 138 times (7 bits of length)
                18 => return @as(u8, try self.bits.read(u7)) + 11,
                else => return error.InvalidDynamicBlockHeader,
            }
        }

        // In larger archives most blocks are usually dynamic, so decompression
        // performance depends on this function.
        fn dynamicBlock(self: *Self) !bool {
            // Hot path loop!
            while (!self.hist.full()) {
                try self.bits.fill(15); // optimization so other bit reads can be buffered (avoiding one `if` in hot path)
                const sym = try self.decodeSymbol(&self.lit_dec);

                switch (sym.kind) {
                    .literal => self.hist.write(sym.symbol),
                    .match => { // Decode match backreference <length, distance>
                        // fill so we can use buffered reads
                        if (Lookahead == u32)
                            try self.bits.fill(5 + 15)
                        else
                            try self.bits.fill(5 + 15 + 13);
                        const length = try self.decodeLength(sym.symbol);
                        const dsm = try self.decodeSymbol(&self.dst_dec);
                        if (Lookahead == u32) try self.bits.fill(13);
                        const distance = try self.decodeDistance(dsm.symbol);
                        try self.hist.writeMatch(length, distance);
                    },
                    .end_of_block => return true,
                }
            }
            return false;
        }

        // Peek 15 bits from bits reader (maximum code len is 15 bits). Use
        // decoder to find symbol for that code. We then know how many bits is
        // used. Shift bit reader for that much bits, those bits are used. And
        // return symbol.
        fn decodeSymbol(self: *Self, decoder: anytype) !hfd.Symbol {
            const sym = try decoder.find(try self.bits.peekF(u15, .{ .buffered = true, .reverse = true }));
            try self.bits.shift(sym.code_bits);
            return sym;
        }

        fn step(self: *Self) !void {
            switch (self.state) {
                .protocol_header => {
                    try container.parseHeader(&self.bits);
                    self.state = .block_header;
                },
                .block_header => {
                    try self.blockHeader();
                    self.state = .block;
                    if (self.block_type == 2) try self.dynamicBlockHeader();
                },
                .block => {
                    const done = switch (self.block_type) {
                        0 => try self.storedBlock(),
                        1 => try self.fixedBlock(),
                        2 => try self.dynamicBlock(),
                        else => return error.InvalidBlockType,
                    };
                    if (done) {
                        self.state = if (self.bfinal == 1) .protocol_footer else .block_header;
                    }
                },
                .protocol_footer => {
                    self.bits.alignToByte();
                    try container.parseFooter(&self.hasher, &self.bits);
                    self.state = .end;
                },
                .end => {},
            }
        }

        /// Replaces the inner reader with new reader.
        pub fn setReader(self: *Self, new_reader: *std.io.BufferedReader) void {
            self.bits.forward_reader = new_reader;
            if (self.state == .end or self.state == .protocol_footer) {
                self.state = .protocol_header;
            }
        }

        // Reads all compressed data from the internal reader and outputs plain
        // (uncompressed) data to the provided writer.
        pub fn decompress(self: *Self, writer: *std.io.BufferedWriter) !void {
            while (try self.next()) |buf| {
                try writer.writeAll(buf);
            }
        }

        /// Returns the number of bytes that have been read from the internal
        /// reader but not yet consumed by the decompressor.
        pub fn unreadBytes(self: Self) usize {
            // There can be no error here: the denominator is not zero, and
            // overflow is not possible since the type is unsigned.
            return std.math.divCeil(usize, self.bits.nbits, 8) catch unreachable;
        }

        // Iterator interface

        /// Can be used in iterator like loop without memcpy to another buffer:
        ///   while (try inflate.next()) |buf| { ... }
        pub fn next(self: *Self) Error!?[]const u8 {
            const out = try self.get(0);
            if (out.len == 0) return null;
            return out;
        }

        /// Returns decompressed data from internal sliding window buffer.
        /// Returned buffer can be any length between 0 and `limit` bytes. 0
        /// returned bytes means end of stream reached. With limit=0 returns as
        /// much data it can. It newer will be more than 65536 bytes, which is
        /// size of internal buffer.
        /// TODO merge this logic into reader_streamRead and reader_streamReadVec
        pub fn get(self: *Self, limit: usize) Error![]const u8 {
            while (true) {
                const out = self.hist.readAtMost(limit);
                if (out.len > 0) {
                    self.hasher.update(out);
                    return out;
                }
                if (self.state == .end) return out;
                try self.step();
            }
        }

        fn reader_streamRead(
            ctx: ?*anyopaque,
            bw: *std.io.BufferedWriter,
            limit: std.io.Reader.Limit,
        ) anyerror!std.io.Reader.Status {
            const self: *Self = @alignCast(@ptrCast(ctx));
            const out = try bw.writableSlice(1);
            const in = try self.get(limit.min(out.len));
            @memcpy(out[0..in.len], in);
            bw.advance(in.len);
            return .{ .len = in.len, .end = in.len == 0 };
        }

        fn reader_streamReadVec(ctx: ?*anyopaque, data: []const []u8) anyerror!std.io.Reader.Status {
            const self: *Self = @alignCast(@ptrCast(ctx));
            for (data) |out| {
                if (out.len == 0) continue;
                const in = try self.get(out.len);
                @memcpy(out[0..in.len], in);
                return .{ .len = @intCast(in.len), .end = in.len == 0 };
            }
            return .{};
        }

        pub fn streamReadVec(self: *Self, data: []const []u8) anyerror!std.io.Reader.Status {
            return reader_streamReadVec(self, data);
        }

        pub fn reader(self: *Self) std.io.Reader {
            return .{
                .context = self,
                .vtable = &.{
                    .posRead = null,
                    .posReadVec = null,
                    .streamRead = reader_streamRead,
                    .streamReadVec = reader_streamReadVec,
                },
            };
        }
    };
}

test "decompress" {
    const cases = [_]struct {
        in: []const u8,
        out: []const u8,
    }{
        // non compressed block (type 0)
        .{
            .in = &[_]u8{
                0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
                'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a, // non compressed data
            },
            .out = "Hello world\n",
        },
        // fixed code block (type 1)
        .{
            .in = &[_]u8{
                0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0x28, 0xcf, // deflate data block type 1
                0x2f, 0xca, 0x49, 0xe1, 0x02, 0x00,
            },
            .out = "Hello world\n",
        },
        // dynamic block (type 2)
        .{
            .in = &[_]u8{
                0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02, // deflate data block type 2
                0x30, 0x2b, 0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38,
                0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01,
            },
            .out = "ABCDEABCD ABCDEABCD",
        },
    };
    for (cases) |c| {
        var fb = std.io.fixedBufferStream(c.in);
        var al = std.ArrayList(u8).init(testing.allocator);
        defer al.deinit();

        try decompress(.raw, fb.reader(), al.writer());
        try testing.expectEqualStrings(c.out, al.items);
    }
}

test "gzip decompress" {
    const cases = [_]struct {
        in: []const u8,
        out: []const u8,
    }{
        // non compressed block (type 0)
        .{
            .in = &[_]u8{
                0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, // gzip header (10 bytes)
                0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
                'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a, // non compressed data
                0xd5, 0xe0, 0x39, 0xb7, // gzip footer: checksum
                0x0c, 0x00, 0x00, 0x00, // gzip footer: size
            },
            .out = "Hello world\n",
        },
        // fixed code block (type 1)
        .{
            .in = &[_]u8{
                0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, // gzip header (10 bytes)
                0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0x28, 0xcf, // deflate data block type 1
                0x2f, 0xca, 0x49, 0xe1, 0x02, 0x00,
                0xd5, 0xe0, 0x39, 0xb7, 0x0c, 0x00, 0x00, 0x00, // gzip footer (chksum, len)
            },
            .out = "Hello world\n",
        },
        // dynamic block (type 2)
        .{
            .in = &[_]u8{
                0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, // gzip header (10 bytes)
                0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02, // deflate data block type 2
                0x30, 0x2b, 0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38,
                0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01,
                0x17, 0x1c, 0x39, 0xb4, 0x13, 0x00, 0x00, 0x00, // gzip footer (chksum, len)
            },
            .out = "ABCDEABCD ABCDEABCD",
        },
        // gzip header with name
        .{
            .in = &[_]u8{
                0x1f, 0x8b, 0x08, 0x08, 0xe5, 0x70, 0xb1, 0x65, 0x00, 0x03, 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x2e,
                0x74, 0x78, 0x74, 0x00, 0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0x28, 0xcf, 0x2f, 0xca, 0x49, 0xe1,
                0x02, 0x00, 0xd5, 0xe0, 0x39, 0xb7, 0x0c, 0x00, 0x00, 0x00,
            },
            .out = "Hello world\n",
        },
    };
    for (cases) |c| {
        var fb = std.io.fixedBufferStream(c.in);
        var al = std.ArrayList(u8).init(testing.allocator);
        defer al.deinit();

        try decompress(.gzip, fb.reader(), al.writer());
        try testing.expectEqualStrings(c.out, al.items);
    }
}

test "zlib decompress" {
    const cases = [_]struct {
        in: []const u8,
        out: []const u8,
    }{
        // non compressed block (type 0)
        .{
            .in = &[_]u8{
                0x78, 0b10_0_11100, // zlib header (2 bytes)
                0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
                'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a, // non compressed data
                0x1c, 0xf2, 0x04, 0x47, // zlib footer: checksum
            },
            .out = "Hello world\n",
        },
    };
    for (cases) |c| {
        var fb = std.io.fixedBufferStream(c.in);
        var al = std.ArrayList(u8).init(testing.allocator);
        defer al.deinit();

        try decompress(.zlib, fb.reader(), al.writer());
        try testing.expectEqualStrings(c.out, al.items);
    }
}

test "fuzzing tests" {
    const cases = [_]struct {
        input: []const u8,
        out: []const u8 = "",
        err: ?anyerror = null,
    }{
        .{ .input = "deflate-stream", .out = @embedFile("testdata/fuzz/deflate-stream.expect") }, // 0
        .{ .input = "empty-distance-alphabet01" },
        .{ .input = "empty-distance-alphabet02" },
        .{ .input = "end-of-stream", .err = error.EndOfStream },
        .{ .input = "invalid-distance", .err = error.InvalidMatch },
        .{ .input = "invalid-tree01", .err = error.IncompleteHuffmanTree }, // 5
        .{ .input = "invalid-tree02", .err = error.IncompleteHuffmanTree },
        .{ .input = "invalid-tree03", .err = error.IncompleteHuffmanTree },
        .{ .input = "lengths-overflow", .err = error.InvalidDynamicBlockHeader },
        .{ .input = "out-of-codes", .err = error.InvalidCode },
        .{ .input = "puff01", .err = error.WrongStoredBlockNlen }, // 10
        .{ .input = "puff02", .err = error.EndOfStream },
        .{ .input = "puff03", .out = &[_]u8{0xa} },
        .{ .input = "puff04", .err = error.InvalidCode },
        .{ .input = "puff05", .err = error.EndOfStream },
        .{ .input = "puff06", .err = error.EndOfStream },
        .{ .input = "puff08", .err = error.InvalidCode },
        .{ .input = "puff09", .out = "P" },
        .{ .input = "puff10", .err = error.InvalidCode },
        .{ .input = "puff11", .err = error.InvalidMatch },
        .{ .input = "puff12", .err = error.InvalidDynamicBlockHeader }, // 20
        .{ .input = "puff13", .err = error.IncompleteHuffmanTree },
        .{ .input = "puff14", .err = error.EndOfStream },
        .{ .input = "puff15", .err = error.IncompleteHuffmanTree },
        .{ .input = "puff16", .err = error.InvalidDynamicBlockHeader },
        .{ .input = "puff17", .err = error.MissingEndOfBlockCode }, // 25
        .{ .input = "fuzz1", .err = error.InvalidDynamicBlockHeader },
        .{ .input = "fuzz2", .err = error.InvalidDynamicBlockHeader },
        .{ .input = "fuzz3", .err = error.InvalidMatch },
        .{ .input = "fuzz4", .err = error.OversubscribedHuffmanTree },
        .{ .input = "puff18", .err = error.OversubscribedHuffmanTree }, // 30
        .{ .input = "puff19", .err = error.OversubscribedHuffmanTree },
        .{ .input = "puff20", .err = error.OversubscribedHuffmanTree },
        .{ .input = "puff21", .err = error.OversubscribedHuffmanTree },
        .{ .input = "puff22", .err = error.OversubscribedHuffmanTree },
        .{ .input = "puff23", .err = error.OversubscribedHuffmanTree }, // 35
        .{ .input = "puff24", .err = error.IncompleteHuffmanTree },
        .{ .input = "puff25", .err = error.OversubscribedHuffmanTree },
        .{ .input = "puff26", .err = error.InvalidDynamicBlockHeader },
        .{ .input = "puff27", .err = error.InvalidDynamicBlockHeader },
    };

    inline for (cases, 0..) |c, case_no| {
        var in = std.io.fixedBufferStream(@embedFile("testdata/fuzz/" ++ c.input ++ ".input"));
        var out = std.ArrayList(u8).init(testing.allocator);
        defer out.deinit();
        errdefer std.debug.print("test case failed {}\n", .{case_no});

        if (c.err) |expected_err| {
            try testing.expectError(expected_err, decompress(.raw, in.reader(), out.writer()));
        } else {
            try decompress(.raw, in.reader(), out.writer());
            try testing.expectEqualStrings(c.out, out.items);
        }
    }
}

test "bug 18966" {
    const input = @embedFile("testdata/fuzz/bug_18966.input");
    const expect = @embedFile("testdata/fuzz/bug_18966.expect");

    var in = std.io.fixedBufferStream(input);
    var out = std.ArrayList(u8).init(testing.allocator);
    defer out.deinit();

    try decompress(.gzip, in.reader(), out.writer());
    try testing.expectEqualStrings(expect, out.items);
}

test "bug 19895" {
    const input = &[_]u8{
        0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
        'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a, // non compressed data
    };
    var in = std.io.fixedBufferStream(input);
    var decomp = decompressor(.raw, in.reader());
    var buf: [0]u8 = undefined;
    try testing.expectEqual(0, try decomp.read(&buf));
}

/// Bit reader used during inflate (decompression). Has internal buffer of 64
/// bits which shifts right after bits are consumed. Uses forward_reader to fill
/// that internal buffer when needed.
///
/// readF is the core function. Supports few different ways of getting bits
/// controlled by flags. In hot path we try to avoid checking whether we need to
/// fill buffer from forward_reader by calling fill in advance and readF with
/// buffered flag set.
///
pub fn BitReader(comptime T: type) type {
    assert(T == u32 or T == u64);
    const t_bytes: usize = @sizeOf(T);
    const Tshift = if (T == u64) u6 else u5;

    return struct {
        // Underlying reader used for filling internal bits buffer
        forward_reader: *std.io.BufferedReader,
        // Internal buffer of 64 bits
        bits: T = 0,
        // Number of bits in the buffer
        nbits: u32 = 0,

        const Self = @This();

        pub const Flags = packed struct(u3) {
            /// dont advance internal buffer, just get bits, leave them in buffer
            peek: bool = false,
            /// assume that there is no need to fill, fill should be called before
            buffered: bool = false,
            /// bit reverse read bits
            reverse: bool = false,

            /// work around https://github.com/ziglang/zig/issues/18882
            pub inline fn toInt(f: Flags) u3 {
                return @bitCast(f);
            }
        };

        pub fn init(forward_reader: *std.io.BufferedReader) Self {
            var self = Self{ .forward_reader = forward_reader };
            self.fill(1) catch {};
            return self;
        }

        /// Try to have `nice` bits are available in buffer. Reads from
        /// forward reader if there is no `nice` bits in buffer. Returns error
        /// if end of forward stream is reached and internal buffer is empty.
        /// It will not error if less than `nice` bits are in buffer, only when
        /// all bits are exhausted. During inflate we usually know what is the
        /// maximum bits for the next step but usually that step will need less
        /// bits to decode. So `nice` is not hard limit, it will just try to have
        /// that number of bits available. If end of forward stream is reached
        /// it may be some extra zero bits in buffer.
        pub fn fill(self: *Self, nice: u6) !void {
            if (self.nbits >= nice and nice != 0) {
                return; // We have enough bits
            }
            // Read more bits from forward reader

            // Number of empty bytes in bits, round nbits to whole bytes.
            const empty_bytes =
                @as(u8, if (self.nbits & 0x7 == 0) t_bytes else t_bytes - 1) - // 8 for 8, 16, 24..., 7 otherwise
                (self.nbits >> 3); // 0 for 0-7, 1 for 8-16, ... same as / 8

            var buf: [t_bytes]u8 = [_]u8{0} ** t_bytes;
            const bytes_read = self.forward_reader.partialRead(buf[0..empty_bytes]) catch 0;
            if (bytes_read > 0) {
                const u: T = std.mem.readInt(T, buf[0..t_bytes], .little);
                self.bits |= u << @as(Tshift, @intCast(self.nbits));
                self.nbits += 8 * @as(u8, @intCast(bytes_read));
                return;
            }

            if (self.nbits == 0)
                return error.EndOfStream;
        }

        /// Read exactly buf.len bytes into buf.
        pub fn readAll(self: *Self, buf: []u8) anyerror!void {
            assert(self.alignBits() == 0); // internal bits must be at byte boundary

            // First read from internal bits buffer.
            var n: usize = 0;
            while (self.nbits > 0 and n < buf.len) {
                buf[n] = try self.readF(u8, .{ .buffered = true });
                n += 1;
            }
            // Then use forward reader for all other bytes.
            try self.forward_reader.read(buf[n..]);
        }

        /// Alias for readF(U, 0).
        pub fn read(self: *Self, comptime U: type) !U {
            return self.readF(U, .{});
        }

        /// Alias for readF with flag.peak set.
        pub inline fn peekF(self: *Self, comptime U: type, comptime how: Flags) !U {
            return self.readF(U, .{
                .peek = true,
                .buffered = how.buffered,
                .reverse = how.reverse,
            });
        }

        /// Read with flags provided.
        pub fn readF(self: *Self, comptime U: type, comptime how: Flags) !U {
            if (U == T) {
                assert(how.toInt() == 0);
                assert(self.alignBits() == 0);
                try self.fill(@bitSizeOf(T));
                if (self.nbits != @bitSizeOf(T)) return error.EndOfStream;
                const v = self.bits;
                self.nbits = 0;
                self.bits = 0;
                return v;
            }
            const n: Tshift = @bitSizeOf(U);
            // work around https://github.com/ziglang/zig/issues/18882
            switch (how.toInt()) {
                @as(Flags, .{}).toInt() => { // `normal` read
                    try self.fill(n); // ensure that there are n bits in the buffer
                    const u: U = @truncate(self.bits); // get n bits
                    try self.shift(n); // advance buffer for n
                    return u;
                },
                @as(Flags, .{ .peek = true }).toInt() => { // no shift, leave bits in the buffer
                    try self.fill(n);
                    return @truncate(self.bits);
                },
                @as(Flags, .{ .buffered = true }).toInt() => { // no fill, assume that buffer has enough bits
                    const u: U = @truncate(self.bits);
                    try self.shift(n);
                    return u;
                },
                @as(Flags, .{ .reverse = true }).toInt() => { // same as 0 with bit reverse
                    try self.fill(n);
                    const u: U = @truncate(self.bits);
                    try self.shift(n);
                    return @bitReverse(u);
                },
                @as(Flags, .{ .peek = true, .reverse = true }).toInt() => {
                    try self.fill(n);
                    return @bitReverse(@as(U, @truncate(self.bits)));
                },
                @as(Flags, .{ .buffered = true, .reverse = true }).toInt() => {
                    const u: U = @truncate(self.bits);
                    try self.shift(n);
                    return @bitReverse(u);
                },
                @as(Flags, .{ .peek = true, .buffered = true }).toInt() => {
                    return @truncate(self.bits);
                },
                @as(Flags, .{ .peek = true, .buffered = true, .reverse = true }).toInt() => {
                    return @bitReverse(@as(U, @truncate(self.bits)));
                },
            }
        }

        /// Read n number of bits.
        /// Only buffered flag can be used in how.
        pub fn readN(self: *Self, n: u4, comptime how: Flags) !u16 {
            // work around https://github.com/ziglang/zig/issues/18882
            switch (how.toInt()) {
                @as(Flags, .{}).toInt() => {
                    try self.fill(n);
                },
                @as(Flags, .{ .buffered = true }).toInt() => {},
                else => unreachable,
            }
            const mask: u16 = (@as(u16, 1) << n) - 1;
            const u: u16 = @as(u16, @truncate(self.bits)) & mask;
            try self.shift(n);
            return u;
        }

        /// Advance buffer for n bits.
        pub fn shift(self: *Self, n: Tshift) !void {
            if (n > self.nbits) return error.EndOfStream;
            self.bits >>= n;
            self.nbits -= n;
        }

        /// Skip n bytes.
        pub fn skipBytes(self: *Self, n: u16) !void {
            for (0..n) |_| {
                try self.fill(8);
                try self.shift(8);
            }
        }

        // Number of bits to align stream to the byte boundary.
        fn alignBits(self: *Self) u3 {
            return @intCast(self.nbits & 0x7);
        }

        /// Align stream to the byte boundary.
        pub fn alignToByte(self: *Self) void {
            const ab = self.alignBits();
            if (ab > 0) self.shift(ab) catch unreachable;
        }

        /// Skip zero terminated string.
        pub fn skipStringZ(self: *Self) !void {
            while (true) {
                if (try self.readF(u8, 0) == 0) break;
            }
        }

        /// Read deflate fixed fixed code.
        /// Reads first 7 bits, and then maybe 1 or 2 more to get full 7,8 or 9 bit code.
        /// ref: https://datatracker.ietf.org/doc/html/rfc1951#page-12
        ///         Lit Value    Bits        Codes
        ///          ---------    ----        -----
        ///            0 - 143     8          00110000 through
        ///                                   10111111
        ///          144 - 255     9          110010000 through
        ///                                   111111111
        ///          256 - 279     7          0000000 through
        ///                                   0010111
        ///          280 - 287     8          11000000 through
        ///                                   11000111
        pub fn readFixedCode(self: *Self) !u16 {
            try self.fill(7 + 2);
            const code7 = try self.readF(u7, .{ .buffered = true, .reverse = true });
            if (code7 <= 0b0010_111) { // 7 bits, 256-279, codes 0000_000 - 0010_111
                return @as(u16, code7) + 256;
            } else if (code7 <= 0b1011_111) { // 8 bits, 0-143, codes 0011_0000 through 1011_1111
                return (@as(u16, code7) << 1) + @as(u16, try self.readF(u1, .{ .buffered = true })) - 0b0011_0000;
            } else if (code7 <= 0b1100_011) { // 8 bit, 280-287, codes 1100_0000 - 1100_0111
                return (@as(u16, code7 - 0b1100000) << 1) + try self.readF(u1, .{ .buffered = true }) + 280;
            } else { // 9 bit, 144-255, codes 1_1001_0000 - 1_1111_1111
                return (@as(u16, code7 - 0b1100_100) << 2) + @as(u16, try self.readF(u2, .{ .buffered = true, .reverse = true })) + 144;
            }
        }
    };
}

test "readF" {
    var input: std.io.BufferedReader = undefined;
    input.initFixed(&[_]u8{ 0xf3, 0x48, 0xcd, 0xc9, 0x00, 0x00 });
    var br: BitReader(u64) = .init(&input);

    try testing.expectEqual(@as(u8, 48), br.nbits);
    try testing.expectEqual(@as(u64, 0xc9cd48f3), br.bits);

    try testing.expect(try br.readF(u1, 0) == 0b0000_0001);
    try testing.expect(try br.readF(u2, 0) == 0b0000_0001);
    try testing.expectEqual(@as(u8, 48 - 3), br.nbits);
    try testing.expectEqual(@as(u3, 5), br.alignBits());

    try testing.expect(try br.readF(u8, .{ .peek = true }) == 0b0001_1110);
    try testing.expect(try br.readF(u9, .{ .peek = true }) == 0b1_0001_1110);
    try br.shift(9);
    try testing.expectEqual(@as(u8, 36), br.nbits);
    try testing.expectEqual(@as(u3, 4), br.alignBits());

    try testing.expect(try br.readF(u4, 0) == 0b0100);
    try testing.expectEqual(@as(u8, 32), br.nbits);
    try testing.expectEqual(@as(u3, 0), br.alignBits());

    try br.shift(1);
    try testing.expectEqual(@as(u3, 7), br.alignBits());
    try br.shift(1);
    try testing.expectEqual(@as(u3, 6), br.alignBits());
    br.alignToByte();
    try testing.expectEqual(@as(u3, 0), br.alignBits());

    try testing.expectEqual(@as(u64, 0xc9), br.bits);
    try testing.expectEqual(@as(u16, 0x9), try br.readN(4, 0));
    try testing.expectEqual(@as(u16, 0xc), try br.readN(4, 0));
}

test "read block type 1 data" {
    inline for ([_]type{ u64, u32 }) |T| {
        const data = [_]u8{
            0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0x28, 0xcf, // deflate data block type 1
            0x2f, 0xca, 0x49, 0xe1, 0x02, 0x00,
            0x0c, 0x01, 0x02, 0x03, //
            0xaa, 0xbb, 0xcc, 0xdd,
        };
        var fbs: std.io.BufferedReader = undefined;
        fbs.initFixed(&data);
        var br: BitReader(T) = .init(&fbs);

        try testing.expectEqual(@as(u1, 1), try br.readF(u1, 0)); // bfinal
        try testing.expectEqual(@as(u2, 1), try br.readF(u2, 0)); // block_type

        for ("Hello world\n") |c| {
            try testing.expectEqual(@as(u8, c), try br.readF(u8, .{ .reverse = true }) - 0x30);
        }
        try testing.expectEqual(@as(u7, 0), try br.readF(u7, 0)); // end of block
        br.alignToByte();
        try testing.expectEqual(@as(u32, 0x0302010c), try br.readF(u32, 0));
        try testing.expectEqual(@as(u16, 0xbbaa), try br.readF(u16, 0));
        try testing.expectEqual(@as(u16, 0xddcc), try br.readF(u16, 0));
    }
}

test "shift/fill" {
    const data = [_]u8{
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
    };
    var fbs: std.io.BufferedReader = undefined;
    fbs.initFixed(&data);
    var br: BitReader(u64) = .init(&fbs);

    try testing.expectEqual(@as(u64, 0x08_07_06_05_04_03_02_01), br.bits);
    try br.shift(8);
    try testing.expectEqual(@as(u64, 0x00_08_07_06_05_04_03_02), br.bits);
    try br.fill(60); // fill with 1 byte
    try testing.expectEqual(@as(u64, 0x01_08_07_06_05_04_03_02), br.bits);
    try br.shift(8 * 4 + 4);
    try testing.expectEqual(@as(u64, 0x00_00_00_00_00_10_80_70), br.bits);

    try br.fill(60); // fill with 4 bytes (shift by 4)
    try testing.expectEqual(@as(u64, 0x00_50_40_30_20_10_80_70), br.bits);
    try testing.expectEqual(@as(u8, 8 * 7 + 4), br.nbits);

    try br.shift(@intCast(br.nbits)); // clear buffer
    try br.fill(8); // refill with the rest of the bytes
    try testing.expectEqual(@as(u64, 0x00_00_00_00_00_08_07_06), br.bits);
}

test "readAll" {
    inline for ([_]type{ u64, u32 }) |T| {
        const data = [_]u8{
            0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
            0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        };
        var fbs: std.io.BufferedReader = undefined;
        fbs.initFixed(&data);
        var br: BitReader(T) = .init(&fbs);

        switch (T) {
            u64 => try testing.expectEqual(@as(u64, 0x08_07_06_05_04_03_02_01), br.bits),
            u32 => try testing.expectEqual(@as(u32, 0x04_03_02_01), br.bits),
            else => unreachable,
        }

        var out: [16]u8 = undefined;
        try br.readAll(out[0..]);
        try testing.expect(br.nbits == 0);
        try testing.expect(br.bits == 0);

        try testing.expectEqualSlices(u8, data[0..16], &out);
    }
}

test "readFixedCode" {
    inline for ([_]type{ u64, u32 }) |T| {
        const fixed_codes = @import("huffman_encoder.zig").fixed_codes;

        var fbs: std.io.BufferedReader = undefined;
        fbs.initFixed(&fixed_codes);
        var rdr: BitReader(T) = .init(&fbs);

        for (0..286) |c| {
            try testing.expectEqual(c, try rdr.readFixedCode());
        }
        try testing.expect(rdr.nbits == 0);
    }
}

test "u32 leaves no bits on u32 reads" {
    const data = [_]u8{
        0xff, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
    };
    var fbs: std.io.BufferedReader = undefined;
    fbs.initFixed(&data);
    var br: BitReader(u32) = .init(&fbs);

    _ = try br.read(u3);
    try testing.expectEqual(29, br.nbits);
    br.alignToByte();
    try testing.expectEqual(24, br.nbits);
    try testing.expectEqual(0x04_03_02_01, try br.read(u32));
    try testing.expectEqual(0, br.nbits);
    try testing.expectEqual(0x08_07_06_05, try br.read(u32));
    try testing.expectEqual(0, br.nbits);

    _ = try br.read(u9);
    try testing.expectEqual(23, br.nbits);
    br.alignToByte();
    try testing.expectEqual(16, br.nbits);
    try testing.expectEqual(0x0e_0d_0c_0b, try br.read(u32));
    try testing.expectEqual(0, br.nbits);
}

test "u64 need fill after alignToByte" {
    const data = [_]u8{
        0xff, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
    };

    // without fill
    var fbs: std.io.BufferedReader = undefined;
    fbs.initFixed(&data);
    var br: BitReader(u64) = .init(&fbs);
    _ = try br.read(u23);
    try testing.expectEqual(41, br.nbits);
    br.alignToByte();
    try testing.expectEqual(40, br.nbits);
    try testing.expectEqual(0x06_05_04_03, try br.read(u32));
    try testing.expectEqual(8, br.nbits);
    try testing.expectEqual(0x0a_09_08_07, try br.read(u32));
    try testing.expectEqual(32, br.nbits);

    // fill after align ensures all bits filled
    fbs.reset();
    br = .init(&fbs);
    _ = try br.read(u23);
    try testing.expectEqual(41, br.nbits);
    br.alignToByte();
    try br.fill(0);
    try testing.expectEqual(64, br.nbits);
    try testing.expectEqual(0x06_05_04_03, try br.read(u32));
    try testing.expectEqual(32, br.nbits);
    try testing.expectEqual(0x0a_09_08_07, try br.read(u32));
    try testing.expectEqual(0, br.nbits);
}
