const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

const hfd = @import("huffman_decoder.zig");
const BitReader = @import("bit_reader.zig").BitReader;
const CircularBuffer = @import("CircularBuffer.zig");
const Container = @import("container.zig").Container;
const Token = @import("Token.zig");
const codegen_order = @import("consts.zig").huffman.codegen_order;

/// Decompresses deflate bit stream `reader` and writes uncompressed data to the
/// `writer` stream.
pub fn decompress(comptime container: Container, reader: anytype, writer: anytype) !void {
    var d = decompressor(container, reader);
    try d.decompress(writer);
}

/// Inflate decompressor for the reader type.
pub fn decompressor(comptime container: Container, reader: anytype) Inflate(container, @TypeOf(reader)) {
    return Inflate(container, @TypeOf(reader)).init(reader);
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
pub fn Inflate(comptime container: Container, comptime ReaderType: type) type {
    return struct {
        const BitReaderType = BitReader(ReaderType);
        const F = BitReaderType.flag;

        bits: BitReaderType = .{},
        hist: CircularBuffer = .{},
        // Hashes, produces checkusm, of uncompressed data for gzip/zlib footer.
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

        pub const Error = BitReaderType.Error || Container.Error || hfd.Error || error{
            InvalidCode,
            InvalidMatch,
            InvalidBlockType,
            WrongStoredBlockNlen,
            InvalidDynamicBlockHeader,
        };

        pub fn init(rt: ReaderType) Self {
            return .{ .bits = BitReaderType.init(rt) };
        }

        fn blockHeader(self: *Self) !void {
            self.bfinal = try self.bits.read(u1);
            self.block_type = try self.bits.read(u2);
        }

        fn storedBlock(self: *Self) !bool {
            self.bits.alignToByte(); // skip padding until byte boundary
            // everyting after this is byte aligned in stored block
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
            const distance = try self.decodeDistance(try self.bits.readF(u5, F.buffered | F.reverse));
            try self.hist.writeMatch(length, distance);
        }

        inline fn decodeLength(self: *Self, code: u8) !u16 {
            if (code > 28) return error.InvalidCode;
            const ml = Token.matchLength(code);
            return if (ml.extra_bits == 0) // 0 - 5 extra bits
                ml.base
            else
                ml.base + try self.bits.readN(ml.extra_bits, F.buffered);
        }

        fn decodeDistance(self: *Self, code: u8) !u16 {
            if (code > 29) return error.InvalidCode;
            const md = Token.matchDistance(code);
            return if (md.extra_bits == 0) // 0 - 13 extra bits
                md.base
            else
                md.base + try self.bits.readN(md.extra_bits, F.buffered);
        }

        fn dynamicBlockHeader(self: *Self) !void {
            const hlit: u16 = @as(u16, try self.bits.read(u5)) + 257; // number of ll code entries present - 257
            const hdist: u16 = @as(u16, try self.bits.read(u5)) + 1; // number of distance code entries - 1
            const hclen: u8 = @as(u8, try self.bits.read(u4)) + 4; // hclen + 4 code lenths are encoded

            if (hlit > 286 or hdist > 30)
                return error.InvalidDynamicBlockHeader;

            // lengths for code lengths
            var cl_lens = [_]u4{0} ** 19;
            for (0..hclen) |i| {
                cl_lens[codegen_order[i]] = try self.bits.read(u3);
            }
            var cl_dec: hfd.CodegenDecoder = .{};
            try cl_dec.generate(&cl_lens);

            // literal code lengths
            var lit_lens = [_]u4{0} ** (286);
            var pos: usize = 0;
            while (pos < hlit) {
                const sym = try cl_dec.find(try self.bits.peekF(u7, F.reverse));
                try self.bits.shift(sym.code_bits);
                pos += try self.dynamicCodeLength(sym.symbol, &lit_lens, pos);
            }
            if (pos > hlit)
                return error.InvalidDynamicBlockHeader;

            // distance code lenths
            var dst_lens = [_]u4{0} ** (30);
            pos = 0;
            while (pos < hdist) {
                const sym = try cl_dec.find(try self.bits.peekF(u7, F.reverse));
                try self.bits.shift(sym.code_bits);
                pos += try self.dynamicCodeLength(sym.symbol, &dst_lens, pos);
            }
            if (pos > hdist)
                return error.InvalidDynamicBlockHeader;

            try self.lit_dec.generate(&lit_lens);
            try self.dst_dec.generate(&dst_lens);
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
                        try self.bits.fill(5 + 15 + 13); // so we can use buffered reads
                        const length = try self.decodeLength(sym.symbol);
                        const dsm = try self.decodeSymbol(&self.dst_dec);
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
            const sym = try decoder.find(try self.bits.peekF(u15, F.buffered | F.reverse));
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
        pub fn setReader(self: *Self, new_reader: ReaderType) void {
            self.bits.forward_reader = new_reader;
            if (self.state == .end or self.state == .protocol_footer) {
                self.state = .protocol_header;
            }
        }

        // Reads all compressed data from the internal reader and outputs plain
        // (uncompressed) data to the provided writer.
        pub fn decompress(self: *Self, writer: anytype) !void {
            while (try self.next()) |buf| {
                try writer.writeAll(buf);
            }
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
        /// Returned buffer can be any length between 0 and `limit` bytes.
        /// 0 returned bytes means end of stream reached.
        /// With limit=0 returns as much data can. It newer will be more
        /// than 65536 bytes, which is limit of internal buffer.
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

        // Reader interface

        pub const Reader = std.io.Reader(*Self, Error, read);

        /// Returns the number of bytes read. It may be less than buffer.len.
        /// If the number of bytes read is 0, it means end of stream.
        /// End of stream is not an error condition.
        pub fn read(self: *Self, buffer: []u8) Error!usize {
            const out = try self.get(buffer.len);
            @memcpy(buffer[0..out.len], out);
            return out.len;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

test "flate.Inflate struct sizes" {
    var fbs = std.io.fixedBufferStream("");
    const ReaderType = @TypeOf(fbs.reader());
    const inflate_size = @sizeOf(Inflate(.gzip, ReaderType));

    try testing.expectEqual(76320, inflate_size);
    try testing.expectEqual(
        @sizeOf(CircularBuffer) + @sizeOf(hfd.LiteralDecoder) + @sizeOf(hfd.DistanceDecoder) + 48,
        inflate_size,
    );
    try testing.expectEqual(65536 + 8 + 8, @sizeOf(CircularBuffer));
    try testing.expectEqual(8, @sizeOf(Container.raw.Hasher()));
    try testing.expectEqual(24, @sizeOf(BitReader(ReaderType)));
    try testing.expectEqual(6384, @sizeOf(hfd.LiteralDecoder));
    try testing.expectEqual(4336, @sizeOf(hfd.DistanceDecoder));
}

test "flate.Inflate decompress" {
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

test "flate.Inflate gzip decompress" {
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

test "flate.Inflate zlib decompress" {
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

test "flate.Inflate fuzzing tests" {
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
        .{ .input = "puff17", .err = error.InvalidDynamicBlockHeader }, // 25
        .{ .input = "fuzz1", .err = error.InvalidDynamicBlockHeader },
        .{ .input = "fuzz2", .err = error.InvalidDynamicBlockHeader },
        .{ .input = "fuzz3", .err = error.InvalidMatch },
        .{ .input = "fuzz4", .err = error.OversubscribedHuffmanTree },
        .{ .input = "puff18", .err = error.OversubscribedHuffmanTree }, // 30
        .{ .input = "puff19", .err = error.OversubscribedHuffmanTree },
        .{ .input = "puff20", .err = error.OversubscribedHuffmanTree },
        .{ .input = "puff21", .err = error.OversubscribedHuffmanTree },
        .{ .input = "puff22", .err = error.OversubscribedHuffmanTree },
        .{ .input = "puff23", .err = error.InvalidDynamicBlockHeader }, // 35
        .{ .input = "puff24", .err = error.InvalidDynamicBlockHeader },
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
