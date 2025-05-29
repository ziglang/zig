//! Inflate decompresses deflate bit stream. Reads compressed data from reader
//! provided in init. Decompressed data are stored in internal hist buffer and
//! can be accesses iterable `next` or reader interface.
//!
//! Container defines header/footer wrapper around deflate bit stream. Can be
//! gzip or zlib.
//!
//! Deflate bit stream consists of multiple blocks. Block can be one of three types:
//!   * stored, non compressed, max 64k in size
//!   * fixed, huffman codes are predefined
//!   * dynamic, huffman code tables are encoded at the block start
//!
//! `step` function runs decoder until internal `hist` buffer is full. Client than needs to read
//! that data in order to proceed with decoding.
//!
//! Allocates 74.5K of internal buffers, most important are:
//!   * 64K for history (CircularBuffer)
//!   * ~10K huffman decoders (Literal and DistanceDecoder)

const std = @import("../../std.zig");
const flate = std.compress.flate;
const Container = flate.Container;
const Token = @import("Token.zig");
const testing = std.testing;
const Decompress = @This();

input: *std.io.BufferedReader,
// Hashes, produces checksum, of uncompressed data for gzip/zlib footer.
hasher: Container.Hasher,

// dynamic block huffman code decoders
lit_dec: LiteralDecoder,
dst_dec: DistanceDecoder,

// current read state
final_block: bool,
state: State,

read_err: ?Error,

const BlockType = enum(u2) {
    stored = 0,
    fixed = 1,
    dynamic = 2,
};

const State = union(enum) {
    protocol_header,
    block_header,
    stored_block: u16,
    fixed_block,
    dynamic_block,
    protocol_footer,
    end,
};

pub const Error = Container.Error || error{
    InvalidCode,
    InvalidMatch,
    InvalidBlockType,
    WrongStoredBlockNlen,
    InvalidDynamicBlockHeader,
    EndOfStream,
    ReadFailed,
    OversubscribedHuffmanTree,
    IncompleteHuffmanTree,
    MissingEndOfBlockCode,
};

pub fn init(input: *std.io.BufferedReader, container: Container) Decompress {
    return .{
        .input = input,
        .hasher = .init(container),
        .lit_dec = .{},
        .dst_dec = .{},
        .final_block = false,
        .state = .protocol_header,
        .read_err = null,
    };
}

fn decodeLength(self: *Decompress, code: u8) !u16 {
    if (code > 28) return error.InvalidCode;
    const ml = Token.matchLength(code);
    return if (ml.extra_bits == 0) // 0 - 5 extra bits
        ml.base
    else
        ml.base + try self.takeNBitsBuffered(ml.extra_bits);
}

fn decodeDistance(self: *Decompress, code: u8) !u16 {
    if (code > 29) return error.InvalidCode;
    const md = Token.matchDistance(code);
    return if (md.extra_bits == 0) // 0 - 13 extra bits
        md.base
    else
        md.base + try self.takeNBitsBuffered(md.extra_bits);
}

// Decode code length symbol to code length. Writes decoded length into
// lens slice starting at position pos. Returns number of positions
// advanced.
fn dynamicCodeLength(self: *Decompress, code: u16, lens: []u4, pos: usize) !usize {
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
            const n: u8 = @as(u8, try self.takeBits(u2)) + 3;
            if (pos == 0 or pos + n > lens.len)
                return error.InvalidDynamicBlockHeader;
            for (0..n) |i| {
                lens[pos + i] = lens[pos + i - 1];
            }
            return n;
        },
        // Repeat a code length of 0 for 3 - 10 times. (3 bits of length)
        17 => return @as(u8, try self.takeBits(u3)) + 3,
        // Repeat a code length of 0 for 11 - 138 times (7 bits of length)
        18 => return @as(u8, try self.takeBits(u7)) + 11,
        else => return error.InvalidDynamicBlockHeader,
    }
}

