const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const bu = @import("bits_utils.zig");
const ddec = @import("dict_decoder.zig");
const deflate_const = @import("deflate_const.zig");

const max_match_offset = deflate_const.max_match_offset;
const end_block_marker = deflate_const.end_block_marker;

const max_code_len = 16; // max length of Huffman code
// The next three numbers come from the RFC section 3.2.7, with the
// additional proviso in section 3.2.5 which implies that distance codes
// 30 and 31 should never occur in compressed data.
const max_num_lit = 286;
const max_num_dist = 30;
const num_codes = 19; // number of codes in Huffman meta-code

var corrupt_input_error_offset: u64 = undefined;

const InflateError = error{
    CorruptInput, // A CorruptInput error reports the presence of corrupt input at a given offset.
    BadInternalState, // An BadInternalState reports an error in the flate code itself.
    BadReaderState, // An error was encountered while accessing the inner reader
    UnexpectedEndOfStream,
    EndOfStreamWithNoError,
};

// The data structure for decoding Huffman tables is based on that of
// zlib. There is a lookup table of a fixed bit width (huffman_chunk_bits),
// For codes smaller than the table width, there are multiple entries
// (each combination of trailing bits has the same value). For codes
// larger than the table width, the table contains a link to an overflow
// table. The width of each entry in the link table is the maximum code
// size minus the chunk width.
//
// Note that you can do a lookup in the table even without all bits
// filled. Since the extra bits are zero, and the DEFLATE Huffman codes
// have the property that shorter codes come before longer ones, the
// bit length estimate in the result is a lower bound on the actual
// number of bits.
//
// See the following:
//	https://github.com/madler/zlib/raw/master/doc/algorithm.txt

// chunk & 15 is number of bits
// chunk >> 4 is value, including table link

const huffman_chunk_bits = 9;
const huffman_num_chunks = 1 << huffman_chunk_bits; // 512
const huffman_count_mask = 15; // 0b1111
const huffman_value_shift = 4;

