const std = @import("../../std.zig");
const assert = std.debug.assert;
const flate = std.compress.flate;
const testing = std.testing;
const Writer = std.Io.Writer;
const Reader = std.Io.Reader;
const Container = flate.Container;

const Decompress = @This();
const Token = @import("Token.zig");

input: *Reader,
next_bits: Bits,
remaining_bits: std.math.Log2Int(Bits),

reader: Reader,

container_metadata: Container.Metadata,

lit_dec: LiteralDecoder,
dst_dec: DistanceDecoder,

final_block: bool,
state: State,

err: ?Error,

/// TODO: change this to usize
const Bits = u64;

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
    dynamic_block_literal: u8,
    dynamic_block_match: u16,
    protocol_footer,
    end,
};

pub const Error = Container.Error || error{
    InvalidCode,
    InvalidMatch,
    WrongStoredBlockNlen,
    InvalidDynamicBlockHeader,
    ReadFailed,
    OversubscribedHuffmanTree,
    IncompleteHuffmanTree,
    MissingEndOfBlockCode,
    EndOfStream,
};

const direct_vtable: Reader.VTable = .{
    .stream = streamDirect,
    .rebase = rebaseFallible,
    .discard = discard,
    .readVec = readVec,
};

const indirect_vtable: Reader.VTable = .{
    .stream = streamIndirect,
    .rebase = rebaseFallible,
    .discard = discardIndirect,
    .readVec = readVec,
};

pub fn init(input: *Reader, container: Container, buffer: []u8) Decompress {
    return .{
        .reader = .{
            .vtable = if (buffer.len == 0) &direct_vtable else &indirect_vtable,
            .buffer = buffer,
            .seek = 0,
            .end = 0,
        },
        .input = input,
        .next_bits = 0,
        .remaining_bits = 0,
        .container_metadata = .init(container),
        .lit_dec = .{},
        .dst_dec = .{},
        .final_block = false,
        .state = .protocol_header,
        .err = null,
    };
}

fn rebaseFallible(r: *Reader, capacity: usize) Reader.RebaseError!void {
    rebase(r, capacity);
}

fn rebase(r: *Reader, capacity: usize) void {
    assert(capacity <= r.buffer.len - flate.history_len);
    assert(r.end + capacity > r.buffer.len);
    const discard_n = r.end - flate.history_len;
    const keep = r.buffer[discard_n..r.end];
    @memmove(r.buffer[0..keep.len], keep);
    assert(keep.len != 0);
    r.end = keep.len;
    r.seek -= discard_n;
}

/// This could be improved so that when an amount is discarded that includes an
/// entire frame, skip decoding that frame.
fn discard(r: *Reader, limit: std.Io.Limit) Reader.Error!usize {
    if (r.end + flate.history_len > r.buffer.len) rebase(r, flate.history_len);
    var writer: Writer = .{
        .vtable = &.{
            .drain = std.Io.Writer.Discarding.drain,
            .sendFile = std.Io.Writer.Discarding.sendFile,
        },
        .buffer = r.buffer,
        .end = r.end,
    };
    defer {
        assert(writer.end != 0);
        r.end = writer.end;
        r.seek = r.end;
    }
    const n = r.stream(&writer, limit) catch |err| switch (err) {
        error.WriteFailed => unreachable,
        error.ReadFailed => return error.ReadFailed,
        error.EndOfStream => return error.EndOfStream,
    };
    assert(n <= @intFromEnum(limit));
    return n;
}

fn discardIndirect(r: *Reader, limit: std.Io.Limit) Reader.Error!usize {
    const d: *Decompress = @alignCast(@fieldParentPtr("reader", r));
    if (r.end + flate.history_len > r.buffer.len) rebase(r, flate.history_len);
    var writer: Writer = .{
        .buffer = r.buffer,
        .end = r.end,
        .vtable = &.{ .drain = Writer.unreachableDrain },
    };
    {
        defer r.end = writer.end;
        _ = streamFallible(d, &writer, .limited(writer.buffer.len - writer.end)) catch |err| switch (err) {
            error.WriteFailed => unreachable,
            else => |e| return e,
        };
    }
    const n = limit.minInt(r.end - r.seek);
    r.seek += n;
    return n;
}

fn readVec(r: *Reader, data: [][]u8) Reader.Error!usize {
    _ = data;
    const d: *Decompress = @alignCast(@fieldParentPtr("reader", r));
    return streamIndirectInner(d);
}