// Peek 15 bits from bits reader (maximum code len is 15 bits). Use
// decoder to find symbol for that code. We then know how many bits is
// used. Shift bit reader for that much bits, those bits are used. And
// return symbol.
fn decodeSymbol(self: *Decompress, decoder: anytype) !Symbol {
    const sym = try decoder.find(try self.peekBitsReverseBuffered(u15));
    try self.shiftBits(sym.code_bits);
    return sym;
}

pub fn read(
    context: ?*anyopaque,
    bw: *std.io.BufferedWriter,
    limit: std.io.Limit,
) std.io.Reader.StreamError!usize {
    const d: *Decompress = @alignCast(@ptrCast(context));
    return readInner(d, bw, limit) catch |err| switch (err) {
        error.EndOfStream => return error.EndOfStream,
        error.WriteFailed => return error.WriteFailed,
        else => |e| {
            // In the event of an error, state is unmodified so that it can be
            // better used to diagnose the failure.
            d.read_err = e;
            return error.ReadFailed;
        },
    };
}

fn readInner(
    d: *Decompress,
    bw: *std.io.BufferedWriter,
    limit: std.io.Limit,
) (Error || error{ WriteFailed, EndOfStream })!usize {
    const in = d.input;
    sw: switch (d.state) {
        .protocol_header => switch (d.hasher.container()) {
            .gzip => {
                const Header = extern struct {
                    magic: u16 align(1),
                    method: u8,
                    flags: packed struct(u8) {
                        text: bool,
                        hcrc: bool,
                        extra: bool,
                        name: bool,
                        comment: bool,
                        reserved: u3,
                    },
                    mtime: u32 align(1),
                    xfl: u8,
                    os: u8,
                };
                const header = try in.takeStructEndian(Header, .little);
                if (header.magic != 0x8b1f or header.method != 0x08)
                    return error.BadGzipHeader;
                if (header.flags.extra) {
                    const extra_len = try in.takeInt(u16, .little);
                    try in.discardAll(extra_len);
                }
                if (header.flags.name) {
                    try in.discardDelimiterInclusive(0);
                }
                if (header.flags.comment) {
                    try in.discardDelimiterInclusive(0);
                }
                if (header.flags.hcrc) {
                    try in.discardAll(2);
                }
                continue :sw .block_header;
            },
            .zlib => {
                const Header = extern struct {
                    cmf: packed struct(u8) {
                        cm: u4,
                        cinfo: u4,
                    },
                    flg: u8,
                };
                const header = try in.takeStruct(Header);
                if (header.cmf.cm != 8 or header.cmf.cinfo > 7) return error.BadZlibHeader;
                continue :sw .block_header;
            },
            .raw => continue :sw .block_header,
        },
        .block_header => {
            d.final_block = (try d.takeBits(u1)) != 0;
            const block_type = try d.takeBits(BlockType);
            switch (block_type) {
                .stored => {
                    d.alignBitsToByte(); // skip padding until byte boundary
                    // everything after this is byte aligned in stored block
                    const len = try in.takeInt(u16, .little);
                    const nlen = try in.takeInt(u16, .little);
                    if (len != ~nlen) return error.WrongStoredBlockNlen;
                    continue :sw .{ .stored_block = len };
                },
                .fixed => continue :sw .fixed_block,
                .dynamic => {
                    const hlit: u16 = @as(u16, try d.takeBits(u5)) + 257; // number of ll code entries present - 257
                    const hdist: u16 = @as(u16, try d.takeBits(u5)) + 1; // number of distance code entries - 1
                    const hclen: u8 = @as(u8, try d.takeBits(u4)) + 4; // hclen + 4 code lengths are encoded

                    if (hlit > 286 or hdist > 30)
                        return error.InvalidDynamicBlockHeader;

                    // lengths for code lengths
                    var cl_lens = [_]u4{0} ** 19;
                    for (0..hclen) |i| {
                        cl_lens[flate.huffman.codegen_order[i]] = try d.takeBits(u3);
                    }
                    var cl_dec: CodegenDecoder = .{};
                    try cl_dec.generate(&cl_lens);

                    // decoded code lengths
                    var dec_lens = [_]u4{0} ** (286 + 30);
                    var pos: usize = 0;
                    while (pos < hlit + hdist) {
                        const sym = try cl_dec.find(try d.peekBitsReverse(u7));
                        try d.shiftBits(sym.code_bits);
                        pos += try d.dynamicCodeLength(sym.symbol, &dec_lens, pos);
                    }
                    if (pos > hlit + hdist) {
                        return error.InvalidDynamicBlockHeader;
                    }

                    // literal code lengths to literal decoder
                    try d.lit_dec.generate(dec_lens[0..hlit]);

                    // distance code lengths to distance decoder
                    try d.dst_dec.generate(dec_lens[hlit .. hlit + hdist]);

                    continue :sw .dynamic_block;
                },
            }
        },
        .stored_block => |remaining_len| {
            const out = try bw.writableSliceGreedyPreserving(flate.history_len, 1);
            const limited_out = limit.min(.limited(remaining_len)).slice(out);
            const n = try d.input.readVec(bw, &.{limited_out});
            if (remaining_len - n == 0) {
                d.state = if (d.final_block) .protocol_footer else .block_header;
            } else {
                d.state = .{ .stored_block = remaining_len - n };
            }
            bw.advance(n);
            return n;
        },
        .fixed_block => {
            const start = bw.count;
            while (@intFromEnum(limit) > bw.count - start) {
                const code = try d.readFixedCode();
                switch (code) {
                    0...255 => try bw.writeBytePreserving(flate.history_len, @intCast(code)),
                    256 => {
                        d.state = if (d.final_block) .protocol_footer else .block_header;
                        return bw.count - start;
                    },
                    257...285 => {
                        // Handles fixed block non literal (length) code.
                        // Length code is followed by 5 bits of distance code.
                        const rebased_code = code - 257;
                        const length = try d.decodeLength(rebased_code);
                        const distance = try d.decodeDistance(try d.takeBitsReverseBuffered(u5));
                        try writeMatch(bw, length, distance);
                    },
                    else => return error.InvalidCode,
                }
            }
            d.state = .fixed_block;
            return bw.count - start;
        },
        .dynamic_block => {
            // In larger archives most blocks are usually dynamic, so decompression
            // performance depends on this logic.
            const start = bw.count;
            while (@intFromEnum(limit) > bw.count - start) {
                const sym = try d.decodeSymbol(&d.lit_dec);

                switch (sym.kind) {
                    .literal => d.hist.write(sym.symbol),
                    .match => {
                        // Decode match backreference <length, distance>
                        const length = try d.decodeLength(sym.symbol);
                        const dsm = try d.decodeSymbol(&d.dst_dec);
                        const distance = try d.decodeDistance(dsm.symbol);
                        try writeMatch(bw, length, distance);
                    },
                    .end_of_block => {
                        d.state = if (d.final_block) .protocol_footer else .block_header;
                        return bw.count - start;
                    },
                }
            }
            d.state = .dynamic_block;
            return bw.count - start;
        },
        .protocol_footer => {
            d.alignBitsToByte();
            switch (d.hasher.container()) {
                .gzip => |*gzip| {
                    if (try reader.read(u32) != gzip.final()) return error.WrongGzipChecksum;
                    if (try reader.read(u32) != gzip.count) return error.WrongGzipSize;
                },
                .zlib => |*zlib| {
                    const chksum: u32 = @byteSwap(zlib.final());
                    if (try reader.read(u32) != chksum) return error.WrongZlibChecksum;
                },
                .raw => {},
            }
            d.state = .end;
            return 0;
        },
        .end => return error.EndOfStream,
    }
}

