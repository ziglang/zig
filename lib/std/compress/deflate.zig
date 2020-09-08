// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
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

const Huffman = struct {
    count: [MAXBITS + 1]u16,
    symbol: [MAXCODES]u16,

    fn construct(self: *Huffman, length: []const u16) !void {
        for (self.count) |*val| {
            val.* = 0;
        }

        for (length) |val| {
            self.count[val] += 1;
        }

        if (self.count[0] == length.len)
            return;

        var left: isize = 1;
        for (self.count[1..]) |val| {
            left *= 2;
            left -= @as(isize, @bitCast(i16, val));
            if (left < 0)
                return error.InvalidTree;
        }

        var offs: [MAXBITS + 1]u16 = undefined;
        {
            var len: usize = 1;
            offs[1] = 0;
            while (len < MAXBITS) : (len += 1) {
                offs[len + 1] = offs[len] + self.count[len];
            }
        }

        for (length) |val, symbol| {
            if (val != 0) {
                self.symbol[offs[val]] = @truncate(u16, symbol);
                offs[val] += 1;
            }
        }
    }
};

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

        bit_reader: io.BitReader(.Little, ReaderType),

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
            fn appendUnsafe(self: *WSelf, value: u8) void {
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
                    const index = (self.wi -% distance) % self.buf.len;
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

        fn stored(self: *Self) !void {
            // Discard the remaining bits, the lenght field is always
            // byte-aligned (and so is the data)
            self.bit_reader.alignToByte();

            const length = (try self.bit_reader.readBitsNoEof(u16, 16));
            const length_cpl = (try self.bit_reader.readBitsNoEof(u16, 16));

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

                const len_lengths = //
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
            const nlen = (try self.bit_reader.readBitsNoEof(usize, 5)) + 257;
            // Number of distance codes
            const ndist = (try self.bit_reader.readBitsNoEof(usize, 5)) + 1;
            // Number of code length codes
            const ncode = (try self.bit_reader.readBitsNoEof(usize, 4)) + 4;

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
                    lengths[val] = try self.bit_reader.readBitsNoEof(u16, 3);
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
                        const repeat = 3 + (try self.bit_reader.readBitsNoEof(usize, 2));
                        const last_index = i + repeat;
                        while (i < last_index) : (i += 1) {
                            lengths[i] = last_length;
                        }
                    },
                    17 => {
                        // repeat zero 3..10 times
                        i += 3 + (try self.bit_reader.readBitsNoEof(usize, 3));
                    },
                    18 => {
                        // repeat zero 11..138 times
                        i += 11 + (try self.bit_reader.readBitsNoEof(usize, 7));
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
                            try self.bit_reader.readBitsNoEof(u16, LEXT[length_symbol]);

                        const distance_symbol = try self.decode(distcode);
                        const distance = DISTS[distance_symbol] +
                            try self.bit_reader.readBitsNoEof(u16, DEXT[distance_symbol]);

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
            var len: usize = 1;
            var code: usize = 0;
            var first: usize = 0;
            var index: usize = 0;

            while (len <= MAXBITS) : (len += 1) {
                code |= try self.bit_reader.readBitsNoEof(usize, 1);
                const count = h.count[len];
                if (code < first + count)
                    return h.symbol[index + (code - first)];
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
                        // The compressed stream is done
                        if (self.seen_eos) return;

                        const last = try self.bit_reader.readBitsNoEof(u1, 1);
                        const kind = try self.bit_reader.readBitsNoEof(u2, 2);

                        self.seen_eos = last != 0;

                        // The next state depends on the block type
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
                            if ((try self.bit_reader.read(&tmp)) != 1) {
                                // Unexpected end of stream, keep this error
                                // consistent with the use of readBitsNoEof
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
                .bit_reader = io.bitReader(.Little, source),
                .window = .{ .buf = window_slice },
                .seen_eos = false,
                .state = .DecodeBlockHeader,
                .hdist = undefined,
                .hlen = undefined,
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