fn streamIndirectInner(d: *Decompress) Reader.Error!usize {
    const r = &d.reader;
    if (r.end + flate.history_len > r.buffer.len) rebase(r, flate.history_len);
    var writer: Writer = .{
        .buffer = r.buffer,
        .end = r.end,
        .vtable = &.{ .drain = Writer.unreachableDrain },
    };
    defer r.end = writer.end;
    _ = streamFallible(d, &writer, .limited(writer.buffer.len - writer.end)) catch |err| switch (err) {
        error.WriteFailed => unreachable,
        else => |e| return e,
    };
    return 0;
}

fn decodeLength(self: *Decompress, code: u8) !u16 {
    if (code > 28) return error.InvalidCode;
    const ml = Token.matchLength(code);
    return if (ml.extra_bits == 0) // 0 - 5 extra bits
        ml.base
    else
        ml.base + try self.takeBitsRuntime(ml.extra_bits);
}

fn decodeDistance(self: *Decompress, code: u8) !u16 {
    if (code > 29) return error.InvalidCode;
    const md = Token.matchDistance(code);
    return if (md.extra_bits == 0) // 0 - 13 extra bits
        md.base
    else
        md.base + try self.takeBitsRuntime(md.extra_bits);
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

fn decodeSymbol(self: *Decompress, decoder: anytype) !Symbol {
    // Maximum code len is 15 bits.
    const sym = try decoder.find(@bitReverse(try self.peekBits(u15)));
    try self.tossBits(sym.code_bits);
    return sym;
}

fn streamDirect(r: *Reader, w: *Writer, limit: std.Io.Limit) Reader.StreamError!usize {
    const d: *Decompress = @alignCast(@fieldParentPtr("reader", r));
    return streamFallible(d, w, limit);
}

fn streamIndirect(r: *Reader, w: *Writer, limit: std.Io.Limit) Reader.StreamError!usize {
    const d: *Decompress = @alignCast(@fieldParentPtr("reader", r));
    _ = limit;
    _ = w;
    return streamIndirectInner(d);
}

fn streamFallible(d: *Decompress, w: *Writer, limit: std.Io.Limit) Reader.StreamError!usize {
    return streamInner(d, w, limit) catch |err| switch (err) {
        error.EndOfStream => {
            if (d.state == .end) {
                return error.EndOfStream;
            } else {
                d.err = error.EndOfStream;
                return error.ReadFailed;
            }
        },
        error.WriteFailed => return error.WriteFailed,
        else => |e| {
            // In the event of an error, state is unmodified so that it can be
            // better used to diagnose the failure.
            d.err = e;
            return error.ReadFailed;
        },
    };
}

fn streamInner(d: *Decompress, w: *Writer, limit: std.Io.Limit) (Error || Reader.StreamError)!usize {
    var remaining = @intFromEnum(limit);
    const in = d.input;
    sw: switch (d.state) {
        .protocol_header => switch (d.container_metadata.container()) {
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
                const header = try in.takeStruct(Header, .little);
                if (header.magic != 0x8b1f or header.method != 0x08)
                    return error.BadGzipHeader;
                if (header.flags.extra) {
                    const extra_len = try in.takeInt(u16, .little);
                    try in.discardAll(extra_len);
                }
                if (header.flags.name) {
                    _ = try in.discardDelimiterInclusive(0);
                }
                if (header.flags.comment) {
                    _ = try in.discardDelimiterInclusive(0);
                }
                if (header.flags.hcrc) {
                    try in.discardAll(2);
                }
                continue :sw .block_header;
            },
            .zlib => {
                const header = try in.takeArray(2);
                const cmf: packed struct(u8) { cm: u4, cinfo: u4 } = @bitCast(header[0]);
                if (cmf.cm != 8 or cmf.cinfo > 7) return error.BadZlibHeader;
                continue :sw .block_header;
            },
            .raw => continue :sw .block_header,
        },
        .block_header => {
            d.final_block = (try d.takeBits(u1)) != 0;
            const block_type: BlockType = @enumFromInt(try d.takeBits(u2));
            switch (block_type) {
                .stored => {
                    d.alignBitsDiscarding();
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
                    var cl_lens: [19]u4 = @splat(0);
                    for (flate.HuffmanEncoder.codegen_order[0..hclen]) |i| {
                        cl_lens[i] = try d.takeBits(u3);
                    }
                    var cl_dec: CodegenDecoder = .{};
                    try cl_dec.generate(&cl_lens);

                    // decoded code lengths
                    var dec_lens: [286 + 30]u4 = @splat(0);
                    var pos: usize = 0;
                    while (pos < hlit + hdist) {
                        const peeked = @bitReverse(try d.peekBits(u7));
                        const sym = try cl_dec.find(peeked);
                        try d.tossBits(sym.code_bits);
                        pos += try d.dynamicCodeLength(sym.symbol, &dec_lens, pos);
                    }
                    if (pos > hlit + hdist) {
                        return error.InvalidDynamicBlockHeader;
                    }

                    // literal code lengths to literal decoder
                    try d.lit_dec.generate(dec_lens[0..hlit]);

                    // distance code lengths to distance decoder
                    try d.dst_dec.generate(dec_lens[hlit..][0..hdist]);

                    continue :sw .dynamic_block;
                },
            }
        },
        .stored_block => |remaining_len| {
            const out = try w.writableSliceGreedyPreserve(flate.history_len, 1);
            var limited_out: [1][]u8 = .{limit.min(.limited(remaining_len)).slice(out)};
            const n = try d.input.readVec(&limited_out);
            if (remaining_len - n == 0) {
                d.state = if (d.final_block) .protocol_footer else .block_header;
            } else {
                d.state = .{ .stored_block = @intCast(remaining_len - n) };
            }
            w.advance(n);
            return @intFromEnum(limit) - remaining + n;
        },
        .fixed_block => {
            while (remaining > 0) {
                const code = try d.readFixedCode();
                switch (code) {
                    0...255 => {
                        try w.writeBytePreserve(flate.history_len, @intCast(code));
                        remaining -= 1;
                    },
                    256 => {
                        d.state = if (d.final_block) .protocol_footer else .block_header;
                        return @intFromEnum(limit) - remaining;
                    },
                    257...285 => {
                        // Handles fixed block non literal (length) code.
                        // Length code is followed by 5 bits of distance code.
                        const length = try d.decodeLength(@intCast(code - 257));
                        const distance = try d.decodeDistance(@bitReverse(try d.takeBits(u5)));
                        try writeMatch(w, length, distance);
                        remaining -= length;
                    },
                    else => return error.InvalidCode,
                }
            }
            d.state = .fixed_block;
            return @intFromEnum(limit) - remaining;
        },
        .dynamic_block => {
            // In larger archives most blocks are usually dynamic, so
            // decompression performance depends on this logic.
            var sym = try d.decodeSymbol(&d.lit_dec);
            sym: switch (sym.kind) {
                .literal => {
                    if (remaining != 0) {
                        @branchHint(.likely);
                        remaining -= 1;
                        try w.writeBytePreserve(flate.history_len, sym.symbol);
                        sym = try d.decodeSymbol(&d.lit_dec);
                        continue :sym sym.kind;
                    } else {
                        d.state = .{ .dynamic_block_literal = sym.symbol };
                        return @intFromEnum(limit) - remaining;
                    }
                },
                .match => {
                    // Decode match backreference <length, distance>
                    const length = try d.decodeLength(sym.symbol);
                    continue :sw .{ .dynamic_block_match = length };
                },
                .end_of_block => {
                    d.state = if (d.final_block) .protocol_footer else .block_header;
                    continue :sw d.state;
                },
            }
        },
        .dynamic_block_literal => |symbol| {
            assert(remaining != 0);
            remaining -= 1;
            try w.writeBytePreserve(flate.history_len, symbol);
            continue :sw .dynamic_block;
        },
        .dynamic_block_match => |length| {
            if (remaining >= length) {
                @branchHint(.likely);
                remaining -= length;
                const dsm = try d.decodeSymbol(&d.dst_dec);
                const distance = try d.decodeDistance(dsm.symbol);
                try writeMatch(w, length, distance);
                continue :sw .dynamic_block;
            } else {
                d.state = .{ .dynamic_block_match = length };
                return @intFromEnum(limit) - remaining;
            }
        },
        .protocol_footer => {
            switch (d.container_metadata) {
                .gzip => |*gzip| {
                    d.alignBitsDiscarding();
                    gzip.* = .{
                        .crc = try in.takeInt(u32, .little),
                        .count = try in.takeInt(u32, .little),
                    };
                },
                .zlib => |*zlib| {
                    d.alignBitsDiscarding();
                    zlib.* = .{
                        .adler = try in.takeInt(u32, .little),
                    };
                },
                .raw => {
                    d.alignBitsPreserving();
                },
            }
            d.state = .end;
            return @intFromEnum(limit) - remaining;
        },
        .end => return error.EndOfStream,
    }
}