const HuffmanDecoder = struct {
    const Self = @This();

    allocator: Allocator = undefined,

    min: u32 = 0, // the minimum code length
    chunks: [huffman_num_chunks]u16 = [1]u16{0} ** huffman_num_chunks, // chunks as described above
    links: [][]u16 = undefined, // overflow links
    link_mask: u32 = 0, // mask the width of the link table
    initialized: bool = false,
    sub_chunks: ArrayList(u32) = undefined,

    // Initialize Huffman decoding tables from array of code lengths.
    // Following this function, self is guaranteed to be initialized into a complete
    // tree (i.e., neither over-subscribed nor under-subscribed). The exception is a
    // degenerate case where the tree has only a single symbol with length 1. Empty
    // trees are permitted.
    fn init(self: *Self, allocator: Allocator, lengths: []u32) !bool {

        // Sanity enables additional runtime tests during Huffman
        // table construction. It's intended to be used during
        // development and debugging
        const sanity = false;

        if (self.min != 0) {
            self.* = HuffmanDecoder{};
        }

        self.allocator = allocator;

        // Count number of codes of each length,
        // compute min and max length.
        var count: [max_code_len]u32 = [1]u32{0} ** max_code_len;
        var min: u32 = 0;
        var max: u32 = 0;
        for (lengths) |n| {
            if (n == 0) {
                continue;
            }
            if (min == 0) {
                min = n;
            }
            min = @min(n, min);
            max = @max(n, max);
            count[n] += 1;
        }

        // Empty tree. The decompressor.huffSym function will fail later if the tree
        // is used. Technically, an empty tree is only valid for the HDIST tree and
        // not the HCLEN and HLIT tree. However, a stream with an empty HCLEN tree
        // is guaranteed to fail since it will attempt to use the tree to decode the
        // codes for the HLIT and HDIST trees. Similarly, an empty HLIT tree is
        // guaranteed to fail later since the compressed data section must be
        // composed of at least one symbol (the end-of-block marker).
        if (max == 0) {
            return true;
        }

        var next_code: [max_code_len]u32 = [1]u32{0} ** max_code_len;
        var code: u32 = 0;
        {
            var i = min;
            while (i <= max) : (i += 1) {
                code <<= 1;
                next_code[i] = code;
                code += count[i];
            }
        }

        // Check that the coding is complete (i.e., that we've
        // assigned all 2-to-the-max possible bit sequences).
        // Exception: To be compatible with zlib, we also need to
        // accept degenerate single-code codings. See also
        // TestDegenerateHuffmanCoding.
        if (code != @as(u32, 1) << @as(u5, @intCast(max)) and !(code == 1 and max == 1)) {
            return false;
        }

        self.min = min;
        if (max > huffman_chunk_bits) {
            var num_links = @as(u32, 1) << @as(u5, @intCast(max - huffman_chunk_bits));
            self.link_mask = @as(u32, @intCast(num_links - 1));

            // create link tables
            var link = next_code[huffman_chunk_bits + 1] >> 1;
            self.links = try self.allocator.alloc([]u16, huffman_num_chunks - link);
            self.sub_chunks = ArrayList(u32).init(self.allocator);
            self.initialized = true;
            var j = @as(u32, @intCast(link));
            while (j < huffman_num_chunks) : (j += 1) {
                var reverse = @as(u32, @intCast(bu.bitReverse(u16, @as(u16, @intCast(j)), 16)));
                reverse >>= @as(u32, @intCast(16 - huffman_chunk_bits));
                var off = j - @as(u32, @intCast(link));
                if (sanity) {
                    // check we are not overwriting an existing chunk
                    assert(self.chunks[reverse] == 0);
                }
                self.chunks[reverse] = @as(u16, @intCast(off << huffman_value_shift | (huffman_chunk_bits + 1)));
                self.links[off] = try self.allocator.alloc(u16, num_links);
                if (sanity) {
                    // initialize to a known invalid chunk code (0) to see if we overwrite
                    // this value later on
                    @memset(self.links[off], 0);
                }
                try self.sub_chunks.append(off);
            }
        }

        for (lengths, 0..) |n, li| {
            if (n == 0) {
                continue;
            }
            var ncode = next_code[n];
            next_code[n] += 1;
            var chunk = @as(u16, @intCast((li << huffman_value_shift) | n));
            var reverse = @as(u16, @intCast(bu.bitReverse(u16, @as(u16, @intCast(ncode)), 16)));
            reverse >>= @as(u4, @intCast(16 - n));
            if (n <= huffman_chunk_bits) {
                var off = reverse;
                while (off < self.chunks.len) : (off += @as(u16, 1) << @as(u4, @intCast(n))) {
                    // We should never need to overwrite
                    // an existing chunk. Also, 0 is
                    // never a valid chunk, because the
                    // lower 4 "count" bits should be
                    // between 1 and 15.
                    if (sanity) {
                        assert(self.chunks[off] == 0);
                    }
                    self.chunks[off] = chunk;
                }
            } else {
                var j = reverse & (huffman_num_chunks - 1);
                if (sanity) {
                    // Expect an indirect chunk
                    assert(self.chunks[j] & huffman_count_mask == huffman_chunk_bits + 1);
                    // Longer codes should have been
                    // associated with a link table above.
                }
                var value = self.chunks[j] >> huffman_value_shift;
                var link_tab = self.links[value];
                reverse >>= huffman_chunk_bits;
                var off = reverse;
                while (off < link_tab.len) : (off += @as(u16, 1) << @as(u4, @intCast(n - huffman_chunk_bits))) {
                    if (sanity) {
                        // check we are not overwriting an existing chunk
                        assert(link_tab[off] == 0);
                    }
                    link_tab[off] = @as(u16, @intCast(chunk));
                }
            }
        }

        if (sanity) {
            // Above we've sanity checked that we never overwrote
            // an existing entry. Here we additionally check that
            // we filled the tables completely.
            for (self.chunks, 0..) |chunk, i| {
                // As an exception, in the degenerate
                // single-code case, we allow odd
                // chunks to be missing.
                if (code == 1 and i % 2 == 1) {
                    continue;
                }

                // Assert we are not missing a chunk.
                // All chunks should have been written once
                // thus losing their initial value of 0
                assert(chunk != 0);
            }

            if (self.initialized) {
                for (self.links) |link_tab| {
                    for (link_tab) |chunk| {
                        // Assert we are not missing a chunk.
                        assert(chunk != 0);
                    }
                }
            }
        }

        return true;
    }

    /// Release all allocated memory.
    pub fn deinit(self: *Self) void {
        if (self.initialized and self.links.len > 0) {
            for (self.sub_chunks.items) |off| {
                self.allocator.free(self.links[off]);
            }
            self.allocator.free(self.links);
            self.sub_chunks.deinit();
            self.initialized = false;
        }
    }
};

var fixed_huffman_decoder: ?HuffmanDecoder = null;

fn fixedHuffmanDecoderInit(allocator: Allocator) !HuffmanDecoder {
    if (fixed_huffman_decoder != null) {
        return fixed_huffman_decoder.?;
    }

    // These come from the RFC section 3.2.6.
    var bits: [288]u32 = undefined;
    var i: u32 = 0;
    while (i < 144) : (i += 1) {
        bits[i] = 8;
    }
    while (i < 256) : (i += 1) {
        bits[i] = 9;
    }
    while (i < 280) : (i += 1) {
        bits[i] = 7;
    }
    while (i < 288) : (i += 1) {
        bits[i] = 8;
    }

    fixed_huffman_decoder = HuffmanDecoder{};
    _ = try fixed_huffman_decoder.?.init(allocator, &bits);
    return fixed_huffman_decoder.?;
}

const DecompressorState = enum {
    init,
    dict,
};

/// Returns a new Decompressor that can be used to read the uncompressed version of `reader`.
/// `dictionary` is optional and initializes the Decompressor with a preset dictionary.
/// The returned Decompressor behaves as if the uncompressed data stream started with the given
/// dictionary, which has already been read. Use the same `dictionary` as the compressor used to
/// compress the data.
/// This decompressor may use at most 300 KiB of heap memory from the provided allocator.
/// The uncompressed data will be written into the provided buffer, see `reader()` and `read()`.
pub fn decompressor(allocator: Allocator, reader: anytype, dictionary: ?[]const u8) !Decompressor(@TypeOf(reader)) {
    return Decompressor(@TypeOf(reader)).init(allocator, reader, dictionary);
}

