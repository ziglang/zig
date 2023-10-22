const std = @import("std");
const builtin = @import("builtin");
const io = std.io;

const Allocator = std.mem.Allocator;

const deflate_const = @import("deflate_const.zig");
const hm_code = @import("huffman_code.zig");
const token = @import("token.zig");

// The first length code.
const length_codes_start = 257;

// The number of codegen codes.
const codegen_code_count = 19;
const bad_code = 255;

// buffer_flush_size indicates the buffer size
// after which bytes are flushed to the writer.
// Should preferably be a multiple of 6, since
// we accumulate 6 bytes between writes to the buffer.
const buffer_flush_size = 240;

// buffer_size is the actual output byte buffer size.
// It must have additional headroom for a flush
// which can contain up to 8 bytes.
const buffer_size = buffer_flush_size + 8;

// The number of extra bits needed by length code X - LENGTH_CODES_START.
var length_extra_bits = [_]u8{
    0, 0, 0, // 257
    0, 0, 0, 0, 0, 1, 1, 1, 1, 2, // 260
    2, 2, 2, 3, 3, 3, 3, 4, 4, 4, // 270
    4, 5, 5, 5, 5, 0, // 280
};

// The length indicated by length code X - LENGTH_CODES_START.
var length_base = [_]u32{
    0,  1,  2,  3,   4,   5,   6,   7,   8,   10,
    12, 14, 16, 20,  24,  28,  32,  40,  48,  56,
    64, 80, 96, 112, 128, 160, 192, 224, 255,
};

// offset code word extra bits.
var offset_extra_bits = [_]i8{
    0, 0, 0,  0,  1,  1,  2,  2,  3,  3,
    4, 4, 5,  5,  6,  6,  7,  7,  8,  8,
    9, 9, 10, 10, 11, 11, 12, 12, 13, 13,
};

var offset_base = [_]u32{
    0x000000, 0x000001, 0x000002, 0x000003, 0x000004,
    0x000006, 0x000008, 0x00000c, 0x000010, 0x000018,
    0x000020, 0x000030, 0x000040, 0x000060, 0x000080,
    0x0000c0, 0x000100, 0x000180, 0x000200, 0x000300,
    0x000400, 0x000600, 0x000800, 0x000c00, 0x001000,
    0x001800, 0x002000, 0x003000, 0x004000, 0x006000,
};