/// Write match (back-reference to the same data slice) starting at `distance`
/// back from current write position, and `length` of bytes.
fn writeMatch(w: *Writer, length: u16, distance: u16) !void {
    if (w.end < distance) return error.InvalidMatch;
    if (length < Token.base_length) return error.InvalidMatch;
    if (length > Token.max_length) return error.InvalidMatch;
    if (distance < Token.min_distance) return error.InvalidMatch;
    if (distance > Token.max_distance) return error.InvalidMatch;

    // This is not a @memmove; it intentionally repeats patterns caused by
    // iterating one byte at a time.
    const dest = try w.writableSlicePreserve(flate.history_len, length);
    const end = dest.ptr - w.buffer.ptr;
    const src = w.buffer[end - distance ..][0..length];
    for (dest, src) |*d, s| d.* = s;
}

fn takeBits(d: *Decompress, comptime U: type) !U {
    const remaining_bits = d.remaining_bits;
    const next_bits = d.next_bits;
    if (remaining_bits >= @bitSizeOf(U)) {
        const u: U = @truncate(next_bits);
        d.next_bits = next_bits >> @bitSizeOf(U);
        d.remaining_bits = remaining_bits - @bitSizeOf(U);
        return u;
    }
    const in = d.input;
    const next_int = in.takeInt(Bits, .little) catch |err| switch (err) {
        error.ReadFailed => return error.ReadFailed,
        error.EndOfStream => return takeBitsEnding(d, U),
    };
    const needed_bits = @bitSizeOf(U) - remaining_bits;
    const u: U = @intCast(((next_int & ((@as(Bits, 1) << needed_bits) - 1)) << remaining_bits) | next_bits);
    d.next_bits = next_int >> needed_bits;
    d.remaining_bits = @intCast(@bitSizeOf(Bits) - @as(usize, needed_bits));
    return u;
}