pub fn Decompressor(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        pub const Error =
            ReaderType.Error ||
            error{EndOfStream} ||
            InflateError ||
            Allocator.Error;
        pub const Reader = io.Reader(*Self, Error, read);

        allocator: Allocator,

        // Input source.
        inner_reader: ReaderType,
        roffset: u64,

        // Input bits, in top of b.
        b: u32,
        nb: u32,

        // Huffman decoders for literal/length, distance.
        hd1: HuffmanDecoder,
        hd2: HuffmanDecoder,

        // Length arrays used to define Huffman codes.
        bits: *[max_num_lit + max_num_dist]u32,
        codebits: *[num_codes]u32,

        // Output history, buffer.
        dict: ddec.DictDecoder,

        // Temporary buffer (avoids repeated allocation).
        buf: [4]u8,

        // Next step in the decompression,
        // and decompression state.
        step: *const fn (*Self) Error!void,
        step_state: DecompressorState,
        final: bool,
        err: ?Error,
        to_read: []u8,
        // Huffman states for the lit/length values
        hl: ?*HuffmanDecoder,
        // Huffman states for the distance values.
        hd: ?*HuffmanDecoder,
        copy_len: u32,
        copy_dist: u32,

        /// Returns a Reader that reads compressed data from an underlying reader and outputs
        /// uncompressed data.
        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        fn init(allocator: Allocator, in_reader: ReaderType, dict: ?[]const u8) !Self {
            fixed_huffman_decoder = try fixedHuffmanDecoderInit(allocator);

            var bits = try allocator.create([max_num_lit + max_num_dist]u32);
            var codebits = try allocator.create([num_codes]u32);

            var dd = ddec.DictDecoder{};
            try dd.init(allocator, max_match_offset, dict);

            return Self{
                .allocator = allocator,

                // Input source.
                .inner_reader = in_reader,
                .roffset = 0,

                // Input bits, in top of b.
                .b = 0,
                .nb = 0,

                // Huffman decoders for literal/length, distance.
                .hd1 = HuffmanDecoder{},
                .hd2 = HuffmanDecoder{},

                // Length arrays used to define Huffman codes.
                .bits = bits,
                .codebits = codebits,

                // Output history, buffer.
                .dict = dd,

                // Temporary buffer (avoids repeated allocation).
                .buf = [_]u8{0} ** 4,

                // Next step in the decompression and decompression state.
                .step = nextBlock,
                .step_state = .init,
                .final = false,
                .err = null,
                .to_read = &[0]u8{},
                .hl = null,
                .hd = null,
                .copy_len = 0,
                .copy_dist = 0,
            };
        }

        /// Release all allocated memory.
        pub fn deinit(self: *Self) void {
            self.hd2.deinit();
            self.hd1.deinit();
            self.dict.deinit();
            self.allocator.destroy(self.codebits);
            self.allocator.destroy(self.bits);
        }

        fn nextBlock(self: *Self) Error!void {
            while (self.nb < 1 + 2) {
                self.moreBits() catch |e| {
                    self.err = e;
                    return e;
                };
            }
            self.final = self.b & 1 == 1;
            self.b >>= 1;
            var typ = self.b & 3;
            self.b >>= 2;
            self.nb -= 1 + 2;
            switch (typ) {
                0 => try self.dataBlock(),
                1 => {
                    // compressed, fixed Huffman tables
                    self.hl = &fixed_huffman_decoder.?;
                    self.hd = null;
                    try self.huffmanBlock();
                },
                2 => {
                    // compressed, dynamic Huffman tables
                    self.hd2.deinit();
                    self.hd1.deinit();
                    try self.readHuffman();
                    self.hl = &self.hd1;
                    self.hd = &self.hd2;
                    try self.huffmanBlock();
                },
                else => {
                    // 3 is reserved.
                    corrupt_input_error_offset = self.roffset;
                    self.err = InflateError.CorruptInput;
                    return InflateError.CorruptInput;
                },
            }
        }

        /// Reads compressed data from the underlying reader and outputs uncompressed data into
        /// `output`.
        pub fn read(self: *Self, output: []u8) Error!usize {
            while (true) {
                if (self.to_read.len > 0) {
                    const n = std.compress.deflate.copy(output, self.to_read);
                    self.to_read = self.to_read[n..];
                    if (self.to_read.len == 0 and
                        self.err != null)
                    {
                        if (self.err.? == InflateError.EndOfStreamWithNoError) {
                            return n;
                        }
                        return self.err.?;
                    }
                    return n;
                }
                if (self.err != null) {
                    if (self.err.? == InflateError.EndOfStreamWithNoError) {
                        return 0;
                    }
                    return self.err.?;
                }
                self.step(self) catch |e| {
                    self.err = e;
                    if (self.to_read.len == 0) {
                        self.to_read = self.dict.readFlush(); // Flush what's left in case of error
                    }
                };
            }
        }

        pub fn close(self: *Self) ?Error {
            if (self.err == @as(?Error, error.EndOfStreamWithNoError)) {
                return null;
            }
            return self.err;
        }

        // RFC 1951 section 3.2.7.
        // Compression with dynamic Huffman codes

        const code_order = [_]u32{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

        fn readHuffman(self: *Self) Error!void {
            // HLIT[5], HDIST[5], HCLEN[4].
            while (self.nb < 5 + 5 + 4) {
                try self.moreBits();
            }
            var nlit = @as(u32, @intCast(self.b & 0x1F)) + 257;
            if (nlit > max_num_lit) {
                corrupt_input_error_offset = self.roffset;
                self.err = InflateError.CorruptInput;
                return InflateError.CorruptInput;
            }
            self.b >>= 5;
            var ndist = @as(u32, @intCast(self.b & 0x1F)) + 1;
            if (ndist > max_num_dist) {
                corrupt_input_error_offset = self.roffset;
                self.err = InflateError.CorruptInput;
                return InflateError.CorruptInput;
            }
            self.b >>= 5;
            var nclen = @as(u32, @intCast(self.b & 0xF)) + 4;
            // num_codes is 19, so nclen is always valid.
            self.b >>= 4;
            self.nb -= 5 + 5 + 4;

            // (HCLEN+4)*3 bits: code lengths in the magic code_order order.
            var i: u32 = 0;
            while (i < nclen) : (i += 1) {
                while (self.nb < 3) {
                    try self.moreBits();
                }
                self.codebits[code_order[i]] = @as(u32, @intCast(self.b & 0x7));
                self.b >>= 3;
                self.nb -= 3;
            }
            i = nclen;
            while (i < code_order.len) : (i += 1) {
                self.codebits[code_order[i]] = 0;
            }
            if (!try self.hd1.init(self.allocator, self.codebits[0..])) {
                corrupt_input_error_offset = self.roffset;
                self.err = InflateError.CorruptInput;
                return InflateError.CorruptInput;
            }

            // HLIT + 257 code lengths, HDIST + 1 code lengths,
            // using the code length Huffman code.
            i = 0;
            var n = nlit + ndist;
            while (i < n) {
                var x = try self.huffSym(&self.hd1);
                if (x < 16) {
                    // Actual length.
                    self.bits[i] = x;
                    i += 1;
                    continue;
                }
                // Repeat previous length or zero.
                var rep: u32 = 0;
                var nb: u32 = 0;
                var b: u32 = 0;
                switch (x) {
                    16 => {
                        rep = 3;
                        nb = 2;
                        if (i == 0) {
                            corrupt_input_error_offset = self.roffset;
                            self.err = InflateError.CorruptInput;
                            return InflateError.CorruptInput;
                        }
                        b = self.bits[i - 1];
                    },
                    17 => {
                        rep = 3;
                        nb = 3;
                        b = 0;
                    },
                    18 => {
                        rep = 11;
                        nb = 7;
                        b = 0;
                    },
                    else => return error.BadInternalState, // unexpected length code
                }
                while (self.nb < nb) {
                    try self.moreBits();
                }
                rep += @as(u32, @intCast(self.b & (@as(u32, 1) << @as(u5, @intCast(nb))) - 1));
                self.b >>= @as(u5, @intCast(nb));
                self.nb -= nb;
                if (i + rep > n) {
                    corrupt_input_error_offset = self.roffset;
                    self.err = InflateError.CorruptInput;
                    return InflateError.CorruptInput;
                }
                var j: u32 = 0;
                while (j < rep) : (j += 1) {
                    self.bits[i] = b;
                    i += 1;
                }
            }

            if (!try self.hd1.init(self.allocator, self.bits[0..nlit]) or
                !try self.hd2.init(self.allocator, self.bits[nlit..][0..ndist]))
            {
                corrupt_input_error_offset = self.roffset;
                self.err = InflateError.CorruptInput;
                return InflateError.CorruptInput;
            }

            // As an optimization, we can initialize the min bits to read at a time
            // for the HLIT tree to the length of the EOB marker since we know that
            // every block must terminate with one. This preserves the property that
            // we never read any extra bytes after the end of the DEFLATE stream.
            if (self.hd1.min < self.bits[end_block_marker]) {
                self.hd1.min = self.bits[end_block_marker];
            }

            return;
        }

        // Decode a single Huffman block.
        // hl and hd are the Huffman states for the lit/length values
        // and the distance values, respectively. If hd == null, using the
        // fixed distance encoding associated with fixed Huffman blocks.
        fn huffmanBlock(self: *Self) Error!void {
            while (true) {
                switch (self.step_state) {
                    .init => {
                        // Read literal and/or (length, distance) according to RFC section 3.2.3.
                        var v = try self.huffSym(self.hl.?);
                        var n: u32 = 0; // number of bits extra
                        var length: u32 = 0;
                        switch (v) {
                            0...255 => {
                                self.dict.writeByte(@as(u8, @intCast(v)));
                                if (self.dict.availWrite() == 0) {
                                    self.to_read = self.dict.readFlush();
                                    self.step = huffmanBlock;
                                    self.step_state = .init;
                                    return;
                                }
                                self.step_state = .init;
                                continue;
                            },
                            256 => {
                                self.finishBlock();
                                return;
                            },
                            // otherwise, reference to older data
                            257...264 => {
                                length = v - (257 - 3);
                                n = 0;
                            },
                            265...268 => {
                                length = v * 2 - (265 * 2 - 11);
                                n = 1;
                            },
                            269...272 => {
                                length = v * 4 - (269 * 4 - 19);
                                n = 2;
                            },
                            273...276 => {
                                length = v * 8 - (273 * 8 - 35);
                                n = 3;
                            },
                            277...280 => {
                                length = v * 16 - (277 * 16 - 67);
                                n = 4;
                            },
                            281...284 => {
                                length = v * 32 - (281 * 32 - 131);
                                n = 5;
                            },
                            max_num_lit - 1 => { // 285
                                length = 258;
                                n = 0;
                            },
                            else => {
                                corrupt_input_error_offset = self.roffset;
                                self.err = InflateError.CorruptInput;
                                return InflateError.CorruptInput;
                            },
                        }
                        if (n > 0) {
                            while (self.nb < n) {
                                try self.moreBits();
                            }
                            length += @as(u32, @intCast(self.b)) & ((@as(u32, 1) << @as(u5, @intCast(n))) - 1);
                            self.b >>= @as(u5, @intCast(n));
                            self.nb -= n;
                        }

                        var dist: u32 = 0;
                        if (self.hd == null) {
                            while (self.nb < 5) {
                                try self.moreBits();
                            }
                            dist = @as(
                                u32,
                                @intCast(bu.bitReverse(u8, @as(u8, @intCast((self.b & 0x1F) << 3)), 8)),
                            );
                            self.b >>= 5;
                            self.nb -= 5;
                        } else {
                            dist = try self.huffSym(self.hd.?);
                        }

                        switch (dist) {
                            0...3 => dist += 1,
                            4...max_num_dist - 1 => { // 4...29
                                var nb = @as(u32, @intCast(dist - 2)) >> 1;
                                // have 1 bit in bottom of dist, need nb more.
                                var extra = (dist & 1) << @as(u5, @intCast(nb));
                                while (self.nb < nb) {
                                    try self.moreBits();
                                }
                                extra |= @as(u32, @intCast(self.b & (@as(u32, 1) << @as(u5, @intCast(nb))) - 1));
                                self.b >>= @as(u5, @intCast(nb));
                                self.nb -= nb;
                                dist = (@as(u32, 1) << @as(u5, @intCast(nb + 1))) + 1 + extra;
                            },
                            else => {
                                corrupt_input_error_offset = self.roffset;
                                self.err = InflateError.CorruptInput;
                                return InflateError.CorruptInput;
                            },
                        }

                        // No check on length; encoding can be prescient.
                        if (dist > self.dict.histSize()) {
                            corrupt_input_error_offset = self.roffset;
                            self.err = InflateError.CorruptInput;
                            return InflateError.CorruptInput;
                        }

                        self.copy_len = length;
                        self.copy_dist = dist;
                        self.step_state = .dict;
                    },

                    .dict => {
                        // Perform a backwards copy according to RFC section 3.2.3.
                        var cnt = self.dict.tryWriteCopy(self.copy_dist, self.copy_len);
                        if (cnt == 0) {
                            cnt = self.dict.writeCopy(self.copy_dist, self.copy_len);
                        }
                        self.copy_len -= cnt;

                        if (self.dict.availWrite() == 0 or self.copy_len > 0) {
                            self.to_read = self.dict.readFlush();
                            self.step = huffmanBlock; // We need to continue this work
                            self.step_state = .dict;
                            return;
                        }
                        self.step_state = .init;
                    },
                }
            }
        }

        // Copy a single uncompressed data block from input to output.
        fn dataBlock(self: *Self) Error!void {
            // Uncompressed.
            // Discard current half-byte.
            self.nb = 0;
            self.b = 0;

            // Length then ones-complement of length.
            var nr: u32 = 4;
            self.inner_reader.readNoEof(self.buf[0..nr]) catch {
                self.err = InflateError.UnexpectedEndOfStream;
                return InflateError.UnexpectedEndOfStream;
            };
            self.roffset += @as(u64, @intCast(nr));
            var n = @as(u32, @intCast(self.buf[0])) | @as(u32, @intCast(self.buf[1])) << 8;
            var nn = @as(u32, @intCast(self.buf[2])) | @as(u32, @intCast(self.buf[3])) << 8;
            if (@as(u16, @intCast(nn)) != @as(u16, @truncate(~n))) {
                corrupt_input_error_offset = self.roffset;
                self.err = InflateError.CorruptInput;
                return InflateError.CorruptInput;
            }

            if (n == 0) {
                self.to_read = self.dict.readFlush();
                self.finishBlock();
                return;
            }

            self.copy_len = n;
            try self.copyData();
        }

        // copyData copies self.copy_len bytes from the underlying reader into self.hist.
        // It pauses for reads when self.hist is full.
        fn copyData(self: *Self) Error!void {
            var buf = self.dict.writeSlice();
            if (buf.len > self.copy_len) {
                buf = buf[0..self.copy_len];
            }

            var cnt = try self.inner_reader.read(buf);
            if (cnt < buf.len) {
                self.err = InflateError.UnexpectedEndOfStream;
            }
            self.roffset += @as(u64, @intCast(cnt));
            self.copy_len -= @as(u32, @intCast(cnt));
            self.dict.writeMark(@as(u32, @intCast(cnt)));
            if (self.err != null) {
                return InflateError.UnexpectedEndOfStream;
            }

            if (self.dict.availWrite() == 0 or self.copy_len > 0) {
                self.to_read = self.dict.readFlush();
                self.step = copyData;
                return;
            }
            self.finishBlock();
        }

        fn finishBlock(self: *Self) void {
            if (self.final) {
                if (self.dict.availRead() > 0) {
                    self.to_read = self.dict.readFlush();
                }
                self.err = InflateError.EndOfStreamWithNoError;
            }
            self.step = nextBlock;
        }

        fn moreBits(self: *Self) InflateError!void {
            var c = self.inner_reader.readByte() catch |e| {
                if (e == error.EndOfStream) {
                    return InflateError.UnexpectedEndOfStream;
                }
                return InflateError.BadReaderState;
            };
            self.roffset += 1;
            self.b |= @as(u32, c) << @as(u5, @intCast(self.nb));
            self.nb += 8;
            return;
        }

        // Read the next Huffman-encoded symbol according to h.
        fn huffSym(self: *Self, h: *HuffmanDecoder) InflateError!u32 {
            // Since a HuffmanDecoder can be empty or be composed of a degenerate tree
            // with single element, huffSym must error on these two edge cases. In both
            // cases, the chunks slice will be 0 for the invalid sequence, leading it
            // satisfy the n == 0 check below.
            var n: u32 = h.min;
            // Optimization. Go compiler isn't smart enough to keep self.b, self.nb in registers,
            // but is smart enough to keep local variables in registers, so use nb and b,
            // inline call to moreBits and reassign b, nb back to self on return.
            var nb = self.nb;
            var b = self.b;
            while (true) {
                while (nb < n) {
                    var c = self.inner_reader.readByte() catch |e| {
                        self.b = b;
                        self.nb = nb;
                        if (e == error.EndOfStream) {
                            return error.UnexpectedEndOfStream;
                        }
                        return InflateError.BadReaderState;
                    };
                    self.roffset += 1;
                    b |= @as(u32, @intCast(c)) << @as(u5, @intCast(nb & 31));
                    nb += 8;
                }
                var chunk = h.chunks[b & (huffman_num_chunks - 1)];
                n = @as(u32, @intCast(chunk & huffman_count_mask));
                if (n > huffman_chunk_bits) {
                    chunk = h.links[chunk >> huffman_value_shift][(b >> huffman_chunk_bits) & h.link_mask];
                    n = @as(u32, @intCast(chunk & huffman_count_mask));
                }
                if (n <= nb) {
                    if (n == 0) {
                        self.b = b;
                        self.nb = nb;
                        corrupt_input_error_offset = self.roffset;
                        self.err = InflateError.CorruptInput;
                        return InflateError.CorruptInput;
                    }
                    self.b = b >> @as(u5, @intCast(n & 31));
                    self.nb = nb - n;
                    return @as(u32, @intCast(chunk >> huffman_value_shift));
                }
            }
        }

        /// Replaces the inner reader and dictionary with new_reader and new_dict.
        /// new_reader must be of the same type as the reader being replaced.
        pub fn reset(s: *Self, new_reader: ReaderType, new_dict: ?[]const u8) !void {
            s.inner_reader = new_reader;
            s.step = nextBlock;
            s.err = null;

            s.dict.deinit();
            try s.dict.init(s.allocator, max_match_offset, new_dict);

            return;
        }
    };
}