/// Write match (back-reference to the same data slice) starting at `distance`
/// back from current write position, and `length` of bytes.
fn writeMatch(bw: *std.io.BufferedWriter, length: u16, distance: u16) !void {
    _ = bw;
    _ = length;
    _ = distance;
    @panic("TODO");
}

pub fn reader(self: *Decompress) std.io.Reader {
    return .{
        .context = self,
        .vtable = &.{ .read = read },
    };
}

pub fn readable(self: *Decompress, buffer: []u8) std.io.BufferedReader {
    return reader(self).buffered(buffer);
}

fn takeBits(d: *Decompress, comptime T: type) !T {
    _ = d;
    @panic("TODO");
}

fn takeNBitsBuffered(d: *Decompress, n: u4) !u16 {
    _ = d;
    _ = n;
    @panic("TODO");
}

fn peekBitsReverse(d: *Decompress, comptime T: type) !T {
    _ = d;
    @panic("TODO");
}

fn peekBitsReverseBuffered(d: *Decompress, comptime T: type) !T {
    _ = d;
    @panic("TODO");
}

fn alignBitsToByte(d: *Decompress) void {
    _ = d;
    @panic("TODO");
}

fn shiftBits(d: *Decompress, n: u6) !void {
    _ = d;
    _ = n;
    @panic("TODO");
}