fn takeBitsEnding(d: *Decompress, comptime U: type) !U {
    const remaining_bits = d.remaining_bits;
    const next_bits = d.next_bits;
    const in = d.input;
    const n = in.bufferedLen();
    assert(n < @sizeOf(Bits));
    const needed_bits = @bitSizeOf(U) - remaining_bits;
    if (n * 8 < needed_bits) return error.EndOfStream;
    const next_int = in.takeVarInt(Bits, .little, n) catch |err| switch (err) {
        error.ReadFailed => return error.ReadFailed,
        error.EndOfStream => unreachable,
    };
    const u: U = @intCast(((next_int & ((@as(Bits, 1) << needed_bits) - 1)) << remaining_bits) | next_bits);
    d.next_bits = next_int >> needed_bits;
    d.remaining_bits = @intCast(n * 8 - @as(usize, needed_bits));
    return u;
}

fn peekBits(d: *Decompress, comptime U: type) !U {
    const remaining_bits = d.remaining_bits;
    const next_bits = d.next_bits;
    if (remaining_bits >= @bitSizeOf(U)) return @truncate(next_bits);
    const in = d.input;
    const next_int = in.peekInt(Bits, .little) catch |err| switch (err) {
        error.ReadFailed => return error.ReadFailed,
        error.EndOfStream => return peekBitsEnding(d, U),
    };
    const needed_bits = @bitSizeOf(U) - remaining_bits;
    return @intCast(((next_int & ((@as(Bits, 1) << needed_bits) - 1)) << remaining_bits) | next_bits);
}

fn peekBitsEnding(d: *Decompress, comptime U: type) !U {
    const remaining_bits = d.remaining_bits;
    const next_bits = d.next_bits;
    const in = d.input;
    var u: Bits = 0;
    var remaining_needed_bits = @bitSizeOf(U) - remaining_bits;
    var i: usize = 0;
    while (remaining_needed_bits >= 8) {
        const byte = try specialPeek(in, next_bits, i);
        u |= @as(Bits, byte) << @intCast(i * 8);
        remaining_needed_bits -= 8;
        i += 1;
    }
    if (remaining_needed_bits != 0) {
        const byte = try specialPeek(in, next_bits, i);
        u |= @as(Bits, byte) << @intCast((i * 8) + remaining_needed_bits);
    }
    return @truncate((u << remaining_bits) | next_bits);
}