// tests
const expectError = std.testing.expectError;
const io = std.io;
const testing = std.testing;

test "truncated input" {
    const TruncatedTest = struct {
        input: []const u8,
        output: []const u8,
    };

    const tests = [_]TruncatedTest{
        .{ .input = "\x00", .output = "" },
        .{ .input = "\x00\x0c", .output = "" },
        .{ .input = "\x00\x0c\x00", .output = "" },
        .{ .input = "\x00\x0c\x00\xf3\xff", .output = "" },
        .{ .input = "\x00\x0c\x00\xf3\xffhello", .output = "hello" },
        .{ .input = "\x00\x0c\x00\xf3\xffhello, world", .output = "hello, world" },
        .{ .input = "\x02", .output = "" },
        .{ .input = "\xf2H\xcd", .output = "He" },
        .{ .input = "\xf2H͙0a\u{0084}\t", .output = "Hel\x90\x90\x90\x90\x90" },
        .{ .input = "\xf2H͙0a\u{0084}\t\x00", .output = "Hel\x90\x90\x90\x90\x90" },
    };

    for (tests) |t| {
        var fib = io.fixedBufferStream(t.input);
        const r = fib.reader();
        var z = try decompressor(testing.allocator, r, null);
        defer z.deinit();
        var zr = z.reader();

        var output = [1]u8{0} ** 12;
        try expectError(error.UnexpectedEndOfStream, zr.readAll(&output));
        try testing.expectEqualSlices(u8, t.output, output[0..t.output.len]);
    }
}