fn readFixedCode(d: *Decompress) !u16 {
    _ = d;
    @panic("TODO");
}

pub const Symbol = packed struct {
    pub const Kind = enum(u2) {
        literal,
        end_of_block,
        match,
    };

    symbol: u8 = 0, // symbol from alphabet
    code_bits: u4 = 0, // number of bits in code 0-15
    kind: Kind = .literal,

    code: u16 = 0, // huffman code of the symbol
    next: u16 = 0, // pointer to the next symbol in linked list
    // it is safe to use 0 as null pointer, when sorted 0 has shortest code and fits into lookup

    // Sorting less than function.
    pub fn asc(_: void, a: Symbol, b: Symbol) bool {
        if (a.code_bits == b.code_bits) {
            if (a.kind == b.kind) {
                return a.symbol < b.symbol;
            }
            return @intFromEnum(a.kind) < @intFromEnum(b.kind);
        }
        return a.code_bits < b.code_bits;
    }
};

pub const LiteralDecoder = HuffmanDecoder(286, 15, 9);
pub const DistanceDecoder = HuffmanDecoder(30, 15, 9);
pub const CodegenDecoder = HuffmanDecoder(19, 7, 7);

/// Creates huffman tree codes from list of code lengths (in `build`).
///
/// `find` then finds symbol for code bits. Code can be any length between 1 and
/// 15 bits. When calling `find` we don't know how many bits will be used to
/// find symbol. When symbol is returned it has code_bits field which defines
/// how much we should advance in bit stream.
///
/// Lookup table is used to map 15 bit int to symbol. Same symbol is written
/// many times in this table; 32K places for 286 (at most) symbols.
/// Small lookup table is optimization for faster search.
/// It is variation of the algorithm explained in [zlib](https://github.com/madler/zlib/blob/643e17b7498d12ab8d15565662880579692f769d/doc/algorithm.txt#L92)
/// with difference that we here use statically allocated arrays.
///
fn HuffmanDecoder(
    comptime alphabet_size: u16,
    comptime max_code_bits: u4,
    comptime lookup_bits: u4,
) type {
    const lookup_shift = max_code_bits - lookup_bits;

    return struct {
        // all symbols in alaphabet, sorted by code_len, symbol
        symbols: [alphabet_size]Symbol = undefined,
        // lookup table code -> symbol
        lookup: [1 << lookup_bits]Symbol = undefined,

        const Self = @This();

        /// Generates symbols and lookup tables from list of code lens for each symbol.
        pub fn generate(self: *Self, lens: []const u4) !void {
            try checkCompleteness(lens);

            // init alphabet with code_bits
            for (self.symbols, 0..) |_, i| {
                const cb: u4 = if (i < lens.len) lens[i] else 0;
                self.symbols[i] = if (i < 256)
                    .{ .kind = .literal, .symbol = @intCast(i), .code_bits = cb }
                else if (i == 256)
                    .{ .kind = .end_of_block, .symbol = 0xff, .code_bits = cb }
                else
                    .{ .kind = .match, .symbol = @intCast(i - 257), .code_bits = cb };
            }
            std.sort.heap(Symbol, &self.symbols, {}, Symbol.asc);

            // reset lookup table
            for (0..self.lookup.len) |i| {
                self.lookup[i] = .{};
            }

            // assign code to symbols
            // reference: https://youtu.be/9_YEGLe33NA?list=PLU4IQLU9e_OrY8oASHx0u3IXAL9TOdidm&t=2639
            var code: u16 = 0;
            var idx: u16 = 0;
            for (&self.symbols, 0..) |*sym, pos| {
                if (sym.code_bits == 0) continue; // skip unused
                sym.code = code;

                const next_code = code + (@as(u16, 1) << (max_code_bits - sym.code_bits));
                const next_idx = next_code >> lookup_shift;

                if (next_idx > self.lookup.len or idx >= self.lookup.len) break;
                if (sym.code_bits <= lookup_bits) {
                    // fill small lookup table
                    for (idx..next_idx) |j|
                        self.lookup[j] = sym.*;
                } else {
                    // insert into linked table starting at root
                    const root = &self.lookup[idx];
                    const root_next = root.next;
                    root.next = @intCast(pos);
                    sym.next = root_next;
                }

                idx = next_idx;
                code = next_code;
            }
        }

        /// Given the list of code lengths check that it represents a canonical
        /// Huffman code for n symbols.
        ///
        /// Reference: https://github.com/madler/zlib/blob/5c42a230b7b468dff011f444161c0145b5efae59/contrib/puff/puff.c#L340
        fn checkCompleteness(lens: []const u4) !void {
            if (alphabet_size == 286)
                if (lens[256] == 0) return error.MissingEndOfBlockCode;

            var count = [_]u16{0} ** (@as(usize, max_code_bits) + 1);
            var max: usize = 0;
            for (lens) |n| {
                if (n == 0) continue;
                if (n > max) max = n;
                count[n] += 1;
            }
            if (max == 0) // empty tree
                return;

            // check for an over-subscribed or incomplete set of lengths
            var left: usize = 1; // one possible code of zero length
            for (1..count.len) |len| {
                left <<= 1; // one more bit, double codes left
                if (count[len] > left)
                    return error.OversubscribedHuffmanTree;
                left -= count[len]; // deduct count from possible codes
            }
            if (left > 0) { // left > 0 means incomplete
                // incomplete code ok only for single length 1 code
                if (max_code_bits > 7 and max == count[0] + count[1]) return;
                return error.IncompleteHuffmanTree;
            }
        }

        /// Finds symbol for lookup table code.
        pub fn find(self: *Self, code: u16) !Symbol {
            // try to find in lookup table
            const idx = code >> lookup_shift;
            const sym = self.lookup[idx];
            if (sym.code_bits != 0) return sym;
            // if not use linked list of symbols with same prefix
            return self.findLinked(code, sym.next);
        }

        inline fn findLinked(self: *Self, code: u16, start: u16) !Symbol {
            var pos = start;
            while (pos > 0) {
                const sym = self.symbols[pos];
                const shift = max_code_bits - sym.code_bits;
                // compare code_bits number of upper bits
                if ((code ^ sym.code) >> shift == 0) return sym;
                pos = sym.next;
            }
            return error.InvalidCode;
        }
    };
}