/// If there is any unconsumed data, handles EndOfStream by pretending there
/// are zeroes afterwards.
fn specialPeek(in: *Reader, next_bits: Bits, i: usize) Reader.Error!u8 {
    const peeked = in.peek(i + 1) catch |err| switch (err) {
        error.ReadFailed => return error.ReadFailed,
        error.EndOfStream => if (next_bits == 0 and i == 0) return error.EndOfStream else return 0,
    };
    return peeked[i];
}

fn tossBits(d: *Decompress, n: u4) !void {
    const remaining_bits = d.remaining_bits;
    const next_bits = d.next_bits;
    if (remaining_bits >= n) {
        d.next_bits = next_bits >> n;
        d.remaining_bits = remaining_bits - n;
    } else {
        const in = d.input;
        const next_int = in.takeInt(Bits, .little) catch |err| switch (err) {
            error.ReadFailed => return error.ReadFailed,
            error.EndOfStream => return tossBitsEnding(d, n),
        };
        const needed_bits = n - remaining_bits;
        d.next_bits = next_int >> needed_bits;
        d.remaining_bits = @intCast(@bitSizeOf(Bits) - @as(usize, needed_bits));
    }
}

fn tossBitsEnding(d: *Decompress, n: u4) !void {
    const remaining_bits = d.remaining_bits;
    const in = d.input;
    const buffered_n = in.bufferedLen();
    if (buffered_n == 0) return error.EndOfStream;
    assert(buffered_n < @sizeOf(Bits));
    const needed_bits = n - remaining_bits;
    const next_int = in.takeVarInt(Bits, .little, buffered_n) catch |err| switch (err) {
        error.ReadFailed => return error.ReadFailed,
        error.EndOfStream => unreachable,
    };
    d.next_bits = next_int >> needed_bits;
    d.remaining_bits = @intCast(@as(usize, buffered_n) * 8 -| @as(usize, needed_bits));
}

fn takeBitsRuntime(d: *Decompress, n: u4) !u16 {
    const x = try peekBits(d, u16);
    const mask: u16 = (@as(u16, 1) << n) - 1;
    const u: u16 = @as(u16, @truncate(x)) & mask;
    try tossBits(d, n);
    return u;
}

fn alignBitsDiscarding(d: *Decompress) void {
    const remaining_bits = d.remaining_bits;
    if (remaining_bits == 0) return;
    const n_bytes = remaining_bits / 8;
    const in = d.input;
    in.seek -= n_bytes;
    d.remaining_bits = 0;
    d.next_bits = 0;
}