// The odd order in which the codegen code sizes are written.
var codegen_order = [_]u32{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

pub fn HuffmanBitWriter(comptime WriterType: type) type {
    return struct {
        const Self = @This();
        pub const Error = WriterType.Error;

        // writer is the underlying writer.
        // Do not use it directly; use the write method, which ensures
        // that Write errors are sticky.
        inner_writer: WriterType,
        bytes_written: usize,

        // Data waiting to be written is bytes[0 .. nbytes]
        // and then the low nbits of bits.  Data is always written
        // sequentially into the bytes array.
        bits: u64,
        nbits: u32, // number of bits
        bytes: [buffer_size]u8,
        codegen_freq: [codegen_code_count]u16,
        nbytes: u32, // number of bytes
        literal_freq: []u16,
        offset_freq: []u16,
        codegen: []u8,
        literal_encoding: hm_code.HuffmanEncoder,
        offset_encoding: hm_code.HuffmanEncoder,
        codegen_encoding: hm_code.HuffmanEncoder,
        err: bool = false,
        fixed_literal_encoding: hm_code.HuffmanEncoder,
        fixed_offset_encoding: hm_code.HuffmanEncoder,
        allocator: Allocator,
        huff_offset: hm_code.HuffmanEncoder,

        pub fn reset(self: *Self, new_writer: WriterType) void {
            self.inner_writer = new_writer;
            self.bytes_written = 0;
            self.bits = 0;
            self.nbits = 0;
            self.nbytes = 0;
            self.err = false;
        }

        pub fn flush(self: *Self) Error!void {
            if (self.err) {
                self.nbits = 0;
                return;
            }
            var n = self.nbytes;
            while (self.nbits != 0) {
                self.bytes[n] = @as(u8, @truncate(self.bits));
                self.bits >>= 8;
                if (self.nbits > 8) { // Avoid underflow
                    self.nbits -= 8;
                } else {
                    self.nbits = 0;
                }
                n += 1;
            }
            self.bits = 0;
            try self.write(self.bytes[0..n]);
            self.nbytes = 0;
        }

        fn write(self: *Self, b: []const u8) Error!void {
            if (self.err) {
                return;
            }
            self.bytes_written += try self.inner_writer.write(b);
        }

        fn writeBits(self: *Self, b: u32, nb: u32) Error!void {
            if (self.err) {
                return;
            }
            self.bits |= @as(u64, @intCast(b)) << @as(u6, @intCast(self.nbits));
            self.nbits += nb;
            if (self.nbits >= 48) {
                var bits = self.bits;
                self.bits >>= 48;
                self.nbits -= 48;
                var n = self.nbytes;
                var bytes = self.bytes[n..][0..6];
                bytes[0] = @as(u8, @truncate(bits));
                bytes[1] = @as(u8, @truncate(bits >> 8));
                bytes[2] = @as(u8, @truncate(bits >> 16));
                bytes[3] = @as(u8, @truncate(bits >> 24));
                bytes[4] = @as(u8, @truncate(bits >> 32));
                bytes[5] = @as(u8, @truncate(bits >> 40));
                n += 6;
                if (n >= buffer_flush_size) {
                    try self.write(self.bytes[0..n]);
                    n = 0;
                }
                self.nbytes = n;
            }
        }

        pub fn writeBytes(self: *Self, bytes: []const u8) Error!void {
            if (self.err) {
                return;
            }
            var n = self.nbytes;
            if (self.nbits & 7 != 0) {
                self.err = true; // unfinished bits
                return;
            }
            while (self.nbits != 0) {
                self.bytes[n] = @as(u8, @truncate(self.bits));
                self.bits >>= 8;
                self.nbits -= 8;
                n += 1;
            }
            if (n != 0) {
                try self.write(self.bytes[0..n]);
            }
            self.nbytes = 0;
            try self.write(bytes);
        }

        // RFC 1951 3.2.7 specifies a special run-length encoding for specifying
        // the literal and offset lengths arrays (which are concatenated into a single
        // array).  This method generates that run-length encoding.
        //
        // The result is written into the codegen array, and the frequencies
        // of each code is written into the codegen_freq array.
        // Codes 0-15 are single byte codes. Codes 16-18 are followed by additional
        // information. Code bad_code is an end marker
        //
        // num_literals: The number of literals in literal_encoding
        // num_offsets: The number of offsets in offset_encoding
        // lit_enc: The literal encoder to use
        // off_enc: The offset encoder to use
        fn generateCodegen(
            self: *Self,
            num_literals: u32,
            num_offsets: u32,
            lit_enc: *hm_code.HuffmanEncoder,
            off_enc: *hm_code.HuffmanEncoder,
        ) void {
            for (self.codegen_freq, 0..) |_, i| {
                self.codegen_freq[i] = 0;
            }

            // Note that we are using codegen both as a temporary variable for holding
            // a copy of the frequencies, and as the place where we put the result.
            // This is fine because the output is always shorter than the input used
            // so far.
            var codegen = self.codegen; // cache
            // Copy the concatenated code sizes to codegen. Put a marker at the end.
            var cgnl = codegen[0..num_literals];
            for (cgnl, 0..) |_, i| {
                cgnl[i] = @as(u8, @intCast(lit_enc.codes[i].len));
            }

            cgnl = codegen[num_literals .. num_literals + num_offsets];
            for (cgnl, 0..) |_, i| {
                cgnl[i] = @as(u8, @intCast(off_enc.codes[i].len));
            }
            codegen[num_literals + num_offsets] = bad_code;

            var size = codegen[0];
            var count: i32 = 1;
            var out_index: u32 = 0;
            var in_index: u32 = 1;
            while (size != bad_code) : (in_index += 1) {
                // INVARIANT: We have seen "count" copies of size that have not yet
                // had output generated for them.
                var next_size = codegen[in_index];
                if (next_size == size) {
                    count += 1;
                    continue;
                }
                // We need to generate codegen indicating "count" of size.
                if (size != 0) {
                    codegen[out_index] = size;
                    out_index += 1;
                    self.codegen_freq[size] += 1;
                    count -= 1;
                    while (count >= 3) {
                        var n: i32 = 6;
                        if (n > count) {
                            n = count;
                        }
                        codegen[out_index] = 16;
                        out_index += 1;
                        codegen[out_index] = @as(u8, @intCast(n - 3));
                        out_index += 1;
                        self.codegen_freq[16] += 1;
                        count -= n;
                    }
                } else {
                    while (count >= 11) {
                        var n: i32 = 138;
                        if (n > count) {
                            n = count;
                        }
                        codegen[out_index] = 18;
                        out_index += 1;
                        codegen[out_index] = @as(u8, @intCast(n - 11));
                        out_index += 1;
                        self.codegen_freq[18] += 1;
                        count -= n;
                    }
                    if (count >= 3) {
                        // 3 <= count <= 10
                        codegen[out_index] = 17;
                        out_index += 1;
                        codegen[out_index] = @as(u8, @intCast(count - 3));
                        out_index += 1;
                        self.codegen_freq[17] += 1;
                        count = 0;
                    }
                }
                count -= 1;
                while (count >= 0) : (count -= 1) {
                    codegen[out_index] = size;
                    out_index += 1;
                    self.codegen_freq[size] += 1;
                }
                // Set up invariant for next time through the loop.
                size = next_size;
                count = 1;
            }
            // Marker indicating the end of the codegen.
            codegen[out_index] = bad_code;
        }

        // dynamicSize returns the size of dynamically encoded data in bits.
        fn dynamicSize(
            self: *Self,
            lit_enc: *hm_code.HuffmanEncoder, // literal encoder
            off_enc: *hm_code.HuffmanEncoder, // offset encoder
            extra_bits: u32,
        ) DynamicSize {
            var num_codegens = self.codegen_freq.len;
            while (num_codegens > 4 and self.codegen_freq[codegen_order[num_codegens - 1]] == 0) {
                num_codegens -= 1;
            }
            var header = 3 + 5 + 5 + 4 + (3 * num_codegens) +
                self.codegen_encoding.bitLength(self.codegen_freq[0..]) +
                self.codegen_freq[16] * 2 +
                self.codegen_freq[17] * 3 +
                self.codegen_freq[18] * 7;
            var size = header +
                lit_enc.bitLength(self.literal_freq) +
                off_enc.bitLength(self.offset_freq) +
                extra_bits;

            return DynamicSize{
                .size = @as(u32, @intCast(size)),
                .num_codegens = @as(u32, @intCast(num_codegens)),
            };
        }

        // fixedSize returns the size of dynamically encoded data in bits.
        fn fixedSize(self: *Self, extra_bits: u32) u32 {
            return 3 +
                self.fixed_literal_encoding.bitLength(self.literal_freq) +
                self.fixed_offset_encoding.bitLength(self.offset_freq) +
                extra_bits;
        }

        // storedSizeFits calculates the stored size, including header.
        // The function returns the size in bits and whether the block
        // fits inside a single block.
        fn storedSizeFits(in: ?[]const u8) StoredSize {
            if (in == null) {
                return .{ .size = 0, .storable = false };
            }
            if (in.?.len <= deflate_const.max_store_block_size) {
                return .{ .size = @as(u32, @intCast((in.?.len + 5) * 8)), .storable = true };
            }
            return .{ .size = 0, .storable = false };
        }

        fn writeCode(self: *Self, c: hm_code.HuffCode) Error!void {
            if (self.err) {
                return;
            }
            self.bits |= @as(u64, @intCast(c.code)) << @as(u6, @intCast(self.nbits));
            self.nbits += @as(u32, @intCast(c.len));
            if (self.nbits >= 48) {
                var bits = self.bits;
                self.bits >>= 48;
                self.nbits -= 48;
                var n = self.nbytes;
                var bytes = self.bytes[n..][0..6];
                bytes[0] = @as(u8, @truncate(bits));
                bytes[1] = @as(u8, @truncate(bits >> 8));
                bytes[2] = @as(u8, @truncate(bits >> 16));
                bytes[3] = @as(u8, @truncate(bits >> 24));
                bytes[4] = @as(u8, @truncate(bits >> 32));
                bytes[5] = @as(u8, @truncate(bits >> 40));
                n += 6;
                if (n >= buffer_flush_size) {
                    try self.write(self.bytes[0..n]);
                    n = 0;
                }
                self.nbytes = n;
            }
        }

        // Write the header of a dynamic Huffman block to the output stream.
        //
        //  num_literals: The number of literals specified in codegen
        //  num_offsets: The number of offsets specified in codegen
        //  num_codegens: The number of codegens used in codegen
        //  is_eof: Is it the end-of-file? (end of stream)
        fn writeDynamicHeader(
            self: *Self,
            num_literals: u32,
            num_offsets: u32,
            num_codegens: u32,
            is_eof: bool,
        ) Error!void {
            if (self.err) {
                return;
            }
            var first_bits: u32 = 4;
            if (is_eof) {
                first_bits = 5;
            }
            try self.writeBits(first_bits, 3);
            try self.writeBits(@as(u32, @intCast(num_literals - 257)), 5);
            try self.writeBits(@as(u32, @intCast(num_offsets - 1)), 5);
            try self.writeBits(@as(u32, @intCast(num_codegens - 4)), 4);

            var i: u32 = 0;
            while (i < num_codegens) : (i += 1) {
                var value = @as(u32, @intCast(self.codegen_encoding.codes[codegen_order[i]].len));
                try self.writeBits(@as(u32, @intCast(value)), 3);
            }

            i = 0;
            while (true) {
                var code_word: u32 = @as(u32, @intCast(self.codegen[i]));
                i += 1;
                if (code_word == bad_code) {
                    break;
                }
                try self.writeCode(self.codegen_encoding.codes[@as(u32, @intCast(code_word))]);

                switch (code_word) {
                    16 => {
                        try self.writeBits(@as(u32, @intCast(self.codegen[i])), 2);
                        i += 1;
                    },
                    17 => {
                        try self.writeBits(@as(u32, @intCast(self.codegen[i])), 3);
                        i += 1;
                    },
                    18 => {
                        try self.writeBits(@as(u32, @intCast(self.codegen[i])), 7);
                        i += 1;
                    },
                    else => {},
                }
            }
        }

        pub fn writeStoredHeader(self: *Self, length: usize, is_eof: bool) Error!void {
            if (self.err) {
                return;
            }
            var flag: u32 = 0;
            if (is_eof) {
                flag = 1;
            }
            try self.writeBits(flag, 3);
            try self.flush();
            try self.writeBits(@as(u32, @intCast(length)), 16);
            try self.writeBits(@as(u32, @intCast(~@as(u16, @intCast(length)))), 16);
        }

        fn writeFixedHeader(self: *Self, is_eof: bool) Error!void {
            if (self.err) {
                return;
            }
            // Indicate that we are a fixed Huffman block
            var value: u32 = 2;
            if (is_eof) {
                value = 3;
            }
            try self.writeBits(value, 3);
        }

        // Write a block of tokens with the smallest encoding.
        // The original input can be supplied, and if the huffman encoded data
        // is larger than the original bytes, the data will be written as a
        // stored block.
        // If the input is null, the tokens will always be Huffman encoded.
        pub fn writeBlock(
            self: *Self,
            tokens: []const token.Token,
            eof: bool,
            input: ?[]const u8,
        ) Error!void {
            if (self.err) {
                return;
            }

            var lit_and_off = self.indexTokens(tokens);
            var num_literals = lit_and_off.num_literals;
            var num_offsets = lit_and_off.num_offsets;

            var extra_bits: u32 = 0;
            var ret = storedSizeFits(input);
            var stored_size = ret.size;
            var storable = ret.storable;

            if (storable) {
                // We only bother calculating the costs of the extra bits required by
                // the length of offset fields (which will be the same for both fixed
                // and dynamic encoding), if we need to compare those two encodings
                // against stored encoding.
                var length_code: u32 = length_codes_start + 8;
                while (length_code < num_literals) : (length_code += 1) {
                    // First eight length codes have extra size = 0.
                    extra_bits += @as(u32, @intCast(self.literal_freq[length_code])) *
                        @as(u32, @intCast(length_extra_bits[length_code - length_codes_start]));
                }
                var offset_code: u32 = 4;
                while (offset_code < num_offsets) : (offset_code += 1) {
                    // First four offset codes have extra size = 0.
                    extra_bits += @as(u32, @intCast(self.offset_freq[offset_code])) *
                        @as(u32, @intCast(offset_extra_bits[offset_code]));
                }
            }

            // Figure out smallest code.
            // Fixed Huffman baseline.
            var literal_encoding = &self.fixed_literal_encoding;
            var offset_encoding = &self.fixed_offset_encoding;
            var size = self.fixedSize(extra_bits);

            // Dynamic Huffman?
            var num_codegens: u32 = 0;

            // Generate codegen and codegenFrequencies, which indicates how to encode
            // the literal_encoding and the offset_encoding.
            self.generateCodegen(
                num_literals,
                num_offsets,
                &self.literal_encoding,
                &self.offset_encoding,
            );
            self.codegen_encoding.generate(self.codegen_freq[0..], 7);
            var dynamic_size = self.dynamicSize(
                &self.literal_encoding,
                &self.offset_encoding,
                extra_bits,
            );
            var dyn_size = dynamic_size.size;
            num_codegens = dynamic_size.num_codegens;

            if (dyn_size < size) {
                size = dyn_size;
                literal_encoding = &self.literal_encoding;
                offset_encoding = &self.offset_encoding;
            }

            // Stored bytes?
            if (storable and stored_size < size) {
                try self.writeStoredHeader(input.?.len, eof);
                try self.writeBytes(input.?);
                return;
            }

            // Huffman.
            if (@intFromPtr(literal_encoding) == @intFromPtr(&self.fixed_literal_encoding)) {
                try self.writeFixedHeader(eof);
            } else {
                try self.writeDynamicHeader(num_literals, num_offsets, num_codegens, eof);
            }

            // Write the tokens.
            try self.writeTokens(tokens, literal_encoding.codes, offset_encoding.codes);
        }

        // writeBlockDynamic encodes a block using a dynamic Huffman table.
        // This should be used if the symbols used have a disproportionate
        // histogram distribution.
        // If input is supplied and the compression savings are below 1/16th of the
        // input size the block is stored.
        pub fn writeBlockDynamic(
            self: *Self,
            tokens: []const token.Token,
            eof: bool,
            input: ?[]const u8,
        ) Error!void {
            if (self.err) {
                return;
            }

            var total_tokens = self.indexTokens(tokens);
            var num_literals = total_tokens.num_literals;
            var num_offsets = total_tokens.num_offsets;

            // Generate codegen and codegenFrequencies, which indicates how to encode
            // the literal_encoding and the offset_encoding.
            self.generateCodegen(
                num_literals,
                num_offsets,
                &self.literal_encoding,
                &self.offset_encoding,
            );
            self.codegen_encoding.generate(self.codegen_freq[0..], 7);
            var dynamic_size = self.dynamicSize(&self.literal_encoding, &self.offset_encoding, 0);
            var size = dynamic_size.size;
            var num_codegens = dynamic_size.num_codegens;

            // Store bytes, if we don't get a reasonable improvement.

            var stored_size = storedSizeFits(input);
            var ssize = stored_size.size;
            var storable = stored_size.storable;
            if (storable and ssize < (size + (size >> 4))) {
                try self.writeStoredHeader(input.?.len, eof);
                try self.writeBytes(input.?);
                return;
            }

            // Write Huffman table.
            try self.writeDynamicHeader(num_literals, num_offsets, num_codegens, eof);

            // Write the tokens.
            try self.writeTokens(tokens, self.literal_encoding.codes, self.offset_encoding.codes);
        }

        const TotalIndexedTokens = struct {
            num_literals: u32,
            num_offsets: u32,
        };

        // Indexes a slice of tokens followed by an end_block_marker, and updates
        // literal_freq and offset_freq, and generates literal_encoding
        // and offset_encoding.
        // The number of literal and offset tokens is returned.
        fn indexTokens(self: *Self, tokens: []const token.Token) TotalIndexedTokens {
            var num_literals: u32 = 0;
            var num_offsets: u32 = 0;

            for (self.literal_freq, 0..) |_, i| {
                self.literal_freq[i] = 0;
            }
            for (self.offset_freq, 0..) |_, i| {
                self.offset_freq[i] = 0;
            }

            for (tokens) |t| {
                if (t < token.match_type) {
                    self.literal_freq[token.literal(t)] += 1;
                    continue;
                }
                var length = token.length(t);
                var offset = token.offset(t);
                self.literal_freq[length_codes_start + token.lengthCode(length)] += 1;
                self.offset_freq[token.offsetCode(offset)] += 1;
            }
            // add end_block_marker token at the end
            self.literal_freq[token.literal(deflate_const.end_block_marker)] += 1;

            // get the number of literals
            num_literals = @as(u32, @intCast(self.literal_freq.len));
            while (self.literal_freq[num_literals - 1] == 0) {
                num_literals -= 1;
            }
            // get the number of offsets
            num_offsets = @as(u32, @intCast(self.offset_freq.len));
            while (num_offsets > 0 and self.offset_freq[num_offsets - 1] == 0) {
                num_offsets -= 1;
            }
            if (num_offsets == 0) {
                // We haven't found a single match. If we want to go with the dynamic encoding,
                // we should count at least one offset to be sure that the offset huffman tree could be encoded.
                self.offset_freq[0] = 1;
                num_offsets = 1;
            }
            self.literal_encoding.generate(self.literal_freq, 15);
            self.offset_encoding.generate(self.offset_freq, 15);
            return TotalIndexedTokens{
                .num_literals = num_literals,
                .num_offsets = num_offsets,
            };
        }

        // Writes a slice of tokens to the output followed by and end_block_marker.
        // codes for literal and offset encoding must be supplied.
        fn writeTokens(
            self: *Self,
            tokens: []const token.Token,
            le_codes: []hm_code.HuffCode,
            oe_codes: []hm_code.HuffCode,
        ) Error!void {
            if (self.err) {
                return;
            }
            for (tokens) |t| {
                if (t < token.match_type) {
                    try self.writeCode(le_codes[token.literal(t)]);
                    continue;
                }
                // Write the length
                var length = token.length(t);
                var length_code = token.lengthCode(length);
                try self.writeCode(le_codes[length_code + length_codes_start]);
                var extra_length_bits = @as(u32, @intCast(length_extra_bits[length_code]));
                if (extra_length_bits > 0) {
                    var extra_length = @as(u32, @intCast(length - length_base[length_code]));
                    try self.writeBits(extra_length, extra_length_bits);
                }
                // Write the offset
                var offset = token.offset(t);
                var offset_code = token.offsetCode(offset);
                try self.writeCode(oe_codes[offset_code]);
                var extra_offset_bits = @as(u32, @intCast(offset_extra_bits[offset_code]));
                if (extra_offset_bits > 0) {
                    var extra_offset = @as(u32, @intCast(offset - offset_base[offset_code]));
                    try self.writeBits(extra_offset, extra_offset_bits);
                }
            }
            // add end_block_marker at the end
            try self.writeCode(le_codes[token.literal(deflate_const.end_block_marker)]);
        }

        // Encodes a block of bytes as either Huffman encoded literals or uncompressed bytes
        // if the results only gains very little from compression.
        pub fn writeBlockHuff(self: *Self, eof: bool, input: []const u8) Error!void {
            if (self.err) {
                return;
            }

            // Clear histogram
            for (self.literal_freq, 0..) |_, i| {
                self.literal_freq[i] = 0;
            }

            // Add everything as literals
            histogram(input, &self.literal_freq);

            self.literal_freq[deflate_const.end_block_marker] = 1;

            const num_literals = deflate_const.end_block_marker + 1;
            self.offset_freq[0] = 1;
            const num_offsets = 1;

            self.literal_encoding.generate(self.literal_freq, 15);

            // Figure out smallest code.
            // Always use dynamic Huffman or Store
            var num_codegens: u32 = 0;

            // Generate codegen and codegenFrequencies, which indicates how to encode
            // the literal_encoding and the offset_encoding.
            self.generateCodegen(
                num_literals,
                num_offsets,
                &self.literal_encoding,
                &self.huff_offset,
            );
            self.codegen_encoding.generate(self.codegen_freq[0..], 7);
            var dynamic_size = self.dynamicSize(&self.literal_encoding, &self.huff_offset, 0);
            var size = dynamic_size.size;
            num_codegens = dynamic_size.num_codegens;

            // Store bytes, if we don't get a reasonable improvement.

            var stored_size_ret = storedSizeFits(input);
            var ssize = stored_size_ret.size;
            var storable = stored_size_ret.storable;

            if (storable and ssize < (size + (size >> 4))) {
                try self.writeStoredHeader(input.len, eof);
                try self.writeBytes(input);
                return;
            }

            // Huffman.
            try self.writeDynamicHeader(num_literals, num_offsets, num_codegens, eof);
            var encoding = self.literal_encoding.codes[0..257];
            var n = self.nbytes;
            for (input) |t| {
                // Bitwriting inlined, ~30% speedup
                var c = encoding[t];
                self.bits |= @as(u64, @intCast(c.code)) << @as(u6, @intCast(self.nbits));
                self.nbits += @as(u32, @intCast(c.len));
                if (self.nbits < 48) {
                    continue;
                }
                // Store 6 bytes
                var bits = self.bits;
                self.bits >>= 48;
                self.nbits -= 48;
                var bytes = self.bytes[n..][0..6];
                bytes[0] = @as(u8, @truncate(bits));
                bytes[1] = @as(u8, @truncate(bits >> 8));
                bytes[2] = @as(u8, @truncate(bits >> 16));
                bytes[3] = @as(u8, @truncate(bits >> 24));
                bytes[4] = @as(u8, @truncate(bits >> 32));
                bytes[5] = @as(u8, @truncate(bits >> 40));
                n += 6;
                if (n < buffer_flush_size) {
                    continue;
                }
                try self.write(self.bytes[0..n]);
                if (self.err) {
                    return; // Return early in the event of write failures
                }
                n = 0;
            }
            self.nbytes = n;
            try self.writeCode(encoding[deflate_const.end_block_marker]);
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.literal_freq);
            self.allocator.free(self.offset_freq);
            self.allocator.free(self.codegen);
            self.literal_encoding.deinit();
            self.codegen_encoding.deinit();
            self.offset_encoding.deinit();
            self.fixed_literal_encoding.deinit();
            self.fixed_offset_encoding.deinit();
            self.huff_offset.deinit();
        }
    };
}