test "init/find" {
    // example data from: https://youtu.be/SJPvNi4HrWQ?t=8423
    const code_lens = [_]u4{ 4, 3, 0, 2, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 3, 2 };
    var h: CodegenDecoder = .{};
    try h.generate(&code_lens);

    const expected = [_]struct {
        sym: Symbol,
        code: u16,
    }{
        .{
            .code = 0b00_00000,
            .sym = .{ .symbol = 3, .code_bits = 2 },
        },
        .{
            .code = 0b01_00000,
            .sym = .{ .symbol = 18, .code_bits = 2 },
        },
        .{
            .code = 0b100_0000,
            .sym = .{ .symbol = 1, .code_bits = 3 },
        },
        .{
            .code = 0b101_0000,
            .sym = .{ .symbol = 4, .code_bits = 3 },
        },
        .{
            .code = 0b110_0000,
            .sym = .{ .symbol = 17, .code_bits = 3 },
        },
        .{
            .code = 0b1110_000,
            .sym = .{ .symbol = 0, .code_bits = 4 },
        },
        .{
            .code = 0b1111_000,
            .sym = .{ .symbol = 16, .code_bits = 4 },
        },
    };

    // unused symbols
    for (0..12) |i| {
        try testing.expectEqual(0, h.symbols[i].code_bits);
    }
    // used, from index 12
    for (expected, 12..) |e, i| {
        try testing.expectEqual(e.sym.symbol, h.symbols[i].symbol);
        try testing.expectEqual(e.sym.code_bits, h.symbols[i].code_bits);
        const sym_from_code = try h.find(e.code);
        try testing.expectEqual(e.sym.symbol, sym_from_code.symbol);
    }

    // All possible codes for each symbol.
    // Lookup table has 126 elements, to cover all possible 7 bit codes.
    for (0b0000_000..0b0100_000) |c| // 0..32 (32)
        try testing.expectEqual(3, (try h.find(@intCast(c))).symbol);

    for (0b0100_000..0b1000_000) |c| // 32..64 (32)
        try testing.expectEqual(18, (try h.find(@intCast(c))).symbol);

    for (0b1000_000..0b1010_000) |c| // 64..80 (16)
        try testing.expectEqual(1, (try h.find(@intCast(c))).symbol);

    for (0b1010_000..0b1100_000) |c| // 80..96 (16)
        try testing.expectEqual(4, (try h.find(@intCast(c))).symbol);

    for (0b1100_000..0b1110_000) |c| // 96..112 (16)
        try testing.expectEqual(17, (try h.find(@intCast(c))).symbol);

    for (0b1110_000..0b1111_000) |c| // 112..120 (8)
        try testing.expectEqual(0, (try h.find(@intCast(c))).symbol);

    for (0b1111_000..0b1_0000_000) |c| // 120...128 (8)
        try testing.expectEqual(16, (try h.find(@intCast(c))).symbol);
}

