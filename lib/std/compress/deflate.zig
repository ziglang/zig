//
// Decompressor for DEFLATE data streams (RFC1951)
//
// Heavily inspired by the simple decompressor puff.c by Mark Adler

const std = @import("std");
const io = std.io;
const math = std.math;
const mem = std.mem;

const assert = std.debug.assert;

const MAXBITS = 15;
const MAXLCODES = 286;
const MAXDCODES = 30;
const MAXCODES = MAXLCODES + MAXDCODES;
const FIXLCODES = 288;

// The maximum length of a Huffman code's prefix we can decode using the fast
// path. The factor 9 is inherited from Zlib, tweaking the value showed little
// or no changes in the profiler output.
const PREFIX_LUT_BITS = 9;

const Huffman = struct {
    const LUTEntry = packed struct { symbol: u16 align(4), len: u16 };

    // Number of codes for each possible length
    count: [MAXBITS + 1]u16,
    // Mapping between codes and symbols
    symbol: [MAXCODES]u16,

    // The decoding process uses a trick explained by Mark Adler in [1].
    // We basically precompute for a fixed number of codes (0 <= x <= 2^N-1)
    // the symbol and the effective code length we'd get if the decoder was run
    // on the given N-bit sequence.
    // A code with length 0 means the sequence is not a valid prefix for this
    // canonical Huffman code and we have to decode it using a slower method.
    //
    // [1] https://github.com/madler/zlib/blob/v1.2.11/doc/algorithm.txt#L58
    prefix_lut: [1 << PREFIX_LUT_BITS]LUTEntry,
    // The following info refer to the codes of length PREFIX_LUT_BITS+1 and are
    // used to bootstrap the bit-by-bit reading method if the fast-path fails.
    last_code: u16,
    last_index: u16,

    min_code_len: u16,

    fn construct(self: *Huffman, code_length: []const u16) !void {
        for (self.count) |*val| {
            val.* = 0;
        }

        self.min_code_len = math.maxInt(u16);
        for (code_length) |len| {
            if (len != 0 and len < self.min_code_len)
                self.min_code_len = len;
            self.count[len] += 1;
        }

        // All zero.
        if (self.count[0] == code_length.len)
            return;

        var left: isize = 1;
        for (self.count[1..]) |val| {
            // Each added bit doubles the amount of codes.
            left *= 2;
            // Make sure the number of codes with this length isn't too high.
            left -= @as(isize, @bitCast(i16, val));
            if (left < 0)
                return error.InvalidTree;
        }

        // Compute the offset of the first symbol represented by a code of a
        // given length in the symbol table, together with the first canonical
        // Huffman code for that length.
        var offset: [MAXBITS + 1]u16 = undefined;
        var codes: [MAXBITS + 1]u16 = undefined;
        {
            offset[1] = 0;
            codes[1] = 0;
            var len: usize = 1;
            while (len < MAXBITS) : (len += 1) {
                offset[len + 1] = offset[len] + self.count[len];
                codes[len + 1] = (codes[len] + self.count[len]) << 1;
            }
        }

        self.prefix_lut = mem.zeroes(@TypeOf(self.prefix_lut));

        for (code_length) |len, symbol| {
            if (len != 0) {
                // Fill the symbol table.
                // The symbols are assigned sequentially for each length.
                self.symbol[offset[len]] = @truncate(u16, symbol);
                // Track the last assigned offset.
                offset[len] += 1;
            }

            if (len == 0 or len > PREFIX_LUT_BITS)
                continue;

            // Given a Huffman code of length N we transform it into an index
            // into the lookup table by reversing its bits and filling the
            // remaining bits (PREFIX_LUT_BITS - N) with every possible
            // combination of bits to act as a wildcard.
            const bits_to_fill = @intCast(u5, PREFIX_LUT_BITS - len);
            const rev_code = bitReverse(u16, codes[len], len);

            // Track the last used code, but only for lengths < PREFIX_LUT_BITS.
            codes[len] += 1;

            var j: usize = 0;
            while (j < @as(usize, 1) << bits_to_fill) : (j += 1) {
                const index = rev_code | (j << @intCast(u5, len));
                assert(self.prefix_lut[index].len == 0);
                self.prefix_lut[index] = .{
                    .symbol = @truncate(u16, symbol),
                    .len = @truncate(u16, len),
                };
            }
        }

        self.last_code = codes[PREFIX_LUT_BITS + 1];
        self.last_index = offset[PREFIX_LUT_BITS + 1] - self.count[PREFIX_LUT_BITS + 1];
    }
};