const DynamicSize = struct {
    size: u32,
    num_codegens: u32,
};

const StoredSize = struct {
    size: u32,
    storable: bool,
};

pub fn huffmanBitWriter(allocator: Allocator, writer: anytype) !HuffmanBitWriter(@TypeOf(writer)) {
    var offset_freq = [1]u16{0} ** deflate_const.offset_code_count;
    offset_freq[0] = 1;
    // huff_offset is a static offset encoder used for huffman only encoding.
    // It can be reused since we will not be encoding offset values.
    var huff_offset = try hm_code.newHuffmanEncoder(allocator, deflate_const.offset_code_count);
    huff_offset.generate(offset_freq[0..], 15);

    return HuffmanBitWriter(@TypeOf(writer)){
        .inner_writer = writer,
        .bytes_written = 0,
        .bits = 0,
        .nbits = 0,
        .nbytes = 0,
        .bytes = [1]u8{0} ** buffer_size,
        .codegen_freq = [1]u16{0} ** codegen_code_count,
        .literal_freq = try allocator.alloc(u16, deflate_const.max_num_lit),
        .offset_freq = try allocator.alloc(u16, deflate_const.offset_code_count),
        .codegen = try allocator.alloc(u8, deflate_const.max_num_lit + deflate_const.offset_code_count + 1),
        .literal_encoding = try hm_code.newHuffmanEncoder(allocator, deflate_const.max_num_lit),
        .codegen_encoding = try hm_code.newHuffmanEncoder(allocator, codegen_code_count),
        .offset_encoding = try hm_code.newHuffmanEncoder(allocator, deflate_const.offset_code_count),
        .allocator = allocator,
        .fixed_literal_encoding = try hm_code.generateFixedLiteralEncoding(allocator),
        .fixed_offset_encoding = try hm_code.generateFixedOffsetEncoding(allocator),
        .huff_offset = huff_offset,
    };
}

// histogram accumulates a histogram of b in h.
//
// h.len must be >= 256, and h's elements must be all zeroes.
fn histogram(b: []const u8, h: *[]u16) void {
    var lh = h.*[0..256];
    for (b) |t| {
        lh[t] += 1;
    }
}

// tests
const expect = std.testing.expect;
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;
const testing = std.testing;

const ArrayList = std.ArrayList;

test "writeBlockHuff" {
    // Tests huffman encoding against reference files to detect possible regressions.
    // If encoding/bit allocation changes you can regenerate these files

    try testBlockHuff(
        "huffman-null-max.input",
        "huffman-null-max.golden",
    );
    try testBlockHuff(
        "huffman-pi.input",
        "huffman-pi.golden",
    );
    try testBlockHuff(
        "huffman-rand-1k.input",
        "huffman-rand-1k.golden",
    );
    try testBlockHuff(
        "huffman-rand-limit.input",
        "huffman-rand-limit.golden",
    );
    try testBlockHuff(
        "huffman-rand-max.input",
        "huffman-rand-max.golden",
    );
    try testBlockHuff(
        "huffman-shifts.input",
        "huffman-shifts.golden",
    );
    try testBlockHuff(
        "huffman-text.input",
        "huffman-text.golden",
    );
    try testBlockHuff(
        "huffman-text-shift.input",
        "huffman-text-shift.golden",
    );
    try testBlockHuff(
        "huffman-zero.input",
        "huffman-zero.golden",
    );
}

fn testBlockHuff(comptime in_name: []const u8, comptime want_name: []const u8) !void {
    const in: []const u8 = @embedFile("testdata/" ++ in_name);
    const want: []const u8 = @embedFile("testdata/" ++ want_name);

    var buf = ArrayList(u8).init(testing.allocator);
    defer buf.deinit();
    var bw = try huffmanBitWriter(testing.allocator, buf.writer());
    defer bw.deinit();
    try bw.writeBlockHuff(false, in);
    try bw.flush();

    try std.testing.expectEqualSlices(u8, want, buf.items);

    // Test if the writer produces the same output after reset.
    var buf_after_reset = ArrayList(u8).init(testing.allocator);
    defer buf_after_reset.deinit();

    bw.reset(buf_after_reset.writer());

    try bw.writeBlockHuff(false, in);
    try bw.flush();

    try std.testing.expectEqualSlices(u8, buf.items, buf_after_reset.items);
    try std.testing.expectEqualSlices(u8, want, buf_after_reset.items);

    try testWriterEOF(.write_huffman_block, &[0]token.Token{}, in);
}

const HuffTest = struct {
    tokens: []const token.Token,
    input: []const u8 = "", // File name of input data matching the tokens.
    want: []const u8 = "", // File name of data with the expected output with input available.
    want_no_input: []const u8 = "", // File name of the expected output when no input is available.
};

const ml = 0x7fc00000; // Maximum length token. Used to reduce the size of writeBlockTests