test "encode/decode literals" {
    const LiteralEncoder = std.compress.flate.Compress.LiteralEncoder;

    for (1..286) |j| { // for all different number of codes
        var enc: LiteralEncoder = .{};
        // create frequencies
        var freq = [_]u16{0} ** 286;
        freq[256] = 1; // ensure we have end of block code
        for (&freq, 1..) |*f, i| {
            if (i % j == 0)
                f.* = @intCast(i);
        }

        // encoder from frequencies
        enc.generate(&freq, 15);

        // get code_lens from encoder
        var code_lens = [_]u4{0} ** 286;
        for (code_lens, 0..) |_, i| {
            code_lens[i] = @intCast(enc.codes[i].len);
        }
        // generate decoder from code lens
        var dec: LiteralDecoder = .{};
        try dec.generate(&code_lens);

        // expect decoder code to match original encoder code
        for (dec.symbols) |s| {
            if (s.code_bits == 0) continue;
            const c_code: u16 = @bitReverse(@as(u15, @intCast(s.code)));
            const symbol: u16 = switch (s.kind) {
                .literal => s.symbol,
                .end_of_block => 256,
                .match => @as(u16, s.symbol) + 257,
            };

            const c = enc.codes[symbol];
            try testing.expect(c.code == c_code);
        }

        // find each symbol by code
        for (enc.codes) |c| {
            if (c.len == 0) continue;

            const s_code: u15 = @bitReverse(@as(u15, @intCast(c.code)));
            const s = try dec.find(s_code);
            try testing.expect(s.code == s_code);
            try testing.expect(s.code_bits == c.len);
        }
    }
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
        var fb: std.io.BufferedReader = undefined;
        fb.initFixed(@constCast(c.in));
        var aw: std.io.AllocatingWriter = undefined;
        aw.init(testing.allocator);
        defer aw.deinit();

        var decompress: Decompress = .init(&fb, .raw);
        var decompress_br = decompress.readable(&.{});
        _ = try decompress_br.readRemaining(&aw.buffered_writer);
        try testing.expectEqualStrings(c.out, aw.getWritten());
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
        var fb: std.io.BufferedReader = undefined;
        fb.initFixed(@constCast(c.in));
        var aw: std.io.AllocatingWriter = undefined;
        aw.init(testing.allocator);
        defer aw.deinit();

        var decompress: Decompress = .init(&fb, .gzip);
        var decompress_br = decompress.readable(&.{});
        _ = try decompress_br.readRemaining(&aw.buffered_writer);
        try testing.expectEqualStrings(c.out, aw.getWritten());
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
        var fb: std.io.BufferedReader = undefined;
        fb.initFixed(@constCast(c.in));
        var aw: std.io.AllocatingWriter = undefined;
        aw.init(testing.allocator);
        defer aw.deinit();

        var decompress: Decompress = .init(&fb, .zlib);
        var decompress_br = decompress.readable(&.{});
        _ = try decompress_br.readRemaining(&aw.buffered_writer);
        try testing.expectEqualStrings(c.out, aw.getWritten());
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
        var in: std.io.BufferedReader = undefined;
        in.initFixed(@constCast(@embedFile("testdata/fuzz/" ++ c.input ++ ".input")));
        var aw: std.io.AllocatingWriter = undefined;
        aw.init(testing.allocator);
        defer aw.deinit();
        errdefer std.debug.print("test case failed {}\n", .{case_no});

        var decompress: Decompress = .init(&in, .raw);
        var decompress_br = decompress.readable(&.{});
        if (c.err) |expected_err| {
            try testing.expectError(error.ReadFailed, decompress_br.readRemaining(&aw.buffered_writer));
            try testing.expectError(expected_err, decompress.read_err.?);
        } else {
            _ = try decompress_br.readRemaining(&aw.buffered_writer);
            try testing.expectEqualStrings(c.out, aw.getWritten());
        }
    }
}

test "bug 18966" {
    const input = @embedFile("testdata/fuzz/bug_18966.input");
    const expect = @embedFile("testdata/fuzz/bug_18966.expect");

    var in: std.io.BufferedReader = undefined;
    in.initFixed(@constCast(input));
    var aw: std.io.AllocatingWriter = undefined;
    aw.init(testing.allocator);
    defer aw.deinit();

    var decompress: Decompress = .init(&in, .gzip);
    var decompress_br = decompress.readable(&.{});
    _ = try decompress_br.readRemaining(&aw.buffered_writer);
    try testing.expectEqualStrings(expect, aw.getWritten());
}

test "reading into empty buffer" {
    // Inspired by https://github.com/ziglang/zig/issues/19895
    const input = &[_]u8{
        0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
        'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a, // non compressed data
    };
    var in: std.io.BufferedReader = undefined;
    in.initFixed(@constCast(input));
    var decomp: Decompress = .init(&in, .raw);
    var decompress_br = decomp.readable(&.{});
    var buf: [0]u8 = undefined;
    try testing.expectEqual(0, try decompress_br.readVec(&.{&buf}));
}