test "Go non-regression test for 9842" {
    // See https://golang.org/issue/9842

    const Test = struct {
        err: ?anyerror,
        input: []const u8,
    };

    const tests = [_]Test{
        .{ .err = error.UnexpectedEndOfStream, .input = ("\x95\x90=o\xc20\x10\x86\xf30") },
        .{ .err = error.CorruptInput, .input = ("\x950\x00\x0000000") },

        // Huffman.construct errors

        // lencode
        .{ .err = error.CorruptInput, .input = ("\x950000") },
        .{ .err = error.CorruptInput, .input = ("\x05000") },
        // hlen
        .{ .err = error.CorruptInput, .input = ("\x05\xea\x01\t\x00\x00\x00\x01\x00\\\xbf.\t\x00") },
        // hdist
        .{ .err = error.CorruptInput, .input = ("\x05\xe0\x01A\x00\x00\x00\x00\x10\\\xbf.") },

        // like the "empty distance alphabet" test but for ndist instead of nlen
        .{ .err = error.CorruptInput, .input = ("\x05\xe0\x01\t\x00\x00\x00\x00\x10\\\xbf\xce") },
        .{ .err = null, .input = "\x15\xe0\x01\t\x00\x00\x00\x00\x10\\\xbf.0" },
    };

    for (tests) |t| {
        var fib = std.io.fixedBufferStream(t.input);
        const reader = fib.reader();
        var decomp = try decompressor(testing.allocator, reader, null);
        defer decomp.deinit();

        var output: [10]u8 = undefined;
        if (t.err != null) {
            try expectError(t.err.?, decomp.reader().read(&output));
        } else {
            _ = try decomp.reader().read(&output);
        }
    }
}