const writeBlockTests = &[_]HuffTest{
    HuffTest{
        .input = "huffman-null-max.input",
        .want = "huffman-null-max.{s}.expect",
        .want_no_input = "huffman-null-max.{s}.expect-noinput",
        .tokens = &[_]token.Token{
            0x0, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,  ml,  ml, ml, ml,
            ml,  ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, 0x0, 0x0,
        },
    },
    HuffTest{
        .input = "huffman-pi.input",
        .want = "huffman-pi.{s}.expect",
        .want_no_input = "huffman-pi.{s}.expect-noinput",
        .tokens = &[_]token.Token{
            0x33,       0x2e,       0x31,       0x34,       0x31,       0x35,       0x39,
            0x32,       0x36,       0x35,       0x33,       0x35,       0x38,       0x39,
            0x37,       0x39,       0x33,       0x32,       0x33,       0x38,       0x34,
            0x36,       0x32,       0x36,       0x34,       0x33,       0x33,       0x38,
            0x33,       0x32,       0x37,       0x39,       0x35,       0x30,       0x32,
            0x38,       0x38,       0x34,       0x31,       0x39,       0x37,       0x31,
            0x36,       0x39,       0x33,       0x39,       0x39,       0x33,       0x37,
            0x35,       0x31,       0x30,       0x35,       0x38,       0x32,       0x30,
            0x39,       0x37,       0x34,       0x39,       0x34,       0x34,       0x35,
            0x39,       0x32,       0x33,       0x30,       0x37,       0x38,       0x31,
            0x36,       0x34,       0x30,       0x36,       0x32,       0x38,       0x36,
            0x32,       0x30,       0x38,       0x39,       0x39,       0x38,       0x36,
            0x32,       0x38,       0x30,       0x33,       0x34,       0x38,       0x32,
            0x35,       0x33,       0x34,       0x32,       0x31,       0x31,       0x37,
            0x30,       0x36,       0x37,       0x39,       0x38,       0x32,       0x31,
            0x34,       0x38,       0x30,       0x38,       0x36,       0x35,       0x31,
            0x33,       0x32,       0x38,       0x32,       0x33,       0x30,       0x36,
            0x36,       0x34,       0x37,       0x30,       0x39,       0x33,       0x38,
            0x34,       0x34,       0x36,       0x30,       0x39,       0x35,       0x35,
            0x30,       0x35,       0x38,       0x32,       0x32,       0x33,       0x31,
            0x37,       0x32,       0x35,       0x33,       0x35,       0x39,       0x34,
            0x30,       0x38,       0x31,       0x32,       0x38,       0x34,       0x38,
            0x31,       0x31,       0x31,       0x37,       0x34,       0x4040007e, 0x34,
            0x31,       0x30,       0x32,       0x37,       0x30,       0x31,       0x39,
            0x33,       0x38,       0x35,       0x32,       0x31,       0x31,       0x30,
            0x35,       0x35,       0x35,       0x39,       0x36,       0x34,       0x34,
            0x36,       0x32,       0x32,       0x39,       0x34,       0x38,       0x39,
            0x35,       0x34,       0x39,       0x33,       0x30,       0x33,       0x38,
            0x31,       0x40400012, 0x32,       0x38,       0x38,       0x31,       0x30,
            0x39,       0x37,       0x35,       0x36,       0x36,       0x35,       0x39,
            0x33,       0x33,       0x34,       0x34,       0x36,       0x40400047, 0x37,
            0x35,       0x36,       0x34,       0x38,       0x32,       0x33,       0x33,
            0x37,       0x38,       0x36,       0x37,       0x38,       0x33,       0x31,
            0x36,       0x35,       0x32,       0x37,       0x31,       0x32,       0x30,
            0x31,       0x39,       0x30,       0x39,       0x31,       0x34,       0x4040001a,
            0x35,       0x36,       0x36,       0x39,       0x32,       0x33,       0x34,
            0x36,       0x404000b2, 0x36,       0x31,       0x30,       0x34,       0x35,
            0x34,       0x33,       0x32,       0x36,       0x40400032, 0x31,       0x33,
            0x33,       0x39,       0x33,       0x36,       0x30,       0x37,       0x32,
            0x36,       0x30,       0x32,       0x34,       0x39,       0x31,       0x34,
            0x31,       0x32,       0x37,       0x33,       0x37,       0x32,       0x34,
            0x35,       0x38,       0x37,       0x30,       0x30,       0x36,       0x36,
            0x30,       0x36,       0x33,       0x31,       0x35,       0x35,       0x38,
            0x38,       0x31,       0x37,       0x34,       0x38,       0x38,       0x31,
            0x35,       0x32,       0x30,       0x39,       0x32,       0x30,       0x39,
            0x36,       0x32,       0x38,       0x32,       0x39,       0x32,       0x35,
            0x34,       0x30,       0x39,       0x31,       0x37,       0x31,       0x35,
            0x33,       0x36,       0x34,       0x33,       0x36,       0x37,       0x38,
            0x39,       0x32,       0x35,       0x39,       0x30,       0x33,       0x36,
            0x30,       0x30,       0x31,       0x31,       0x33,       0x33,       0x30,
            0x35,       0x33,       0x30,       0x35,       0x34,       0x38,       0x38,
            0x32,       0x30,       0x34,       0x36,       0x36,       0x35,       0x32,
            0x31,       0x33,       0x38,       0x34,       0x31,       0x34,       0x36,
            0x39,       0x35,       0x31,       0x39,       0x34,       0x31,       0x35,
            0x31,       0x31,       0x36,       0x30,       0x39,       0x34,       0x33,
            0x33,       0x30,       0x35,       0x37,       0x32,       0x37,       0x30,
            0x33,       0x36,       0x35,       0x37,       0x35,       0x39,       0x35,
            0x39,       0x31,       0x39,       0x35,       0x33,       0x30,       0x39,
            0x32,       0x31,       0x38,       0x36,       0x31,       0x31,       0x37,
            0x404000e9, 0x33,       0x32,       0x40400009, 0x39,       0x33,       0x31,
            0x30,       0x35,       0x31,       0x31,       0x38,       0x35,       0x34,
            0x38,       0x30,       0x37,       0x4040010e, 0x33,       0x37,       0x39,
            0x39,       0x36,       0x32,       0x37,       0x34,       0x39,       0x35,
            0x36,       0x37,       0x33,       0x35,       0x31,       0x38,       0x38,
            0x35,       0x37,       0x35,       0x32,       0x37,       0x32,       0x34,
            0x38,       0x39,       0x31,       0x32,       0x32,       0x37,       0x39,
            0x33,       0x38,       0x31,       0x38,       0x33,       0x30,       0x31,
            0x31,       0x39,       0x34,       0x39,       0x31,       0x32,       0x39,
            0x38,       0x33,       0x33,       0x36,       0x37,       0x33,       0x33,
            0x36,       0x32,       0x34,       0x34,       0x30,       0x36,       0x35,
            0x36,       0x36,       0x34,       0x33,       0x30,       0x38,       0x36,
            0x30,       0x32,       0x31,       0x33,       0x39,       0x34,       0x39,
            0x34,       0x36,       0x33,       0x39,       0x35,       0x32,       0x32,
            0x34,       0x37,       0x33,       0x37,       0x31,       0x39,       0x30,
            0x37,       0x30,       0x32,       0x31,       0x37,       0x39,       0x38,
            0x40800099, 0x37,       0x30,       0x32,       0x37,       0x37,       0x30,
            0x35,       0x33,       0x39,       0x32,       0x31,       0x37,       0x31,
            0x37,       0x36,       0x32,       0x39,       0x33,       0x31,       0x37,
            0x36,       0x37,       0x35,       0x40800232, 0x37,       0x34,       0x38,
            0x31,       0x40400006, 0x36,       0x36,       0x39,       0x34,       0x30,
            0x404001e7, 0x30,       0x30,       0x30,       0x35,       0x36,       0x38,
            0x31,       0x32,       0x37,       0x31,       0x34,       0x35,       0x32,
            0x36,       0x33,       0x35,       0x36,       0x30,       0x38,       0x32,
            0x37,       0x37,       0x38,       0x35,       0x37,       0x37,       0x31,
            0x33,       0x34,       0x32,       0x37,       0x35,       0x37,       0x37,
            0x38,       0x39,       0x36,       0x40400129, 0x33,       0x36,       0x33,
            0x37,       0x31,       0x37,       0x38,       0x37,       0x32,       0x31,
            0x34,       0x36,       0x38,       0x34,       0x34,       0x30,       0x39,
            0x30,       0x31,       0x32,       0x32,       0x34,       0x39,       0x35,
            0x33,       0x34,       0x33,       0x30,       0x31,       0x34,       0x36,
            0x35,       0x34,       0x39,       0x35,       0x38,       0x35,       0x33,
            0x37,       0x31,       0x30,       0x35,       0x30,       0x37,       0x39,
            0x404000ca, 0x36,       0x40400153, 0x38,       0x39,       0x32,       0x33,
            0x35,       0x34,       0x404001c9, 0x39,       0x35,       0x36,       0x31,
            0x31,       0x32,       0x31,       0x32,       0x39,       0x30,       0x32,
            0x31,       0x39,       0x36,       0x30,       0x38,       0x36,       0x34,
            0x30,       0x33,       0x34,       0x34,       0x31,       0x38,       0x31,
            0x35,       0x39,       0x38,       0x31,       0x33,       0x36,       0x32,
            0x39,       0x37,       0x37,       0x34,       0x40400074, 0x30,       0x39,
            0x39,       0x36,       0x30,       0x35,       0x31,       0x38,       0x37,
            0x30,       0x37,       0x32,       0x31,       0x31,       0x33,       0x34,
            0x39,       0x40800000, 0x38,       0x33,       0x37,       0x32,       0x39,
            0x37,       0x38,       0x30,       0x34,       0x39,       0x39,       0x404002da,
            0x39,       0x37,       0x33,       0x31,       0x37,       0x33,       0x32,
            0x38,       0x4040018a, 0x36,       0x33,       0x31,       0x38,       0x35,
            0x40400301, 0x404002e8, 0x34,       0x35,       0x35,       0x33,       0x34,
            0x36,       0x39,       0x30,       0x38,       0x33,       0x30,       0x32,
            0x36,       0x34,       0x32,       0x35,       0x32,       0x32,       0x33,
            0x30,       0x404002e3, 0x40400267, 0x38,       0x35,       0x30,       0x33,
            0x35,       0x32,       0x36,       0x31,       0x39,       0x33,       0x31,
            0x31,       0x40400212, 0x31,       0x30,       0x31,       0x30,       0x30,
            0x30,       0x33,       0x31,       0x33,       0x37,       0x38,       0x33,
            0x38,       0x37,       0x35,       0x32,       0x38,       0x38,       0x36,
            0x35,       0x38,       0x37,       0x35,       0x33,       0x33,       0x32,
            0x30,       0x38,       0x33,       0x38,       0x31,       0x34,       0x32,
            0x30,       0x36,       0x40400140, 0x4040012b, 0x31,       0x34,       0x37,
            0x33,       0x30,       0x33,       0x35,       0x39,       0x4080032e, 0x39,
            0x30,       0x34,       0x32,       0x38,       0x37,       0x35,       0x35,
            0x34,       0x36,       0x38,       0x37,       0x33,       0x31,       0x31,
            0x35,       0x39,       0x35,       0x40400355, 0x33,       0x38,       0x38,
            0x32,       0x33,       0x35,       0x33,       0x37,       0x38,       0x37,
            0x35,       0x4080037f, 0x39,       0x4040013a, 0x31,       0x40400148, 0x38,
            0x30,       0x35,       0x33,       0x4040018a, 0x32,       0x32,       0x36,
            0x38,       0x30,       0x36,       0x36,       0x31,       0x33,       0x30,
            0x30,       0x31,       0x39,       0x32,       0x37,       0x38,       0x37,
            0x36,       0x36,       0x31,       0x31,       0x31,       0x39,       0x35,
            0x39,       0x40400237, 0x36,       0x40800124, 0x38,       0x39,       0x33,
            0x38,       0x30,       0x39,       0x35,       0x32,       0x35,       0x37,
            0x32,       0x30,       0x31,       0x30,       0x36,       0x35,       0x34,
            0x38,       0x35,       0x38,       0x36,       0x33,       0x32,       0x37,
            0x4040009a, 0x39,       0x33,       0x36,       0x31,       0x35,       0x33,
            0x40400220, 0x4080015c, 0x32,       0x33,       0x30,       0x33,       0x30,
            0x31,       0x39,       0x35,       0x32,       0x30,       0x33,       0x35,
            0x33,       0x30,       0x31,       0x38,       0x35,       0x32,       0x40400171,
            0x40400075, 0x33,       0x36,       0x32,       0x32,       0x35,       0x39,
            0x39,       0x34,       0x31,       0x33,       0x40400254, 0x34,       0x39,
            0x37,       0x32,       0x31,       0x37,       0x404000de, 0x33,       0x34,
            0x37,       0x39,       0x31,       0x33,       0x31,       0x35,       0x31,
            0x35,       0x35,       0x37,       0x34,       0x38,       0x35,       0x37,
            0x32,       0x34,       0x32,       0x34,       0x35,       0x34,       0x31,
            0x35,       0x30,       0x36,       0x39,       0x4040013f, 0x38,       0x32,
            0x39,       0x35,       0x33,       0x33,       0x31,       0x31,       0x36,
            0x38,       0x36,       0x31,       0x37,       0x32,       0x37,       0x38,
            0x40400337, 0x39,       0x30,       0x37,       0x35,       0x30,       0x39,
            0x4040010d, 0x37,       0x35,       0x34,       0x36,       0x33,       0x37,
            0x34,       0x36,       0x34,       0x39,       0x33,       0x39,       0x33,
            0x31,       0x39,       0x32,       0x35,       0x35,       0x30,       0x36,
            0x30,       0x34,       0x30,       0x30,       0x39,       0x4040026b, 0x31,
            0x36,       0x37,       0x31,       0x31,       0x33,       0x39,       0x30,
            0x30,       0x39,       0x38,       0x40400335, 0x34,       0x30,       0x31,
            0x32,       0x38,       0x35,       0x38,       0x33,       0x36,       0x31,
            0x36,       0x30,       0x33,       0x35,       0x36,       0x33,       0x37,
            0x30,       0x37,       0x36,       0x36,       0x30,       0x31,       0x30,
            0x34,       0x40400172, 0x38,       0x31,       0x39,       0x34,       0x32,
            0x39,       0x4080041e, 0x404000ef, 0x4040028b, 0x37,       0x38,       0x33,
            0x37,       0x34,       0x404004a8, 0x38,       0x32,       0x35,       0x35,
            0x33,       0x37,       0x40800209, 0x32,       0x36,       0x38,       0x4040002e,
            0x34,       0x30,       0x34,       0x37,       0x404001d1, 0x34,       0x404004b5,
            0x4040038d, 0x38,       0x34,       0x404003a8, 0x36,       0x40c0031f, 0x33,
            0x33,       0x31,       0x33,       0x36,       0x37,       0x37,       0x30,
            0x32,       0x38,       0x39,       0x38,       0x39,       0x31,       0x35,
            0x32,       0x40400062, 0x35,       0x32,       0x31,       0x36,       0x32,
            0x30,       0x35,       0x36,       0x39,       0x36,       0x40400411, 0x30,
            0x35,       0x38,       0x40400477, 0x35,       0x40400498, 0x35,       0x31,
            0x31,       0x40400209, 0x38,       0x32,       0x34,       0x33,       0x30,
            0x30,       0x33,       0x35,       0x35,       0x38,       0x37,       0x36,
            0x34,       0x30,       0x32,       0x34,       0x37,       0x34,       0x39,
            0x36,       0x34,       0x37,       0x33,       0x32,       0x36,       0x33,
            0x4040043e, 0x39,       0x39,       0x32,       0x4040044b, 0x34,       0x32,
            0x36,       0x39,       0x40c002c5, 0x37,       0x404001d6, 0x34,       0x4040053d,
            0x4040041d, 0x39,       0x33,       0x34,       0x31,       0x37,       0x404001ad,
            0x31,       0x32,       0x4040002a, 0x34,       0x4040019e, 0x31,       0x35,
            0x30,       0x33,       0x30,       0x32,       0x38,       0x36,       0x31,
            0x38,       0x32,       0x39,       0x37,       0x34,       0x35,       0x35,
            0x35,       0x37,       0x30,       0x36,       0x37,       0x34,       0x40400135,
            0x35,       0x30,       0x35,       0x34,       0x39,       0x34,       0x35,
            0x38,       0x404001c5, 0x39,       0x40400051, 0x35,       0x36,       0x404001ec,
            0x37,       0x32,       0x31,       0x30,       0x37,       0x39,       0x40400159,
            0x33,       0x30,       0x4040010a, 0x33,       0x32,       0x31,       0x31,
            0x36,       0x35,       0x33,       0x34,       0x34,       0x39,       0x38,
            0x37,       0x32,       0x30,       0x32,       0x37,       0x4040011b, 0x30,
            0x32,       0x33,       0x36,       0x34,       0x4040022e, 0x35,       0x34,
            0x39,       0x39,       0x31,       0x31,       0x39,       0x38,       0x40400418,
            0x34,       0x4040011b, 0x35,       0x33,       0x35,       0x36,       0x36,
            0x33,       0x36,       0x39,       0x40400450, 0x32,       0x36,       0x35,
            0x404002e4, 0x37,       0x38,       0x36,       0x32,       0x35,       0x35,
            0x31,       0x404003da, 0x31,       0x37,       0x35,       0x37,       0x34,
            0x36,       0x37,       0x32,       0x38,       0x39,       0x30,       0x39,
            0x37,       0x37,       0x37,       0x37,       0x40800453, 0x30,       0x30,
            0x30,       0x404005fd, 0x37,       0x30,       0x404004df, 0x36,       0x404003e9,
            0x34,       0x39,       0x31,       0x4040041e, 0x40400297, 0x32,       0x31,
            0x34,       0x37,       0x37,       0x32,       0x33,       0x35,       0x30,
            0x31,       0x34,       0x31,       0x34,       0x40400643, 0x33,       0x35,
            0x36,       0x404004af, 0x31,       0x36,       0x31,       0x33,       0x36,
            0x31,       0x31,       0x35,       0x37,       0x33,       0x35,       0x32,
            0x35,       0x40400504, 0x33,       0x34,       0x4040005b, 0x31,       0x38,
            0x4040047b, 0x38,       0x34,       0x404005e7, 0x33,       0x33,       0x32,
            0x33,       0x39,       0x30,       0x37,       0x33,       0x39,       0x34,
            0x31,       0x34,       0x33,       0x33,       0x33,       0x34,       0x35,
            0x34,       0x37,       0x37,       0x36,       0x32,       0x34,       0x40400242,
            0x32,       0x35,       0x31,       0x38,       0x39,       0x38,       0x33,
            0x35,       0x36,       0x39,       0x34,       0x38,       0x35,       0x35,
            0x36,       0x32,       0x30,       0x39,       0x39,       0x32,       0x31,
            0x39,       0x32,       0x32,       0x32,       0x31,       0x38,       0x34,
            0x32,       0x37,       0x4040023e, 0x32,       0x404000ba, 0x36,       0x38,
            0x38,       0x37,       0x36,       0x37,       0x31,       0x37,       0x39,
            0x30,       0x40400055, 0x30,       0x40800106, 0x36,       0x36,       0x404003e7,
            0x38,       0x38,       0x36,       0x32,       0x37,       0x32,       0x404006dc,
            0x31,       0x37,       0x38,       0x36,       0x30,       0x38,       0x35,
            0x37,       0x40400073, 0x33,       0x408002fc, 0x37,       0x39,       0x37,
            0x36,       0x36,       0x38,       0x31,       0x404002bd, 0x30,       0x30,
            0x39,       0x35,       0x33,       0x38,       0x38,       0x40400638, 0x33,
            0x404006a5, 0x30,       0x36,       0x38,       0x30,       0x30,       0x36,
            0x34,       0x32,       0x32,       0x35,       0x31,       0x32,       0x35,
            0x32,       0x4040057b, 0x37,       0x33,       0x39,       0x32,       0x40400297,
            0x40400474, 0x34,       0x408006b3, 0x38,       0x36,       0x32,       0x36,
            0x39,       0x34,       0x35,       0x404001e5, 0x34,       0x31,       0x39,
            0x36,       0x35,       0x32,       0x38,       0x35,       0x30,       0x40400099,
            0x4040039c, 0x31,       0x38,       0x36,       0x33,       0x404001be, 0x34,
            0x40800154, 0x32,       0x30,       0x33,       0x39,       0x4040058b, 0x34,
            0x35,       0x404002bc, 0x32,       0x33,       0x37,       0x4040042c, 0x36,
            0x40400510, 0x35,       0x36,       0x40400638, 0x37,       0x31,       0x39,
            0x31,       0x37,       0x32,       0x38,       0x40400171, 0x37,       0x36,
            0x34,       0x36,       0x35,       0x37,       0x35,       0x37,       0x33,
            0x39,       0x40400101, 0x33,       0x38,       0x39,       0x40400748, 0x38,
            0x33,       0x32,       0x36,       0x34,       0x35,       0x39,       0x39,
            0x35,       0x38,       0x404006a7, 0x30,       0x34,       0x37,       0x38,
            0x404001de, 0x40400328, 0x39,       0x4040002d, 0x36,       0x34,       0x30,
            0x37,       0x38,       0x39,       0x35,       0x31,       0x4040008e, 0x36,
            0x38,       0x33,       0x4040012f, 0x32,       0x35,       0x39,       0x35,
            0x37,       0x30,       0x40400468, 0x38,       0x32,       0x32,       0x404002c8,
            0x32,       0x4040061b, 0x34,       0x30,       0x37,       0x37,       0x32,
            0x36,       0x37,       0x31,       0x39,       0x34,       0x37,       0x38,
            0x40400319, 0x38,       0x32,       0x36,       0x30,       0x31,       0x34,
            0x37,       0x36,       0x39,       0x39,       0x30,       0x39,       0x404004e8,
            0x30,       0x31,       0x33,       0x36,       0x33,       0x39,       0x34,
            0x34,       0x33,       0x4040027f, 0x33,       0x30,       0x40400105, 0x32,
            0x30,       0x33,       0x34,       0x39,       0x36,       0x32,       0x35,
            0x32,       0x34,       0x35,       0x31,       0x37,       0x404003b5, 0x39,
            0x36,       0x35,       0x31,       0x34,       0x33,       0x31,       0x34,
            0x32,       0x39,       0x38,       0x30,       0x39,       0x31,       0x39,
            0x30,       0x36,       0x35,       0x39,       0x32,       0x40400282, 0x37,
            0x32,       0x32,       0x31,       0x36,       0x39,       0x36,       0x34,
            0x36,       0x40400419, 0x4040007a, 0x35,       0x4040050e, 0x34,       0x40800565,
            0x38,       0x40400559, 0x39,       0x37,       0x4040057b, 0x35,       0x34,
            0x4040049d, 0x4040023e, 0x37,       0x4040065a, 0x38,       0x34,       0x36,
            0x38,       0x31,       0x33,       0x4040008c, 0x36,       0x38,       0x33,
            0x38,       0x36,       0x38,       0x39,       0x34,       0x32,       0x37,
            0x37,       0x34,       0x31,       0x35,       0x35,       0x39,       0x39,
            0x31,       0x38,       0x35,       0x4040005a, 0x32,       0x34,       0x35,
            0x39,       0x35,       0x33,       0x39,       0x35,       0x39,       0x34,
            0x33,       0x31,       0x404005b7, 0x37,       0x40400012, 0x36,       0x38,
            0x30,       0x38,       0x34,       0x35,       0x404002e7, 0x37,       0x33,
            0x4040081e, 0x39,       0x35,       0x38,       0x34,       0x38,       0x36,
            0x35,       0x33,       0x38,       0x404006e8, 0x36,       0x32,       0x404000f2,
            0x36,       0x30,       0x39,       0x404004b6, 0x36,       0x30,       0x38,
            0x30,       0x35,       0x31,       0x32,       0x34,       0x33,       0x38,
            0x38,       0x34,       0x4040013a, 0x4040000b, 0x34,       0x31,       0x33,
            0x4040030f, 0x37,       0x36,       0x32,       0x37,       0x38,       0x40400341,
            0x37,       0x31,       0x35,       0x4040059b, 0x33,       0x35,       0x39,
            0x39,       0x37,       0x37,       0x30,       0x30,       0x31,       0x32,
            0x39,       0x40400472, 0x38,       0x39,       0x34,       0x34,       0x31,
            0x40400277, 0x36,       0x38,       0x35,       0x35,       0x4040005f, 0x34,
            0x30,       0x36,       0x33,       0x404008e6, 0x32,       0x30,       0x37,
            0x32,       0x32,       0x40400158, 0x40800203, 0x34,       0x38,       0x31,
            0x35,       0x38,       0x40400205, 0x404001fe, 0x4040027a, 0x40400298, 0x33,
            0x39,       0x34,       0x35,       0x32,       0x32,       0x36,       0x37,
            0x40c00496, 0x38,       0x4040058a, 0x32,       0x31,       0x404002ea, 0x32,
            0x40400387, 0x35,       0x34,       0x36,       0x36,       0x36,       0x4040051b,
            0x32,       0x33,       0x39,       0x38,       0x36,       0x34,       0x35,
            0x36,       0x404004c4, 0x31,       0x36,       0x33,       0x35,       0x40800253,
            0x40400811, 0x37,       0x404008ad, 0x39,       0x38,       0x4040045e, 0x39,
            0x33,       0x36,       0x33,       0x34,       0x4040075b, 0x37,       0x34,
            0x33,       0x32,       0x34,       0x4040047b, 0x31,       0x35,       0x30,
            0x37,       0x36,       0x404004bb, 0x37,       0x39,       0x34,       0x35,
            0x31,       0x30,       0x39,       0x4040003e, 0x30,       0x39,       0x34,
            0x30,       0x404006a6, 0x38,       0x38,       0x37,       0x39,       0x37,
            0x31,       0x30,       0x38,       0x39,       0x33,       0x404008f0, 0x36,
            0x39,       0x31,       0x33,       0x36,       0x38,       0x36,       0x37,
            0x32,       0x4040025b, 0x404001fe, 0x35,       0x4040053f, 0x40400468, 0x40400801,
            0x31,       0x37,       0x39,       0x32,       0x38,       0x36,       0x38,
            0x404008cc, 0x38,       0x37,       0x34,       0x37,       0x4080079e, 0x38,
            0x32,       0x34,       0x4040097a, 0x38,       0x4040025b, 0x37,       0x31,
            0x34,       0x39,       0x30,       0x39,       0x36,       0x37,       0x35,
            0x39,       0x38,       0x404006ef, 0x33,       0x36,       0x35,       0x40400134,
            0x38,       0x31,       0x4040005c, 0x40400745, 0x40400936, 0x36,       0x38,
            0x32,       0x39,       0x4040057e, 0x38,       0x37,       0x32,       0x32,
            0x36,       0x35,       0x38,       0x38,       0x30,       0x40400611, 0x35,
            0x40400249, 0x34,       0x32,       0x37,       0x30,       0x34,       0x37,
            0x37,       0x35,       0x35,       0x4040081e, 0x33,       0x37,       0x39,
            0x36,       0x34,       0x31,       0x34,       0x35,       0x31,       0x35,
            0x32,       0x404005fd, 0x32,       0x33,       0x34,       0x33,       0x36,
            0x34,       0x35,       0x34,       0x404005de, 0x34,       0x34,       0x34,
            0x37,       0x39,       0x35,       0x4040003c, 0x40400523, 0x408008e6, 0x34,
            0x31,       0x4040052a, 0x33,       0x40400304, 0x35,       0x32,       0x33,
            0x31,       0x40800841, 0x31,       0x36,       0x36,       0x31,       0x404008b2,
            0x35,       0x39,       0x36,       0x39,       0x35,       0x33,       0x36,
            0x32,       0x33,       0x31,       0x34,       0x404005ff, 0x32,       0x34,
            0x38,       0x34,       0x39,       0x33,       0x37,       0x31,       0x38,
            0x37,       0x31,       0x31,       0x30,       0x31,       0x34,       0x35,
            0x37,       0x36,       0x35,       0x34,       0x40400761, 0x30,       0x32,
            0x37,       0x39,       0x39,       0x33,       0x34,       0x34,       0x30,
            0x33,       0x37,       0x34,       0x32,       0x30,       0x30,       0x37,
            0x4040093f, 0x37,       0x38,       0x35,       0x33,       0x39,       0x30,
            0x36,       0x32,       0x31,       0x39,       0x40800299, 0x40400345, 0x38,
            0x34,       0x37,       0x408003d2, 0x38,       0x33,       0x33,       0x32,
            0x31,       0x34,       0x34,       0x35,       0x37,       0x31,       0x40400284,
            0x40400776, 0x34,       0x33,       0x35,       0x30,       0x40400928, 0x40400468,
            0x35,       0x33,       0x31,       0x39,       0x31,       0x30,       0x34,
            0x38,       0x34,       0x38,       0x31,       0x30,       0x30,       0x35,
            0x33,       0x37,       0x30,       0x36,       0x404008bc, 0x4080059d, 0x40800781,
            0x31,       0x40400559, 0x37,       0x4040031b, 0x35,       0x404007ec, 0x4040040c,
            0x36,       0x33,       0x408007dc, 0x34,       0x40400971, 0x4080034e, 0x408003f5,
            0x38,       0x4080052d, 0x40800887, 0x39,       0x40400187, 0x39,       0x31,
            0x404008ce, 0x38,       0x31,       0x34,       0x36,       0x37,       0x35,
            0x31,       0x4040062b, 0x31,       0x32,       0x33,       0x39,       0x40c001a9,
            0x39,       0x30,       0x37,       0x31,       0x38,       0x36,       0x34,
            0x39,       0x34,       0x32,       0x33,       0x31,       0x39,       0x36,
            0x31,       0x35,       0x36,       0x404001ec, 0x404006bc, 0x39,       0x35,
            0x40400926, 0x40400469, 0x4040011b, 0x36,       0x30,       0x33,       0x38,
            0x40400a25, 0x4040016f, 0x40400384, 0x36,       0x32,       0x4040045a, 0x35,
            0x4040084c, 0x36,       0x33,       0x38,       0x39,       0x33,       0x37,
            0x37,       0x38,       0x37,       0x404008c5, 0x404000f8, 0x39,       0x37,
            0x39,       0x32,       0x30,       0x37,       0x37,       0x33,       0x404005d7,
            0x32,       0x31,       0x38,       0x32,       0x35,       0x36,       0x404007df,
            0x36,       0x36,       0x404006d6, 0x34,       0x32,       0x4080067e, 0x36,
            0x404006e6, 0x34,       0x34,       0x40400024, 0x35,       0x34,       0x39,
            0x32,       0x30,       0x32,       0x36,       0x30,       0x35,       0x40400ab3,
            0x408003e4, 0x32,       0x30,       0x31,       0x34,       0x39,       0x404004d2,
            0x38,       0x35,       0x30,       0x37,       0x33,       0x40400599, 0x36,
            0x36,       0x36,       0x30,       0x40400194, 0x32,       0x34,       0x33,
            0x34,       0x30,       0x40400087, 0x30,       0x4040076b, 0x38,       0x36,
            0x33,       0x40400956, 0x404007e4, 0x4040042b, 0x40400174, 0x35,       0x37,
            0x39,       0x36,       0x32,       0x36,       0x38,       0x35,       0x36,
            0x40400140, 0x35,       0x30,       0x38,       0x40400523, 0x35,       0x38,
            0x37,       0x39,       0x36,       0x39,       0x39,       0x40400711, 0x35,
            0x37,       0x34,       0x40400a18, 0x38,       0x34,       0x30,       0x404008b3,
            0x31,       0x34,       0x35,       0x39,       0x31,       0x4040078c, 0x37,
            0x30,       0x40400234, 0x30,       0x31,       0x40400be7, 0x31,       0x32,
            0x40400c74, 0x30,       0x404003c3, 0x33,       0x39,       0x40400b2a, 0x40400112,
            0x37,       0x31,       0x35,       0x404003b0, 0x34,       0x32,       0x30,
            0x40800bf2, 0x39,       0x40400bc2, 0x30,       0x37,       0x40400341, 0x40400795,
            0x40400aaf, 0x40400c62, 0x32,       0x31,       0x40400960, 0x32,       0x35,
            0x31,       0x4040057b, 0x40400944, 0x39,       0x32,       0x404001b2, 0x38,
            0x32,       0x36,       0x40400b66, 0x32,       0x40400278, 0x33,       0x32,
            0x31,       0x35,       0x37,       0x39,       0x31,       0x39,       0x38,
            0x34,       0x31,       0x34,       0x4080087b, 0x39,       0x31,       0x36,
            0x34,       0x408006e8, 0x39,       0x40800b58, 0x404008db, 0x37,       0x32,
            0x32,       0x40400321, 0x35,       0x404008a4, 0x40400141, 0x39,       0x31,
            0x30,       0x404000bc, 0x40400c5b, 0x35,       0x32,       0x38,       0x30,
            0x31,       0x37,       0x40400231, 0x37,       0x31,       0x32,       0x40400914,
            0x38,       0x33,       0x32,       0x40400373, 0x31,       0x40400589, 0x30,
            0x39,       0x33,       0x35,       0x33,       0x39,       0x36,       0x35,
            0x37,       0x4040064b, 0x31,       0x30,       0x38,       0x33,       0x40400069,
            0x35,       0x31,       0x4040077a, 0x40400d5a, 0x31,       0x34,       0x34,
            0x34,       0x32,       0x31,       0x30,       0x30,       0x40400202, 0x30,
            0x33,       0x4040019c, 0x31,       0x31,       0x30,       0x33,       0x40400c81,
            0x40400009, 0x40400026, 0x40c00602, 0x35,       0x31,       0x36,       0x404005d9,
            0x40800883, 0x4040092a, 0x35,       0x40800c42, 0x38,       0x35,       0x31,
            0x37,       0x31,       0x34,       0x33,       0x37,       0x40400605, 0x4040006d,
            0x31,       0x35,       0x35,       0x36,       0x35,       0x30,       0x38,
            0x38,       0x404003b9, 0x39,       0x38,       0x39,       0x38,       0x35,
            0x39,       0x39,       0x38,       0x32,       0x33,       0x38,       0x404001cf,
            0x404009ba, 0x33,       0x4040016c, 0x4040043e, 0x404009c3, 0x38,       0x40800e05,
            0x33,       0x32,       0x40400107, 0x35,       0x40400305, 0x33,       0x404001ca,
            0x39,       0x4040041b, 0x39,       0x38,       0x4040087d, 0x34,       0x40400cb8,
            0x37,       0x4040064b, 0x30,       0x37,       0x404000e5, 0x34,       0x38,
            0x31,       0x34,       0x31,       0x40400539, 0x38,       0x35,       0x39,
            0x34,       0x36,       0x31,       0x40400bc9, 0x38,       0x30,
        },
    },
    HuffTest{
        .input = "huffman-rand-1k.input",
        .want = "huffman-rand-1k.{s}.expect",
        .want_no_input = "huffman-rand-1k.{s}.expect-noinput",
        .tokens = &[_]token.Token{
            0xf8, 0x8b, 0x96, 0x76, 0x48, 0xd,  0x85, 0x94, 0x25, 0x80, 0xaf, 0xc2, 0xfe, 0x8d,
            0xe8, 0x20, 0xeb, 0x17, 0x86, 0xc9, 0xb7, 0xc5, 0xde, 0x6,  0xea, 0x7d, 0x18, 0x8b,
            0xe7, 0x3e, 0x7,  0xda, 0xdf, 0xff, 0x6c, 0x73, 0xde, 0xcc, 0xe7, 0x6d, 0x8d, 0x4,
            0x19, 0x49, 0x7f, 0x47, 0x1f, 0x48, 0x15, 0xb0, 0xe8, 0x9e, 0xf2, 0x31, 0x59, 0xde,
            0x34, 0xb4, 0x5b, 0xe5, 0xe0, 0x9,  0x11, 0x30, 0xc2, 0x88, 0x5b, 0x7c, 0x5d, 0x14,
            0x13, 0x6f, 0x23, 0xa9, 0xd,  0xbc, 0x2d, 0x23, 0xbe, 0xd9, 0xed, 0x75, 0x4,  0x6c,
            0x99, 0xdf, 0xfd, 0x70, 0x66, 0xe6, 0xee, 0xd9, 0xb1, 0x9e, 0x6e, 0x83, 0x59, 0xd5,
            0xd4, 0x80, 0x59, 0x98, 0x77, 0x89, 0x43, 0x38, 0xc9, 0xaf, 0x30, 0x32, 0x9a, 0x20,
            0x1b, 0x46, 0x3d, 0x67, 0x6e, 0xd7, 0x72, 0x9e, 0x4e, 0x21, 0x4f, 0xc6, 0xe0, 0xd4,
            0x7b, 0x4,  0x8d, 0xa5, 0x3,  0xf6, 0x5,  0x9b, 0x6b, 0xdc, 0x2a, 0x93, 0x77, 0x28,
            0xfd, 0xb4, 0x62, 0xda, 0x20, 0xe7, 0x1f, 0xab, 0x6b, 0x51, 0x43, 0x39, 0x2f, 0xa0,
            0x92, 0x1,  0x6c, 0x75, 0x3e, 0xf4, 0x35, 0xfd, 0x43, 0x2e, 0xf7, 0xa4, 0x75, 0xda,
            0xea, 0x9b, 0xa,  0x64, 0xb,  0xe0, 0x23, 0x29, 0xbd, 0xf7, 0xe7, 0x83, 0x3c, 0xfb,
            0xdf, 0xb3, 0xae, 0x4f, 0xa4, 0x47, 0x55, 0x99, 0xde, 0x2f, 0x96, 0x6e, 0x1c, 0x43,
            0x4c, 0x87, 0xe2, 0x7c, 0xd9, 0x5f, 0x4c, 0x7c, 0xe8, 0x90, 0x3,  0xdb, 0x30, 0x95,
            0xd6, 0x22, 0xc,  0x47, 0xb8, 0x4d, 0x6b, 0xbd, 0x24, 0x11, 0xab, 0x2c, 0xd7, 0xbe,
            0x6e, 0x7a, 0xd6, 0x8,  0xa3, 0x98, 0xd8, 0xdd, 0x15, 0x6a, 0xfa, 0x93, 0x30, 0x1,
            0x25, 0x1d, 0xa2, 0x74, 0x86, 0x4b, 0x6a, 0x95, 0xe8, 0xe1, 0x4e, 0xe,  0x76, 0xb9,
            0x49, 0xa9, 0x5f, 0xa0, 0xa6, 0x63, 0x3c, 0x7e, 0x7e, 0x20, 0x13, 0x4f, 0xbb, 0x66,
            0x92, 0xb8, 0x2e, 0xa4, 0xfa, 0x48, 0xcb, 0xae, 0xb9, 0x3c, 0xaf, 0xd3, 0x1f, 0xe1,
            0xd5, 0x8d, 0x42, 0x6d, 0xf0, 0xfc, 0x8c, 0xc,  0x0,  0xde, 0x40, 0xab, 0x8b, 0x47,
            0x97, 0x4e, 0xa8, 0xcf, 0x8e, 0xdb, 0xa6, 0x8b, 0x20, 0x9,  0x84, 0x7a, 0x66, 0xe5,
            0x98, 0x29, 0x2,  0x95, 0xe6, 0x38, 0x32, 0x60, 0x3,  0xe3, 0x9a, 0x1e, 0x54, 0xe8,
            0x63, 0x80, 0x48, 0x9c, 0xe7, 0x63, 0x33, 0x6e, 0xa0, 0x65, 0x83, 0xfa, 0xc6, 0xba,
            0x7a, 0x43, 0x71, 0x5,  0xf5, 0x68, 0x69, 0x85, 0x9c, 0xba, 0x45, 0xcd, 0x6b, 0xb,
            0x19, 0xd1, 0xbb, 0x7f, 0x70, 0x85, 0x92, 0xd1, 0xb4, 0x64, 0x82, 0xb1, 0xe4, 0x62,
            0xc5, 0x3c, 0x46, 0x1f, 0x92, 0x31, 0x1c, 0x4e, 0x41, 0x77, 0xf7, 0xe7, 0x87, 0xa2,
            0xf,  0x6e, 0xe8, 0x92, 0x3,  0x6b, 0xa,  0xe7, 0xa9, 0x3b, 0x11, 0xda, 0x66, 0x8a,
            0x29, 0xda, 0x79, 0xe1, 0x64, 0x8d, 0xe3, 0x54, 0xd4, 0xf5, 0xef, 0x64, 0x87, 0x3b,
            0xf4, 0xc2, 0xf4, 0x71, 0x13, 0xa9, 0xe9, 0xe0, 0xa2, 0x6,  0x14, 0xab, 0x5d, 0xa7,
            0x96, 0x0,  0xd6, 0xc3, 0xcc, 0x57, 0xed, 0x39, 0x6a, 0x25, 0xcd, 0x76, 0xea, 0xba,
            0x3a, 0xf2, 0xa1, 0x95, 0x5d, 0xe5, 0x71, 0xcf, 0x9c, 0x62, 0x9e, 0x6a, 0xfa, 0xd5,
            0x31, 0xd1, 0xa8, 0x66, 0x30, 0x33, 0xaa, 0x51, 0x17, 0x13, 0x82, 0x99, 0xc8, 0x14,
            0x60, 0x9f, 0x4d, 0x32, 0x6d, 0xda, 0x19, 0x26, 0x21, 0xdc, 0x7e, 0x2e, 0x25, 0x67,
            0x72, 0xca, 0xf,  0x92, 0xcd, 0xf6, 0xd6, 0xcb, 0x97, 0x8a, 0x33, 0x58, 0x73, 0x70,
            0x91, 0x1d, 0xbf, 0x28, 0x23, 0xa3, 0xc,  0xf1, 0x83, 0xc3, 0xc8, 0x56, 0x77, 0x68,
            0xe3, 0x82, 0xba, 0xb9, 0x57, 0x56, 0x57, 0x9c, 0xc3, 0xd6, 0x14, 0x5,  0x3c, 0xb1,
            0xaf, 0x93, 0xc8, 0x8a, 0x57, 0x7f, 0x53, 0xfa, 0x2f, 0xaa, 0x6e, 0x66, 0x83, 0xfa,
            0x33, 0xd1, 0x21, 0xab, 0x1b, 0x71, 0xb4, 0x7c, 0xda, 0xfd, 0xfb, 0x7f, 0x20, 0xab,
            0x5e, 0xd5, 0xca, 0xfd, 0xdd, 0xe0, 0xee, 0xda, 0xba, 0xa8, 0x27, 0x99, 0x97, 0x69,
            0xc1, 0x3c, 0x82, 0x8c, 0xa,  0x5c, 0x2d, 0x5b, 0x88, 0x3e, 0x34, 0x35, 0x86, 0x37,
            0x46, 0x79, 0xe1, 0xaa, 0x19, 0xfb, 0xaa, 0xde, 0x15, 0x9,  0xd,  0x1a, 0x57, 0xff,
            0xb5, 0xf,  0xf3, 0x2b, 0x5a, 0x6a, 0x4d, 0x19, 0x77, 0x71, 0x45, 0xdf, 0x4f, 0xb3,
            0xec, 0xf1, 0xeb, 0x18, 0x53, 0x3e, 0x3b, 0x47, 0x8,  0x9a, 0x73, 0xa0, 0x5c, 0x8c,
            0x5f, 0xeb, 0xf,  0x3a, 0xc2, 0x43, 0x67, 0xb4, 0x66, 0x67, 0x80, 0x58, 0xe,  0xc1,
            0xec, 0x40, 0xd4, 0x22, 0x94, 0xca, 0xf9, 0xe8, 0x92, 0xe4, 0x69, 0x38, 0xbe, 0x67,
            0x64, 0xca, 0x50, 0xc7, 0x6,  0x67, 0x42, 0x6e, 0xa3, 0xf0, 0xb7, 0x6c, 0xf2, 0xe8,
            0x5f, 0xb1, 0xaf, 0xe7, 0xdb, 0xbb, 0x77, 0xb5, 0xf8, 0xcb, 0x8,  0xc4, 0x75, 0x7e,
            0xc0, 0xf9, 0x1c, 0x7f, 0x3c, 0x89, 0x2f, 0xd2, 0x58, 0x3a, 0xe2, 0xf8, 0x91, 0xb6,
            0x7b, 0x24, 0x27, 0xe9, 0xae, 0x84, 0x8b, 0xde, 0x74, 0xac, 0xfd, 0xd9, 0xb7, 0x69,
            0x2a, 0xec, 0x32, 0x6f, 0xf0, 0x92, 0x84, 0xf1, 0x40, 0xc,  0x8a, 0xbc, 0x39, 0x6e,
            0x2e, 0x73, 0xd4, 0x6e, 0x8a, 0x74, 0x2a, 0xdc, 0x60, 0x1f, 0xa3, 0x7,  0xde, 0x75,
            0x8b, 0x74, 0xc8, 0xfe, 0x63, 0x75, 0xf6, 0x3d, 0x63, 0xac, 0x33, 0x89, 0xc3, 0xf0,
            0xf8, 0x2d, 0x6b, 0xb4, 0x9e, 0x74, 0x8b, 0x5c, 0x33, 0xb4, 0xca, 0xa8, 0xe4, 0x99,
            0xb6, 0x90, 0xa1, 0xef, 0xf,  0xd3, 0x61, 0xb2, 0xc6, 0x1a, 0x94, 0x7c, 0x44, 0x55,
            0xf4, 0x45, 0xff, 0x9e, 0xa5, 0x5a, 0xc6, 0xa0, 0xe8, 0x2a, 0xc1, 0x8d, 0x6f, 0x34,
            0x11, 0xb9, 0xbe, 0x4e, 0xd9, 0x87, 0x97, 0x73, 0xcf, 0x3d, 0x23, 0xae, 0xd5, 0x1a,
            0x5e, 0xae, 0x5d, 0x6a, 0x3,  0xf9, 0x22, 0xd,  0x10, 0xd9, 0x47, 0x69, 0x15, 0x3f,
            0xee, 0x52, 0xa3, 0x8,  0xd2, 0x3c, 0x51, 0xf4, 0xf8, 0x9d, 0xe4, 0x98, 0x89, 0xc8,
            0x67, 0x39, 0xd5, 0x5e, 0x35, 0x78, 0x27, 0xe8, 0x3c, 0x80, 0xae, 0x79, 0x71, 0xd2,
            0x93, 0xf4, 0xaa, 0x51, 0x12, 0x1c, 0x4b, 0x1b, 0xe5, 0x6e, 0x15, 0x6f, 0xe4, 0xbb,
            0x51, 0x9b, 0x45, 0x9f, 0xf9, 0xc4, 0x8c, 0x2a, 0xfb, 0x1a, 0xdf, 0x55, 0xd3, 0x48,
            0x93, 0x27, 0x1,  0x26, 0xc2, 0x6b, 0x55, 0x6d, 0xa2, 0xfb, 0x84, 0x8b, 0xc9, 0x9e,
            0x28, 0xc2, 0xef, 0x1a, 0x24, 0xec, 0x9b, 0xae, 0xbd, 0x60, 0xe9, 0x15, 0x35, 0xee,
            0x42, 0xa4, 0x33, 0x5b, 0xfa, 0xf,  0xb6, 0xf7, 0x1,  0xa6, 0x2,  0x4c, 0xca, 0x90,
            0x58, 0x3a, 0x96, 0x41, 0xe7, 0xcb, 0x9,  0x8c, 0xdb, 0x85, 0x4d, 0xa8, 0x89, 0xf3,
            0xb5, 0x8e, 0xfd, 0x75, 0x5b, 0x4f, 0xed, 0xde, 0x3f, 0xeb, 0x38, 0xa3, 0xbe, 0xb0,
            0x73, 0xfc, 0xb8, 0x54, 0xf7, 0x4c, 0x30, 0x67, 0x2e, 0x38, 0xa2, 0x54, 0x18, 0xba,
            0x8,  0xbf, 0xf2, 0x39, 0xd5, 0xfe, 0xa5, 0x41, 0xc6, 0x66, 0x66, 0xba, 0x81, 0xef,
            0x67, 0xe4, 0xe6, 0x3c, 0xc,  0xca, 0xa4, 0xa,  0x79, 0xb3, 0x57, 0x8b, 0x8a, 0x75,
            0x98, 0x18, 0x42, 0x2f, 0x29, 0xa3, 0x82, 0xef, 0x9f, 0x86, 0x6,  0x23, 0xe1, 0x75,
            0xfa, 0x8,  0xb1, 0xde, 0x17, 0x4a,
        },
    },
    HuffTest{
        .input = "huffman-rand-limit.input",
        .want = "huffman-rand-limit.{s}.expect",
        .want_no_input = "huffman-rand-limit.{s}.expect-noinput",
        .tokens = &[_]token.Token{
            0x61, 0x51c00000, 0xa,  0xf8, 0x8b, 0x96, 0x76, 0x48, 0xa,  0x85, 0x94, 0x25, 0x80,
            0xaf, 0xc2,       0xfe, 0x8d, 0xe8, 0x20, 0xeb, 0x17, 0x86, 0xc9, 0xb7, 0xc5, 0xde,
            0x6,  0xea,       0x7d, 0x18, 0x8b, 0xe7, 0x3e, 0x7,  0xda, 0xdf, 0xff, 0x6c, 0x73,
            0xde, 0xcc,       0xe7, 0x6d, 0x8d, 0x4,  0x19, 0x49, 0x7f, 0x47, 0x1f, 0x48, 0x15,
            0xb0, 0xe8,       0x9e, 0xf2, 0x31, 0x59, 0xde, 0x34, 0xb4, 0x5b, 0xe5, 0xe0, 0x9,
            0x11, 0x30,       0xc2, 0x88, 0x5b, 0x7c, 0x5d, 0x14, 0x13, 0x6f, 0x23, 0xa9, 0xa,
            0xbc, 0x2d,       0x23, 0xbe, 0xd9, 0xed, 0x75, 0x4,  0x6c, 0x99, 0xdf, 0xfd, 0x70,
            0x66, 0xe6,       0xee, 0xd9, 0xb1, 0x9e, 0x6e, 0x83, 0x59, 0xd5, 0xd4, 0x80, 0x59,
            0x98, 0x77,       0x89, 0x43, 0x38, 0xc9, 0xaf, 0x30, 0x32, 0x9a, 0x20, 0x1b, 0x46,
            0x3d, 0x67,       0x6e, 0xd7, 0x72, 0x9e, 0x4e, 0x21, 0x4f, 0xc6, 0xe0, 0xd4, 0x7b,
            0x4,  0x8d,       0xa5, 0x3,  0xf6, 0x5,  0x9b, 0x6b, 0xdc, 0x2a, 0x93, 0x77, 0x28,
            0xfd, 0xb4,       0x62, 0xda, 0x20, 0xe7, 0x1f, 0xab, 0x6b, 0x51, 0x43, 0x39, 0x2f,
            0xa0, 0x92,       0x1,  0x6c, 0x75, 0x3e, 0xf4, 0x35, 0xfd, 0x43, 0x2e, 0xf7, 0xa4,
            0x75, 0xda,       0xea, 0x9b, 0xa,
        },
    },
    HuffTest{
        .input = "huffman-shifts.input",
        .want = "huffman-shifts.{s}.expect",
        .want_no_input = "huffman-shifts.{s}.expect-noinput",
        .tokens = &[_]token.Token{
            0x31,       0x30,       0x7fc00001, 0x7fc00001, 0x7fc00001, 0x7fc00001, 0x7fc00001,
            0x7fc00001, 0x7fc00001, 0x7fc00001, 0x7fc00001, 0x7fc00001, 0x7fc00001, 0x7fc00001,
            0x7fc00001, 0x7fc00001, 0x7fc00001, 0x52400001, 0xd,        0xa,        0x32,
            0x33,       0x7fc00001, 0x7fc00001, 0x7fc00001, 0x7fc00001, 0x7fc00001, 0x7fc00001,
            0x7fc00001, 0x7fc00001, 0x7fc00001, 0x7f400001,
        },
    },
    HuffTest{
        .input = "huffman-text-shift.input",
        .want = "huffman-text-shift.{s}.expect",
        .want_no_input = "huffman-text-shift.{s}.expect-noinput",
        .tokens = &[_]token.Token{
            0x2f,       0x2f, 0x43, 0x6f, 0x70, 0x79, 0x72,       0x69, 0x67,       0x68,
            0x74,       0x32, 0x30, 0x30, 0x39, 0x54, 0x68,       0x47, 0x6f,       0x41,
            0x75,       0x74, 0x68, 0x6f, 0x72, 0x2e, 0x41,       0x6c, 0x6c,       0x40800016,
            0x72,       0x72, 0x76, 0x64, 0x2e, 0xd,  0xa,        0x2f, 0x2f,       0x55,
            0x6f,       0x66, 0x74, 0x68, 0x69, 0x6f, 0x75,       0x72, 0x63,       0x63,
            0x6f,       0x64, 0x69, 0x67, 0x6f, 0x76, 0x72,       0x6e, 0x64,       0x62,
            0x79,       0x42, 0x53, 0x44, 0x2d, 0x74, 0x79,       0x6c, 0x40400020, 0x6c,
            0x69,       0x63, 0x6e, 0x74, 0x68, 0x74, 0x63,       0x6e, 0x62,       0x66,
            0x6f,       0x75, 0x6e, 0x64, 0x69, 0x6e, 0x74,       0x68, 0x4c,       0x49,
            0x43,       0x45, 0x4e, 0x53, 0x45, 0x66, 0x69,       0x6c, 0x2e,       0xd,
            0xa,        0xd,  0xa,  0x70, 0x63, 0x6b, 0x67,       0x6d, 0x69,       0x6e,
            0x4040000a, 0x69, 0x6d, 0x70, 0x6f, 0x72, 0x74,       0x22, 0x6f,       0x22,
            0x4040000c, 0x66, 0x75, 0x6e, 0x63, 0x6d, 0x69,       0x6e, 0x28,       0x29,
            0x7b,       0xd,  0xa,  0x9,  0x76, 0x72, 0x62,       0x3d, 0x6d,       0x6b,
            0x28,       0x5b, 0x5d, 0x62, 0x79, 0x74, 0x2c,       0x36, 0x35,       0x35,
            0x33,       0x35, 0x29, 0xd,  0xa,  0x9,  0x66,       0x2c, 0x5f,       0x3a,
            0x3d,       0x6f, 0x2e, 0x43, 0x72, 0x74, 0x28,       0x22, 0x68,       0x75,
            0x66,       0x66, 0x6d, 0x6e, 0x2d, 0x6e, 0x75,       0x6c, 0x6c,       0x2d,
            0x6d,       0x78, 0x2e, 0x69, 0x6e, 0x22, 0x40800021, 0x2e, 0x57,       0x72,
            0x69,       0x74, 0x28, 0x62, 0x29, 0xd,  0xa,        0x7d, 0xd,        0xa,
            0x41,       0x42, 0x43, 0x44, 0x45, 0x46, 0x47,       0x48, 0x49,       0x4a,
            0x4b,       0x4c, 0x4d, 0x4e, 0x4f, 0x50, 0x51,       0x52, 0x53,       0x54,
            0x55,       0x56, 0x58, 0x78, 0x79, 0x7a, 0x21,       0x22, 0x23,       0xc2,
            0xa4,       0x25, 0x26, 0x2f, 0x3f, 0x22,
        },
    },
    HuffTest{
        .input = "huffman-text.input",
        .want = "huffman-text.{s}.expect",
        .want_no_input = "huffman-text.{s}.expect-noinput",
        .tokens = &[_]token.Token{
            0x2f,       0x2f,       0x20,       0x7a,       0x69, 0x67, 0x20, 0x76,
            0x30,       0x2e,       0x31,       0x30,       0x2e, 0x30, 0x0a, 0x2f,
            0x2f,       0x20,       0x63,       0x72,       0x65, 0x61, 0x74, 0x65,
            0x20,       0x61,       0x20,       0x66,       0x69, 0x6c, 0x65, 0x40400004,
            0x6c,       0x65,       0x64,       0x20,       0x77, 0x69, 0x74, 0x68,
            0x20,       0x30,       0x78,       0x30,       0x30, 0x0a, 0x63, 0x6f,
            0x6e,       0x73,       0x74,       0x20,       0x73, 0x74, 0x64, 0x20,
            0x3d,       0x20,       0x40,       0x69,       0x6d, 0x70, 0x6f, 0x72,
            0x74,       0x28,       0x22,       0x73,       0x74, 0x64, 0x22, 0x29,
            0x3b,       0x0a,       0x0a,       0x70,       0x75, 0x62, 0x20, 0x66,
            0x6e,       0x20,       0x6d,       0x61,       0x69, 0x6e, 0x28, 0x29,
            0x20,       0x21,       0x76,       0x6f,       0x69, 0x64, 0x20, 0x7b,
            0x0a,       0x20,       0x20,       0x20,       0x20, 0x76, 0x61, 0x72,
            0x20,       0x62,       0x20,       0x3d,       0x20, 0x5b, 0x31, 0x5d,
            0x75,       0x38,       0x7b,       0x30,       0x7d, 0x20, 0x2a, 0x2a,
            0x20,       0x36,       0x35,       0x35,       0x33, 0x35, 0x3b, 0x4080001e,
            0x40c00055, 0x66,       0x20,       0x3d,       0x20, 0x74, 0x72, 0x79,
            0x4040005d, 0x2e,       0x66,       0x73,       0x2e, 0x63, 0x77, 0x64,
            0x28,       0x29,       0x2e,       0x40c0008f, 0x46, 0x69, 0x6c, 0x65,
            0x28,       0x4080002a, 0x40400000, 0x22,       0x68, 0x75, 0x66, 0x66,
            0x6d,       0x61,       0x6e,       0x2d,       0x6e, 0x75, 0x6c, 0x6c,
            0x2d,       0x6d,       0x61,       0x78,       0x2e, 0x69, 0x6e, 0x22,
            0x2c,       0x4180001e, 0x2e,       0x7b,       0x20, 0x2e, 0x72, 0x65,
            0x61,       0x64,       0x4080004e, 0x75,       0x65, 0x20, 0x7d, 0x40c0001a,
            0x29,       0x40c0006b, 0x64,       0x65,       0x66, 0x65, 0x72, 0x20,
            0x66,       0x2e,       0x63,       0x6c,       0x6f, 0x73, 0x65, 0x28,
            0x404000b6, 0x40400015, 0x5f,       0x4100007b, 0x66, 0x2e, 0x77, 0x72,
            0x69,       0x74,       0x65,       0x41,       0x6c, 0x6c, 0x28, 0x62,
            0x5b,       0x30,       0x2e,       0x2e,       0x5d, 0x29, 0x3b, 0x0a,
            0x7d,       0x0a,
        },
    },
    HuffTest{
        .input = "huffman-zero.input",
        .want = "huffman-zero.{s}.expect",
        .want_no_input = "huffman-zero.{s}.expect-noinput",
        .tokens = &[_]token.Token{ 0x30, ml, 0x4b800000 },
    },
    HuffTest{
        .input = "",
        .want = "",
        .want_no_input = "null-long-match.{s}.expect-noinput",
        .tokens = &[_]token.Token{
            0x0, ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, ml,         ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml, ml,
            ml,  ml, ml, 0x41400000,
        },
    },
};