// Reverse bit-by-bit a N-bit code.
fn bitReverse(comptime T: type, value: T, N: usize) T {
    const r = @bitReverse(T, value);
    return r >> @intCast(math.Log2Int(T), @typeInfo(T).Int.bits - N);
}

pub fn InflateStream(comptime ReaderType: type) type {
    return struct {
        const Self = @This();

        pub const Error = ReaderType.Error || error{
            EndOfStream,
            BadCounts,
            InvalidBlockType,
            InvalidDistance,
            InvalidFixedCode,
            InvalidLength,
            InvalidStoredSize,
            InvalidSymbol,
            InvalidTree,
            MissingEOBCode,
            NoLastLength,
            OutOfCodes,
        };
        pub const Reader = io.Reader(*Self, Error, read);

        inner_reader: ReaderType,

        // True if the decoder met the end of the compressed stream, no further
        // data can be decompressed
        seen_eos: bool,

        state: union(enum) {
            // Parse a compressed block header and set up the internal state for
            // decompressing its contents.
            DecodeBlockHeader: void,
            // Decode all the symbols in a compressed block.
            DecodeBlockData: void,
            // Copy N bytes of uncompressed data from the underlying stream into
            // the window.
            Copy: usize,
            // Copy 1 byte into the window.
            CopyLit: u8,
            // Copy L bytes from the window itself, starting from D bytes
            // behind.
            CopyFrom: struct { distance: u16, length: u16 },
        },

        // Sliding window for the LZ77 algorithm
        window: struct {
            const WSelf = @This();

            // invariant: buffer length is always a power of 2
            buf: []u8,
            // invariant: ri <= wi
            wi: usize = 0, // Write index
            ri: usize = 0, // Read index
            el: usize = 0, // Number of readable elements

            fn readable(self: *WSelf) usize {
                return self.el;
            }

            fn writable(self: *WSelf) usize {
                return self.buf.len - self.el;
            }

            // Insert a single byte into the window.
            // Returns 1 if there's enough space for the new byte and 0
            // otherwise.
            fn append(self: *WSelf, value: u8) usize {
                if (self.writable() < 1) return 0;
                self.appendUnsafe(value);
                return 1;
            }

            // Insert a single byte into the window.
            // Assumes there's enough space.
            inline fn appendUnsafe(self: *WSelf, value: u8) void {
                self.buf[self.wi] = value;
                self.wi = (self.wi + 1) & (self.buf.len - 1);
                self.el += 1;
            }

            // Fill dest[] with data from the window, starting from the read
            // position. This updates the read pointer.
            // Returns the number of read bytes or 0 if there's nothing to read
            // yet.
            fn read(self: *WSelf, dest: []u8) usize {
                const N = math.min(dest.len, self.readable());

                if (N == 0) return 0;

                if (self.ri + N < self.buf.len) {
                    // The data doesn't wrap around
                    mem.copy(u8, dest, self.buf[self.ri .. self.ri + N]);
                } else {
                    // The data wraps around the buffer, split the copy
                    std.mem.copy(u8, dest, self.buf[self.ri..]);
                    // How much data we've copied from `ri` to the end
                    const r = self.buf.len - self.ri;
                    std.mem.copy(u8, dest[r..], self.buf[0 .. N - r]);
                }

                self.ri = (self.ri + N) & (self.buf.len - 1);
                self.el -= N;

                return N;
            }

            // Copy `length` bytes starting from `distance` bytes behind the
            // write pointer.
            // Be careful as the length may be greater than the distance, that's
            // how the compressor encodes run-length encoded sequences.
            fn copyFrom(self: *WSelf, distance: usize, length: usize) usize {
                const N = math.min(length, self.writable());

                if (N == 0) return 0;

                // TODO: Profile and, if needed, replace with smarter juggling
                // of the window memory for the non-overlapping case.
                var i: usize = 0;
                while (i < N) : (i += 1) {
                    const index = (self.wi -% distance) & (self.buf.len - 1);
                    self.appendUnsafe(self.buf[index]);
                }

                return N;
            }
        },

        // Compressor-local Huffman tables used to decompress blocks with
        // dynamic codes.
        huffman_tables: [2]Huffman = undefined,

        // Huffman tables used for decoding length/distance pairs.
        hdist: *Huffman,
        hlen: *Huffman,

        // Temporary buffer for the bitstream.
        // Bits 0..`bits_left` are filled with data, the remaining ones are zeros.
        bits: u32,
        bits_left: usize,

        fn peekBits(self: *Self, bits: usize) !u32 {
            while (self.bits_left < bits) {
                const byte = try self.inner_reader.readByte();
                self.bits |= @as(u32, byte) << @intCast(u5, self.bits_left);
                self.bits_left += 8;
            }
            const mask = (@as(u32, 1) << @intCast(u5, bits)) - 1;
            return self.bits & mask;
        }
        fn readBits(self: *Self, bits: usize) !u32 {
            const val = self.peekBits(bits);
            self.discardBits(bits);
            return val;
        }
        fn discardBits(self: *Self, bits: usize) void {
            self.bits >>= @intCast(u5, bits);
            self.bits_left -= bits;
        }

        fn stored(self: *Self) !void {
            // Discard the remaining bits, the length field is always
            // byte-aligned (and so is the data).
            self.discardBits(self.bits_left);

            const length = try self.inner_reader.readIntLittle(u16);
            const length_cpl = try self.inner_reader.readIntLittle(u16);

            if (length != ~length_cpl)
                return error.InvalidStoredSize;

            self.state = .{ .Copy = length };
        }

        fn fixed(self: *Self) !void {
            comptime var lencode: Huffman = undefined;
            comptime var distcode: Huffman = undefined;

            // The Huffman codes are specified in the RFC1951, section 3.2.6
            comptime {
                @setEvalBranchQuota(100000);

                const len_lengths =
                    [_]u16{8} ** 144 ++
                    [_]u16{9} ** 112 ++
                    [_]u16{7} ** 24 ++
                    [_]u16{8} ** 8;
                assert(len_lengths.len == FIXLCODES);
                try lencode.construct(len_lengths[0..]);

                const dist_lengths = [_]u16{5} ** MAXDCODES;
                try distcode.construct(dist_lengths[0..]);
            }

            self.hlen = &lencode;
            self.hdist = &distcode;
            self.state = .DecodeBlockData;
        }

        fn dynamic(self: *Self) !void {
            // Number of length codes
            const nlen = (try self.readBits(5)) + 257;
            // Number of distance codes
            const ndist = (try self.readBits(5)) + 1;
            // Number of code length codes
            const ncode = (try self.readBits(4)) + 4;

            if (nlen > MAXLCODES or ndist > MAXDCODES)
                return error.BadCounts;

            // Permutation of code length codes
            const ORDER = [19]u16{
                16, 17, 18, 0, 8,  7, 9,  6, 10, 5, 11, 4,
                12, 3,  13, 2, 14, 1, 15,
            };

            // Build the Huffman table to decode the code length codes
            var lencode: Huffman = undefined;
            {
                var lengths = std.mem.zeroes([19]u16);

                // Read the code lengths, missing ones are left as zero
                for (ORDER[0..ncode]) |val| {
                    lengths[val] = @intCast(u16, try self.readBits(3));
                }

                try lencode.construct(lengths[0..]);
            }

            // Read the length/literal and distance code length tables.
            // Zero the table by default so we can avoid explicitly writing out
            // zeros for codes 17 and 18
            var lengths = std.mem.zeroes([MAXCODES]u16);

            var i: usize = 0;
            while (i < nlen + ndist) {
                const symbol = try self.decode(&lencode);

                switch (symbol) {
                    0...15 => {
                        lengths[i] = symbol;
                        i += 1;
                    },
                    16 => {
                        // repeat last length 3..6 times
                        if (i == 0) return error.NoLastLength;

                        const last_length = lengths[i - 1];
                        const repeat = 3 + (try self.readBits(2));
                        const last_index = i + repeat;
                        if (last_index > lengths.len)
                            return error.InvalidLength;
                        while (i < last_index) : (i += 1) {
                            lengths[i] = last_length;
                        }
                    },
                    17 => {
                        // repeat zero 3..10 times
                        i += 3 + (try self.readBits(3));
                    },
                    18 => {
                        // repeat zero 11..138 times
                        i += 11 + (try self.readBits(7));
                    },
                    else => return error.InvalidSymbol,
                }
            }

            if (i > nlen + ndist)
                return error.InvalidLength;

            // Check if the end of block code is present
            if (lengths[256] == 0)
                return error.MissingEOBCode;

            try self.huffman_tables[0].construct(lengths[0..nlen]);
            try self.huffman_tables[1].construct(lengths[nlen .. nlen + ndist]);

            self.hlen = &self.huffman_tables[0];
            self.hdist = &self.huffman_tables[1];
            self.state = .DecodeBlockData;
        }

        fn codes(self: *Self, lencode: *Huffman, distcode: *Huffman) !bool {
            // Size base for length codes 257..285
            const LENS = [29]u16{
                3,  4,  5,  6,  7,  8,  9,  10,  11,  13,  15,  17,  19,  23, 27, 31,
                35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258,
            };
            // Extra bits for length codes 257..285
            const LEXT = [29]u16{
                0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
                3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0,
            };
            // Offset base for distance codes 0..29
            const DISTS = [30]u16{
                1,   2,   3,   4,   5,    7,    9,    13,   17,   25,   33,   49,    65,    97,    129, 193,
                257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577,
            };
            // Extra bits for distance codes 0..29
            const DEXT = [30]u16{
                0, 0, 0, 0, 1, 1, 2,  2,  3,  3,  4,  4,  5,  5,  6, 6,
                7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
            };

            while (true) {
                const symbol = try self.decode(lencode);

                switch (symbol) {
                    0...255 => {
                        // Literal value
                        const c = @truncate(u8, symbol);
                        if (self.window.append(c) == 0) {
                            self.state = .{ .CopyLit = c };
                            return false;
                        }
                    },
                    256 => {
                        // End of block symbol
                        return true;
                    },
                    257...285 => {
                        // Length/distance pair
                        const length_symbol = symbol - 257;
                        const length = LENS[length_symbol] +
                            @intCast(u16, try self.readBits(LEXT[length_symbol]));

                        const distance_symbol = try self.decode(distcode);
                        const distance = DISTS[distance_symbol] +
                            @intCast(u16, try self.readBits(DEXT[distance_symbol]));

                        if (distance > self.window.buf.len)
                            return error.InvalidDistance;

                        const written = self.window.copyFrom(distance, length);
                        if (written != length) {
                            self.state = .{
                                .CopyFrom = .{
                                    .distance = distance,
                                    .length = length - @truncate(u16, written),
                                },
                            };
                            return false;
                        }
                    },
                    else => return error.InvalidFixedCode,
                }
            }
        }

        fn decode(self: *Self, h: *Huffman) !u16 {
            // Using u32 instead of u16 to reduce the number of casts needed.
            var prefix: u32 = 0;

            // Fast path, read some bits and hope they're the prefix of some code.
            // We can't read PREFIX_LUT_BITS as we don't want to read past the
            // deflate stream end, use an incremental approach instead.
            var code_len = h.min_code_len;
            while (true) {
                _ = try self.peekBits(code_len);
                // Small optimization win, use as many bits as possible in the
                // table lookup.
                prefix = self.bits & ((1 << PREFIX_LUT_BITS) - 1);

                const lut_entry = &h.prefix_lut[prefix];
                // The code is longer than PREFIX_LUT_BITS!
                if (lut_entry.len == 0)
                    break;
                // If the code lenght doesn't increase we found a match.
                if (lut_entry.len <= code_len) {
                    self.discardBits(code_len);
                    return lut_entry.symbol;
                }

                code_len = lut_entry.len;
            }

            // The sequence we've read is not a prefix of any code of length <=
            // PREFIX_LUT_BITS, keep decoding it using a slower method.
            prefix = try self.readBits(PREFIX_LUT_BITS);

            // Speed up the decoding by starting from the first code length
            // that's not covered by the table.
            var len: usize = PREFIX_LUT_BITS + 1;
            var first: usize = h.last_code;
            var index: usize = h.last_index;

            // Reverse the prefix so that the LSB becomes the MSB and make space
            // for the next bit.
            var code = bitReverse(u32, prefix, PREFIX_LUT_BITS + 1);

            while (len <= MAXBITS) : (len += 1) {
                code |= try self.readBits(1);
                const count = h.count[len];
                if (code < first + count) {
                    return h.symbol[index + (code - first)];
                }
                index += count;
                first += count;
                first <<= 1;
                code <<= 1;
            }

            return error.OutOfCodes;
        }

        fn step(self: *Self) !void {
            while (true) {
                switch (self.state) {
                    .DecodeBlockHeader => {
                        // The compressed stream is done.
                        if (self.seen_eos) return;

                        const last = @intCast(u1, try self.readBits(1));
                        const kind = @intCast(u2, try self.readBits(2));

                        self.seen_eos = last != 0;

                        // The next state depends on the block type.
                        switch (kind) {
                            0 => try self.stored(),
                            1 => try self.fixed(),
                            2 => try self.dynamic(),
                            3 => return error.InvalidBlockType,
                        }
                    },
                    .DecodeBlockData => {
                        if (!try self.codes(self.hlen, self.hdist)) {
                            return;
                        }

                        self.state = .DecodeBlockHeader;
                    },
                    .Copy => |*length| {
                        const N = math.min(self.window.writable(), length.*);

                        // TODO: This loop can be more efficient. On the other
                        // hand uncompressed blocks are not that common so...
                        var i: usize = 0;
                        while (i < N) : (i += 1) {
                            var tmp: [1]u8 = undefined;
                            if ((try self.inner_reader.read(&tmp)) != 1) {
                                // Unexpected end of stream, keep this error
                                // consistent with the use of readBitsNoEof.
                                return error.EndOfStream;
                            }
                            self.window.appendUnsafe(tmp[0]);
                        }

                        if (N != length.*) {
                            length.* -= N;
                            return;
                        }

                        self.state = .DecodeBlockHeader;
                    },
                    .CopyLit => |c| {
                        if (self.window.append(c) == 0) {
                            return;
                        }

                        self.state = .DecodeBlockData;
                    },
                    .CopyFrom => |*info| {
                        const written = self.window.copyFrom(info.distance, info.length);
                        if (written != info.length) {
                            info.length -= @truncate(u16, written);
                            return;
                        }

                        self.state = .DecodeBlockData;
                    },
                }
            }
        }

        fn init(source: ReaderType, window_slice: []u8) Self {
            assert(math.isPowerOfTwo(window_slice.len));

            return Self{
                .inner_reader = source,
                .window = .{ .buf = window_slice },
                .seen_eos = false,
                .state = .DecodeBlockHeader,
                .hdist = undefined,
                .hlen = undefined,
                .bits = 0,
                .bits_left = 0,
            };
        }

        // Implements the io.Reader interface
        pub fn read(self: *Self, buffer: []u8) Error!usize {
            if (buffer.len == 0)
                return 0;

            // Try reading as much as possible from the window
            var read_amt: usize = self.window.read(buffer);
            while (read_amt < buffer.len) {
                // Run the state machine, we can detect the "effective" end of
                // stream condition by checking if any progress was made.
                // Why "effective"? Because even though `seen_eos` is true we
                // may still have to finish processing other decoding steps.
                try self.step();
                // No progress was made
                if (self.window.readable() == 0)
                    break;

                read_amt += self.window.read(buffer[read_amt..]);
            }

            return read_amt;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }
    };
}

pub fn inflateStream(reader: anytype, window_slice: []u8) InflateStream(@TypeOf(reader)) {
    return InflateStream(@TypeOf(reader)).init(reader, window_slice);
}

test "lengths overflow" {
    // malformed final dynamic block, tries to write 321 code lengths (MAXCODES is 316)
    // f dy  hlit hdist hclen 16  17  18   0 (18)    x138 (18)    x138 (18)     x39 (16) x6
    // 1 10 11101 11101 0000 010 010 010 010 (11) 1111111 (11) 1111111 (11) 0011100 (01) 11
    const stream = [_]u8{ 0b11101101, 0b00011101, 0b00100100, 0b11101001, 0b11111111, 0b11111111, 0b00111001, 0b00001110 };

    const reader = std.io.fixedBufferStream(&stream).reader();
    var window: [0x8000]u8 = undefined;
    var inflate = inflateStream(reader, &window);

    var buf: [1]u8 = undefined;
    try std.testing.expectError(error.InvalidLength, inflate.read(&buf));
}