test "inflate A Tale of Two Cities (1859) intro" {
    const compressed = [_]u8{
        0x74, 0xeb, 0xcd, 0x0d, 0x80, 0x20, 0x0c, 0x47, 0x71, 0xdc, 0x9d, 0xa2, 0x03, 0xb8, 0x88,
        0x63, 0xf0, 0xf1, 0x47, 0x9a, 0x00, 0x35, 0xb4, 0x86, 0xf5, 0x0d, 0x27, 0x63, 0x82, 0xe7,
        0xdf, 0x7b, 0x87, 0xd1, 0x70, 0x4a, 0x96, 0x41, 0x1e, 0x6a, 0x24, 0x89, 0x8c, 0x2b, 0x74,
        0xdf, 0xf8, 0x95, 0x21, 0xfd, 0x8f, 0xdc, 0x89, 0x09, 0x83, 0x35, 0x4a, 0x5d, 0x49, 0x12,
        0x29, 0xac, 0xb9, 0x41, 0xbf, 0x23, 0x2e, 0x09, 0x79, 0x06, 0x1e, 0x85, 0x91, 0xd6, 0xc6,
        0x2d, 0x74, 0xc4, 0xfb, 0xa1, 0x7b, 0x0f, 0x52, 0x20, 0x84, 0x61, 0x28, 0x0c, 0x63, 0xdf,
        0x53, 0xf4, 0x00, 0x1e, 0xc3, 0xa5, 0x97, 0x88, 0xf4, 0xd9, 0x04, 0xa5, 0x2d, 0x49, 0x54,
        0xbc, 0xfd, 0x90, 0xa5, 0x0c, 0xae, 0xbf, 0x3f, 0x84, 0x77, 0x88, 0x3f, 0xaf, 0xc0, 0x40,
        0xd6, 0x5b, 0x14, 0x8b, 0x54, 0xf6, 0x0f, 0x9b, 0x49, 0xf7, 0xbf, 0xbf, 0x36, 0x54, 0x5a,
        0x0d, 0xe6, 0x3e, 0xf0, 0x9e, 0x29, 0xcd, 0xa1, 0x41, 0x05, 0x36, 0x48, 0x74, 0x4a, 0xe9,
        0x46, 0x66, 0x2a, 0x19, 0x17, 0xf4, 0x71, 0x8e, 0xcb, 0x15, 0x5b, 0x57, 0xe4, 0xf3, 0xc7,
        0xe7, 0x1e, 0x9d, 0x50, 0x08, 0xc3, 0x50, 0x18, 0xc6, 0x2a, 0x19, 0xa0, 0xdd, 0xc3, 0x35,
        0x82, 0x3d, 0x6a, 0xb0, 0x34, 0x92, 0x16, 0x8b, 0xdb, 0x1b, 0xeb, 0x7d, 0xbc, 0xf8, 0x16,
        0xf8, 0xc2, 0xe1, 0xaf, 0x81, 0x7e, 0x58, 0xf4, 0x9f, 0x74, 0xf8, 0xcd, 0x39, 0xd3, 0xaa,
        0x0f, 0x26, 0x31, 0xcc, 0x8d, 0x9a, 0xd2, 0x04, 0x3e, 0x51, 0xbe, 0x7e, 0xbc, 0xc5, 0x27,
        0x3d, 0xa5, 0xf3, 0x15, 0x63, 0x94, 0x42, 0x75, 0x53, 0x6b, 0x61, 0xc8, 0x01, 0x13, 0x4d,
        0x23, 0xba, 0x2a, 0x2d, 0x6c, 0x94, 0x65, 0xc7, 0x4b, 0x86, 0x9b, 0x25, 0x3e, 0xba, 0x01,
        0x10, 0x84, 0x81, 0x28, 0x80, 0x55, 0x1c, 0xc0, 0xa5, 0xaa, 0x36, 0xa6, 0x09, 0xa8, 0xa1,
        0x85, 0xf9, 0x7d, 0x45, 0xbf, 0x80, 0xe4, 0xd1, 0xbb, 0xde, 0xb9, 0x5e, 0xf1, 0x23, 0x89,
        0x4b, 0x00, 0xd5, 0x59, 0x84, 0x85, 0xe3, 0xd4, 0xdc, 0xb2, 0x66, 0xe9, 0xc1, 0x44, 0x0b,
        0x1e, 0x84, 0xec, 0xe6, 0xa1, 0xc7, 0x42, 0x6a, 0x09, 0x6d, 0x9a, 0x5e, 0x70, 0xa2, 0x36,
        0x94, 0x29, 0x2c, 0x85, 0x3f, 0x24, 0x39, 0xf3, 0xae, 0xc3, 0xca, 0xca, 0xaf, 0x2f, 0xce,
        0x8e, 0x58, 0x91, 0x00, 0x25, 0xb5, 0xb3, 0xe9, 0xd4, 0xda, 0xef, 0xfa, 0x48, 0x7b, 0x3b,
        0xe2, 0x63, 0x12, 0x00, 0x00, 0x20, 0x04, 0x80, 0x70, 0x36, 0x8c, 0xbd, 0x04, 0x71, 0xff,
        0xf6, 0x0f, 0x66, 0x38, 0xcf, 0xa1, 0x39, 0x11, 0x0f,
    };

    const expected =
        \\It was the best of times,
        \\it was the worst of times,
        \\it was the age of wisdom,
        \\it was the age of foolishness,
        \\it was the epoch of belief,
        \\it was the epoch of incredulity,
        \\it was the season of Light,
        \\it was the season of Darkness,
        \\it was the spring of hope,
        \\it was the winter of despair,
        \\
        \\we had everything before us, we had nothing before us, we were all going direct to Heaven, we were all going direct the other way---in short, the period was so far like the present period, that some of its noisiest authorities insisted on its being received, for good or for evil, in the superlative degree of comparison only.
        \\
    ;

    var fib = std.io.fixedBufferStream(&compressed);
    const reader = fib.reader();
    var decomp = try decompressor(testing.allocator, reader, null);
    defer decomp.deinit();

    var got: [700]u8 = undefined;
    var got_len = try decomp.reader().read(&got);
    try testing.expectEqual(@as(usize, 616), got_len);
    try testing.expectEqualSlices(u8, expected, got[0..expected.len]);
}