fn alignBitsPreserving(d: *Decompress) void {
    const remaining_bits: usize = d.remaining_bits;
    if (remaining_bits == 0) return;
    const n_bytes = (remaining_bits + 7) / 8;
    const in = d.input;
    in.seek -= n_bytes;
    d.remaining_bits = 0;
    d.next_bits = 0;
}

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
fn readFixedCode(d: *Decompress) !u16 {
    const code7 = @bitReverse(try d.takeBits(u7));
    return switch (code7) {
        0...0b0010_111 => @as(u16, code7) + 256,
        0b0010_111 + 1...0b1011_111 => (@as(u16, code7) << 1) + @as(u16, try d.takeBits(u1)) - 0b0011_0000,
        0b1011_111 + 1...0b1100_011 => (@as(u16, code7 - 0b1100000) << 1) + try d.takeBits(u1) + 280,
        else => (@as(u16, code7 - 0b1100_100) << 2) + @as(u16, @bitReverse(try d.takeBits(u2))) + 144,
    };
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
    var codes: [flate.HuffmanEncoder.max_num_frequencies]flate.HuffmanEncoder.Code = undefined;
    for (1..286) |j| { // for all different number of codes
        var enc: flate.HuffmanEncoder = .{
            .codes = &codes,
            .freq_cache = undefined,
            .bit_count = undefined,
            .lns = undefined,
            .lfs = undefined,
        };
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

test "non compressed block (type 0)" {
    try testDecompress(.raw, &[_]u8{
        0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
        'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a, // non compressed data
    }, "Hello world\n");
}

test "fixed code block (type 1)" {
    try testDecompress(.raw, &[_]u8{
        0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0x28, 0xcf, // deflate data block type 1
        0x2f, 0xca, 0x49, 0xe1, 0x02, 0x00,
    }, "Hello world\n");
}

test "dynamic block (type 2)" {
    try testDecompress(.raw, &[_]u8{
        0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02, // deflate data block type 2
        0x30, 0x2b, 0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38,
        0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01,
    }, "ABCDEABCD ABCDEABCD");
}

test "gzip non compressed block (type 0)" {
    try testDecompress(.gzip, &[_]u8{
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, // gzip header (10 bytes)
        0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
        'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a, // non compressed data
        0xd5, 0xe0, 0x39, 0xb7, // gzip footer: checksum
        0x0c, 0x00, 0x00, 0x00, // gzip footer: size
    }, "Hello world\n");
}

test "gzip fixed code block (type 1)" {
    try testDecompress(.gzip, &[_]u8{
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04, 0x03, // gzip header (10 bytes)
        0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0x28, 0xcf, // deflate data block type 1
        0x2f, 0xca, 0x49, 0xe1, 0x02, 0x00,
        0xd5, 0xe0, 0x39, 0xb7, 0x0c, 0x00, 0x00, 0x00, // gzip footer (chksum, len)
    }, "Hello world\n");
}

test "gzip dynamic block (type 2)" {
    try testDecompress(.gzip, &[_]u8{
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, // gzip header (10 bytes)
        0x3d, 0xc6, 0x39, 0x11, 0x00, 0x00, 0x0c, 0x02, // deflate data block type 2
        0x30, 0x2b, 0xb5, 0x52, 0x1e, 0xff, 0x96, 0x38,
        0x16, 0x96, 0x5c, 0x1e, 0x94, 0xcb, 0x6d, 0x01,
        0x17, 0x1c, 0x39, 0xb4, 0x13, 0x00, 0x00, 0x00, // gzip footer (chksum, len)
    }, "ABCDEABCD ABCDEABCD");
}

test "gzip header with name" {
    try testDecompress(.gzip, &[_]u8{
        0x1f, 0x8b, 0x08, 0x08, 0xe5, 0x70, 0xb1, 0x65, 0x00, 0x03, 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x2e,
        0x74, 0x78, 0x74, 0x00, 0xf3, 0x48, 0xcd, 0xc9, 0xc9, 0x57, 0x28, 0xcf, 0x2f, 0xca, 0x49, 0xe1,
        0x02, 0x00, 0xd5, 0xe0, 0x39, 0xb7, 0x0c, 0x00, 0x00, 0x00,
    }, "Hello world\n");
}

test "zlib decompress non compressed block (type 0)" {
    try testDecompress(.zlib, &[_]u8{
        0x78, 0b10_0_11100, // zlib header (2 bytes)
        0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
        'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a, // non compressed data
        0x1c, 0xf2, 0x04, 0x47, // zlib footer: checksum
    }, "Hello world\n");
}

test "failing end-of-stream" {
    try testFailure(.raw, @embedFile("testdata/fuzz/end-of-stream.input"), error.EndOfStream);
}
test "failing invalid-distance" {
    try testFailure(.raw, @embedFile("testdata/fuzz/invalid-distance.input"), error.InvalidMatch);
}
test "failing invalid-tree01" {
    try testFailure(.raw, @embedFile("testdata/fuzz/invalid-tree01.input"), error.IncompleteHuffmanTree);
}
test "failing invalid-tree02" {
    try testFailure(.raw, @embedFile("testdata/fuzz/invalid-tree02.input"), error.EndOfStream);
}
test "failing invalid-tree03" {
    try testFailure(.raw, @embedFile("testdata/fuzz/invalid-tree03.input"), error.IncompleteHuffmanTree);
}
test "failing lengths-overflow" {
    try testFailure(.raw, @embedFile("testdata/fuzz/lengths-overflow.input"), error.InvalidDynamicBlockHeader);
}
test "failing out-of-codes" {
    try testFailure(.raw, @embedFile("testdata/fuzz/out-of-codes.input"), error.InvalidCode);
}
test "failing puff01" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff01.input"), error.WrongStoredBlockNlen);
}
test "failing puff02" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff02.input"), error.EndOfStream);
}
test "failing puff04" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff04.input"), error.InvalidCode);
}
test "failing puff05" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff05.input"), error.EndOfStream);
}
test "failing puff06" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff06.input"), error.EndOfStream);
}
test "failing puff08" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff08.input"), error.InvalidCode);
}
test "failing puff10" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff10.input"), error.InvalidCode);
}
test "failing puff11" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff11.input"), error.EndOfStream);
}
test "failing puff12" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff12.input"), error.InvalidDynamicBlockHeader);
}
test "failing puff13" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff13.input"), error.IncompleteHuffmanTree);
}
test "failing puff14" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff14.input"), error.EndOfStream);
}
test "failing puff15" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff15.input"), error.IncompleteHuffmanTree);
}
test "failing puff16" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff16.input"), error.InvalidDynamicBlockHeader);
}
test "failing puff17" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff17.input"), error.MissingEndOfBlockCode);
}
test "failing fuzz1" {
    try testFailure(.raw, @embedFile("testdata/fuzz/fuzz1.input"), error.InvalidDynamicBlockHeader);
}
test "failing fuzz2" {
    try testFailure(.raw, @embedFile("testdata/fuzz/fuzz2.input"), error.InvalidDynamicBlockHeader);
}
test "failing fuzz3" {
    try testFailure(.raw, @embedFile("testdata/fuzz/fuzz3.input"), error.InvalidMatch);
}
test "failing fuzz4" {
    try testFailure(.raw, @embedFile("testdata/fuzz/fuzz4.input"), error.OversubscribedHuffmanTree);
}
test "failing puff18" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff18.input"), error.OversubscribedHuffmanTree);
}
test "failing puff19" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff19.input"), error.OversubscribedHuffmanTree);
}
test "failing puff20" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff20.input"), error.OversubscribedHuffmanTree);
}
test "failing puff21" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff21.input"), error.OversubscribedHuffmanTree);
}
test "failing puff22" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff22.input"), error.OversubscribedHuffmanTree);
}
test "failing puff23" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff23.input"), error.OversubscribedHuffmanTree);
}
test "failing puff24" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff24.input"), error.IncompleteHuffmanTree);
}
test "failing puff25" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff25.input"), error.OversubscribedHuffmanTree);
}
test "failing puff26" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff26.input"), error.InvalidDynamicBlockHeader);
}
test "failing puff27" {
    try testFailure(.raw, @embedFile("testdata/fuzz/puff27.input"), error.InvalidDynamicBlockHeader);
}