const TestType = enum {
    write_block,
    write_dyn_block, // write dynamic block
    write_huffman_block,

    fn to_s(self: TestType) []const u8 {
        return switch (self) {
            .write_block => "wb",
            .write_dyn_block => "dyn",
            .write_huffman_block => "huff",
        };
    }
};

test "writeBlock" {
    // tests if the writeBlock encoding has changed.

    const ttype: TestType = .write_block;
    try testBlock(writeBlockTests[0], ttype);
    try testBlock(writeBlockTests[1], ttype);
    try testBlock(writeBlockTests[2], ttype);
    try testBlock(writeBlockTests[3], ttype);
    try testBlock(writeBlockTests[4], ttype);
    try testBlock(writeBlockTests[5], ttype);
    try testBlock(writeBlockTests[6], ttype);
    try testBlock(writeBlockTests[7], ttype);
    try testBlock(writeBlockTests[8], ttype);
}

test "writeBlockDynamic" {
    // tests if the writeBlockDynamic encoding has changed.

    const ttype: TestType = .write_dyn_block;
    try testBlock(writeBlockTests[0], ttype);
    try testBlock(writeBlockTests[1], ttype);
    try testBlock(writeBlockTests[2], ttype);
    try testBlock(writeBlockTests[3], ttype);
    try testBlock(writeBlockTests[4], ttype);
    try testBlock(writeBlockTests[5], ttype);
    try testBlock(writeBlockTests[6], ttype);
    try testBlock(writeBlockTests[7], ttype);
    try testBlock(writeBlockTests[8], ttype);
}