test "lengths overflow" {
    // malformed final dynamic block, tries to write 321 code lengths (MAXCODES is 316)
    // f dy  hlit hdist hclen 16  17  18   0 (18)    x138 (18)    x138 (18)     x39 (16) x6
    // 1 10 11101 11101 0000 010 010 010 010 (11) 1111111 (11) 1111111 (11) 0011100 (01) 11
    const stream = [_]u8{
        0b11101101, 0b00011101, 0b00100100, 0b11101001, 0b11111111, 0b11111111, 0b00111001,
        0b00001110,
    };
    try expectError(error.CorruptInput, decompress(stream[0..]));
}

test "empty distance alphabet" {
    // dynamic block with empty distance alphabet is valid if only literals and end of data symbol are used
    // f dy  hlit hdist hclen 16  17  18   0   8   7   9   6  10   5  11   4  12   3  13   2  14   1  15 (18)    x128 (18)    x128 (1)  ( 0) (256)
    // 1 10 00000 00000 1111 000 000 010 010 000 000 000 000 000 000 000 000 000 000 000 000 000 001 000 (11) 1110101 (11) 1110101 (0)  (10)  (0)
    const stream = [_]u8{
        0b00000101, 0b11100000, 0b00000001, 0b00001001, 0b00000000, 0b00000000,
        0b00000000, 0b00000000, 0b00010000, 0b01011100, 0b10111111, 0b00101110,
    };
    try decompress(stream[0..]);
}