test "deflate-stream" {
    try testDecompress(
        .raw,
        @embedFile("testdata/fuzz/deflate-stream.input"),
        @embedFile("testdata/fuzz/deflate-stream.expect"),
    );
}

test "empty-distance-alphabet01" {
    try testFailure(.raw, @embedFile("testdata/fuzz/empty-distance-alphabet01.input"), error.EndOfStream);
}

test "empty-distance-alphabet02" {
    try testDecompress(.raw, @embedFile("testdata/fuzz/empty-distance-alphabet02.input"), "");
}

test "puff03" {
    try testDecompress(.raw, @embedFile("testdata/fuzz/puff03.input"), &.{0xa});
}

test "puff09" {
    try testDecompress(.raw, @embedFile("testdata/fuzz/puff09.input"), "P");
}

test "bug 18966" {
    try testDecompress(
        .gzip,
        @embedFile("testdata/fuzz/bug_18966.input"),
        @embedFile("testdata/fuzz/bug_18966.expect"),
    );
}

test "reading into empty buffer" {
    // Inspired by https://github.com/ziglang/zig/issues/19895
    const input = &[_]u8{
        0b0000_0001, 0b0000_1100, 0x00, 0b1111_0011, 0xff, // deflate fixed buffer header len, nlen
        'H', 'e', 'l', 'l', 'o', ' ', 'w', 'o', 'r', 'l', 'd', 0x0a, // non compressed data
    };
    var in: Reader = .fixed(input);
    var decomp: Decompress = .init(&in, .raw, &.{});
    const r = &decomp.reader;
    var bufs: [1][]u8 = .{&.{}};
    try testing.expectEqual(0, try r.readVec(&bufs));
}