// testBlock tests a block against its references,
// or regenerate the references, if "-update" flag is set.
fn testBlock(comptime ht: HuffTest, comptime ttype: TestType) !void {
    if (ht.input.len != 0 and ht.want.len != 0) {
        const want_name = comptime fmt.comptimePrint(ht.want, .{ttype.to_s()});
        const input = @embedFile("testdata/" ++ ht.input);
        const want = @embedFile("testdata/" ++ want_name);

        var buf = ArrayList(u8).init(testing.allocator);
        var bw = try huffmanBitWriter(testing.allocator, buf.writer());
        try writeToType(ttype, &bw, ht.tokens, input);

        var got = buf.items;
        try testing.expectEqualSlices(u8, want, got); // expect writeBlock to yield expected result

        // Test if the writer produces the same output after reset.
        buf.deinit();
        buf = ArrayList(u8).init(testing.allocator);
        defer buf.deinit();

        bw.reset(buf.writer());
        defer bw.deinit();

        try writeToType(ttype, &bw, ht.tokens, input);
        try bw.flush();
        got = buf.items;
        try testing.expectEqualSlices(u8, want, got); // expect writeBlock to yield expected result
        try testWriterEOF(.write_block, ht.tokens, input);
    }

    const want_name_no_input = comptime fmt.comptimePrint(ht.want_no_input, .{ttype.to_s()});
    const want_ni = @embedFile("testdata/" ++ want_name_no_input);

    var buf = ArrayList(u8).init(testing.allocator);
    var bw = try huffmanBitWriter(testing.allocator, buf.writer());

    try writeToType(ttype, &bw, ht.tokens, null);

    var got = buf.items;
    try testing.expectEqualSlices(u8, want_ni, got); // expect writeBlock to yield expected result
    try expect(got[0] & 1 != 1); // expect no EOF

    // Test if the writer produces the same output after reset.
    buf.deinit();
    buf = ArrayList(u8).init(testing.allocator);
    defer buf.deinit();

    bw.reset(buf.writer());
    defer bw.deinit();

    try writeToType(ttype, &bw, ht.tokens, null);
    try bw.flush();
    got = buf.items;

    try testing.expectEqualSlices(u8, want_ni, got); // expect writeBlock to yield expected result
    try testWriterEOF(.write_block, ht.tokens, &[0]u8{});
}

fn writeToType(ttype: TestType, bw: anytype, tok: []const token.Token, input: ?[]const u8) !void {
    switch (ttype) {
        .write_block => try bw.writeBlock(tok, false, input),
        .write_dyn_block => try bw.writeBlockDynamic(tok, false, input),
        else => unreachable,
    }
    try bw.flush();
}

// Tests if the written block contains an EOF marker.
fn testWriterEOF(ttype: TestType, ht_tokens: []const token.Token, input: []const u8) !void {
    var buf = ArrayList(u8).init(testing.allocator);
    defer buf.deinit();
    var bw = try huffmanBitWriter(testing.allocator, buf.writer());
    defer bw.deinit();

    switch (ttype) {
        .write_block => try bw.writeBlock(ht_tokens, true, input),
        .write_dyn_block => try bw.writeBlockDynamic(ht_tokens, true, input),
        .write_huffman_block => try bw.writeBlockHuff(true, input),
    }

    try bw.flush();

    var b = buf.items;
    try expect(b.len > 0);
    try expect(b[0] & 1 == 1);
}
