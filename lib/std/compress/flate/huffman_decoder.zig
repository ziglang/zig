const std = @import("std");
const testing = std.testing;

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

pub const Error = error{
    InvalidCode,
    OversubscribedHuffmanTree,
    IncompleteHuffmanTree,
    MissingEndOfBlockCode,
};

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
    const LiteralEncoder = @import("huffman_encoder.zig").LiteralEncoder;

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