test "zlib header" {
    // Truncated header
    try testFailure(.zlib, &[_]u8{0x78}, error.EndOfStream);

    // Wrong CM
    try testFailure(.zlib, &[_]u8{ 0x79, 0x94 }, error.BadZlibHeader);

    // Wrong CINFO
    try testFailure(.zlib, &[_]u8{ 0x88, 0x98 }, error.BadZlibHeader);

    // Truncated checksum
    try testFailure(.zlib, &[_]u8{ 0x78, 0xda, 0x03, 0x00, 0x00 }, error.EndOfStream);
}

test "gzip header" {
    // Truncated header
    try testFailure(.gzip, &[_]u8{ 0x1f, 0x8B }, error.EndOfStream);

    // Wrong CM
    try testFailure(.gzip, &[_]u8{
        0x1f, 0x8b, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x03,
    }, error.BadGzipHeader);

    // Truncated checksum
    try testFailure(.gzip, &[_]u8{
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00,
    }, error.EndOfStream);

    // Truncated initial size field
    try testFailure(.gzip, &[_]u8{
        0x1f, 0x8b, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x03, 0x03, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00,
    }, error.EndOfStream);

    try testDecompress(.gzip, &[_]u8{
        // GZIP header
        0x1f, 0x8b, 0x08, 0x12, 0x00, 0x09, 0x6e, 0x88, 0x00, 0xff, 0x48, 0x65, 0x6c, 0x6c, 0x6f, 0x00,
        // header.FHCRC (should cover entire header)
        0x99, 0xd6,
        // GZIP data
        0x01, 0x00, 0x00, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    }, "");
}

test "zlib should not overshoot" {
    // Compressed zlib data with extra 4 bytes at the end.
    const data = [_]u8{
        0x78, 0x9c, 0x73, 0xce, 0x2f, 0xa8, 0x2c, 0xca, 0x4c, 0xcf, 0x28, 0x51, 0x08, 0xcf, 0xcc, 0xc9,
        0x49, 0xcd, 0x55, 0x28, 0x4b, 0xcc, 0x53, 0x08, 0x4e, 0xce, 0x48, 0xcc, 0xcc, 0xd6, 0x51, 0x08,
        0xce, 0xcc, 0x4b, 0x4f, 0x2c, 0xc8, 0x2f, 0x4a, 0x55, 0x30, 0xb4, 0xb4, 0x34, 0xd5, 0xb5, 0x34,
        0x03, 0x00, 0x8b, 0x61, 0x0f, 0xa4, 0x52, 0x5a, 0x94, 0x12,
    };

    var reader: std.Io.Reader = .fixed(&data);

    var decompress_buffer: [flate.max_window_len]u8 = undefined;
    var decompress: Decompress = .init(&reader, .zlib, &decompress_buffer);
    var out: [128]u8 = undefined;

    {
        const n = try decompress.reader.readSliceShort(&out);
        try std.testing.expectEqual(46, n);
        try std.testing.expectEqualStrings("Copyright Willem van Schaik, Singapore 1995-96", out[0..n]);
    }

    // 4 bytes after compressed chunk are available in reader.
    const n = try reader.readSliceShort(&out);
    try std.testing.expectEqual(n, 4);
    try std.testing.expectEqualSlices(u8, data[data.len - 4 .. data.len], out[0..n]);
}

fn testFailure(container: Container, in: []const u8, expected_err: anyerror) !void {
    var reader: Reader = .fixed(in);
    var aw: Writer.Allocating = .init(testing.allocator);
    try aw.ensureUnusedCapacity(flate.history_len);
    defer aw.deinit();

    var decompress: Decompress = .init(&reader, container, &.{});
    try testing.expectError(error.ReadFailed, decompress.reader.streamRemaining(&aw.writer));
    try testing.expectEqual(expected_err, decompress.err orelse return error.TestFailed);
}

fn testDecompress(container: Container, compressed: []const u8, expected_plain: []const u8) !void {
    var in: std.Io.Reader = .fixed(compressed);
    var aw: std.Io.Writer.Allocating = .init(testing.allocator);
    try aw.ensureUnusedCapacity(flate.history_len);
    defer aw.deinit();

    var decompress: Decompress = .init(&in, container, &.{});
    const decompressed_len = try decompress.reader.streamRemaining(&aw.writer);
    try testing.expectEqual(expected_plain.len, decompressed_len);
    try testing.expectEqualSlices(u8, expected_plain, aw.getWritten());
}