test "distance past beginning of output stream" {
    // f fx ('A')      ('B')      ('C')      <len=4,   dist=4> (end)
    // 1 01 (01110001) (01110010) (01110011) (0000010) (00011) (0000000)
    const stream = [_]u8{ 0b01110011, 0b01110100, 0b01110010, 0b00000110, 0b01100001, 0b00000000 };
    try std.testing.expectError(error.CorruptInput, decompress(stream[0..]));
}

test "fuzzing" {
    const compressed = [_]u8{
        0x0a, 0x08, 0x50, 0xeb, 0x25, 0x05, 0xfc, 0x30, 0x0b, 0x0a, 0x08, 0x50, 0xeb, 0x25, 0x05,
    } ++ [_]u8{0xe1} ** 15 ++ [_]u8{0x30} ++ [_]u8{0xe1} ** 1481;
    try expectError(error.UnexpectedEndOfStream, decompress(&compressed));

    // see https://github.com/ziglang/zig/issues/9842
    try expectError(error.UnexpectedEndOfStream, decompress("\x95\x90=o\xc20\x10\x86\xf30"));
    try expectError(error.CorruptInput, decompress("\x950\x00\x0000000"));

    // Huffman errors
    // lencode
    try expectError(error.CorruptInput, decompress("\x950000"));
    try expectError(error.CorruptInput, decompress("\x05000"));
    // hlen
    try expectError(error.CorruptInput, decompress("\x05\xea\x01\t\x00\x00\x00\x01\x00\\\xbf.\t\x00"));
    // hdist
    try expectError(error.CorruptInput, decompress("\x05\xe0\x01A\x00\x00\x00\x00\x10\\\xbf."));

    // like the "empty distance alphabet" test but for ndist instead of nlen
    try expectError(error.CorruptInput, decompress("\x05\xe0\x01\t\x00\x00\x00\x00\x10\\\xbf\xce"));
    try decompress("\x15\xe0\x01\t\x00\x00\x00\x00\x10\\\xbf.0");
}

fn decompress(input: []const u8) !void {
    const allocator = testing.allocator;
    var fib = std.io.fixedBufferStream(input);
    const reader = fib.reader();
    var decomp = try decompressor(allocator, reader, null);
    defer decomp.deinit();
    var output = try decomp.reader().readAllAlloc(allocator, math.maxInt(usize));
    defer std.testing.allocator.free(output);
}
