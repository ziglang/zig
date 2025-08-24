//! Accepts list of tokens, decides what is best block type to write. What block
//! type will provide best compression. Writes header and body of the block.
const std = @import("std");
const io = std.io;
const assert = std.debug.assert;
const Writer = std.io.Writer;

const BlockWriter = @This();
const flate = @import("../flate.zig");
const Compress = flate.Compress;
const HuffmanEncoder = flate.HuffmanEncoder;
const Token = @import("Token.zig");

const codegen_order = HuffmanEncoder.codegen_order;
const end_code_mark = 255;

output: *Writer,

codegen_freq: [HuffmanEncoder.codegen_code_count]u16,
literal_freq: [HuffmanEncoder.max_num_lit]u16,
distance_freq: [HuffmanEncoder.distance_code_count]u16,
codegen: [HuffmanEncoder.max_num_lit + HuffmanEncoder.distance_code_count + 1]u8,
literal_encoding: HuffmanEncoder,
distance_encoding: HuffmanEncoder,
codegen_encoding: HuffmanEncoder,
fixed_literal_encoding: HuffmanEncoder,
fixed_distance_encoding: HuffmanEncoder,
huff_distance: HuffmanEncoder,

fixed_literal_codes: [HuffmanEncoder.max_num_frequencies]HuffmanEncoder.Code,
fixed_distance_codes: [HuffmanEncoder.distance_code_count]HuffmanEncoder.Code,
distance_codes: [HuffmanEncoder.distance_code_count]HuffmanEncoder.Code,

pub fn init(output: *Writer) BlockWriter {
    return .{
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
    };
}

pub fn initBuffers(bw: *BlockWriter) void {
    bw.fixed_literal_encoding = .fixedLiteralEncoder(&bw.fixed_literal_codes);
    bw.fixed_distance_encoding = .fixedDistanceEncoder(&bw.fixed_distance_codes);
    bw.huff_distance = .huffmanDistanceEncoder(&bw.distance_codes);
}

/// Flush intrenal bit buffer to the writer.
/// Should be called only when bit stream is at byte boundary.
///
/// That is after final block; when last byte could be incomplete or
/// after stored block; which is aligned to the byte boundary (it has x
/// padding bits after first 3 bits).
pub fn flush(self: *BlockWriter) Writer.Error!void {
    try self.bit_writer.flush();
}

fn writeCode(self: *BlockWriter, c: Compress.HuffCode) Writer.Error!void {
    try self.bit_writer.writeBits(c.code, c.len);
}

/// RFC 1951 3.2.7 specifies a special run-length encoding for specifying
/// the literal and distance lengths arrays (which are concatenated into a single
/// array).  This method generates that run-length encoding.
///
/// The result is written into the codegen array, and the frequencies
/// of each code is written into the codegen_freq array.
/// Codes 0-15 are single byte codes. Codes 16-18 are followed by additional
/// information. Code bad_code is an end marker
///
/// num_literals: The number of literals in literal_encoding
/// num_distances: The number of distances in distance_encoding
/// lit_enc: The literal encoder to use
/// dist_enc: The distance encoder to use
fn generateCodegen(
    self: *BlockWriter,
    num_literals: u32,
    num_distances: u32,
    lit_enc: *Compress.LiteralEncoder,
    dist_enc: *Compress.DistanceEncoder,
) void {
    for (self.codegen_freq, 0..) |_, i| {
        self.codegen_freq[i] = 0;
    }

    // Note that we are using codegen both as a temporary variable for holding
    // a copy of the frequencies, and as the place where we put the result.
    // This is fine because the output is always shorter than the input used
    // so far.
    var codegen = &self.codegen; // cache
    // Copy the concatenated code sizes to codegen. Put a marker at the end.
    var cgnl = codegen[0..num_literals];
    for (cgnl, 0..) |_, i| {
        cgnl[i] = @as(u8, @intCast(lit_enc.codes[i].len));
    }

    cgnl = codegen[num_literals .. num_literals + num_distances];
    for (cgnl, 0..) |_, i| {
        cgnl[i] = @as(u8, @intCast(dist_enc.codes[i].len));
    }
    codegen[num_literals + num_distances] = end_code_mark;

    var size = codegen[0];
    var count: i32 = 1;
    var out_index: u32 = 0;
    var in_index: u32 = 1;
    while (size != end_code_mark) : (in_index += 1) {
        // INVARIANT: We have seen "count" copies of size that have not yet
        // had output generated for them.
        const next_size = codegen[in_index];
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
    codegen[out_index] = end_code_mark;
}

const DynamicSize = struct {
    size: u32,
    num_codegens: u32,
};

/// dynamicSize returns the size of dynamically encoded data in bits.
fn dynamicSize(
    self: *BlockWriter,
    lit_enc: *Compress.LiteralEncoder, // literal encoder
    dist_enc: *Compress.DistanceEncoder, // distance encoder
    extra_bits: u32,
) DynamicSize {
    var num_codegens = self.codegen_freq.len;
    while (num_codegens > 4 and self.codegen_freq[codegen_order[num_codegens - 1]] == 0) {
        num_codegens -= 1;
    }
    const header = 3 + 5 + 5 + 4 + (3 * num_codegens) +
        self.codegen_encoding.bitLength(self.codegen_freq[0..]) +
        self.codegen_freq[16] * 2 +
        self.codegen_freq[17] * 3 +
        self.codegen_freq[18] * 7;
    const size = header +
        lit_enc.bitLength(&self.literal_freq) +
        dist_enc.bitLength(&self.distance_freq) +
        extra_bits;

    return DynamicSize{
        .size = @as(u32, @intCast(size)),
        .num_codegens = @as(u32, @intCast(num_codegens)),
    };
}

/// fixedSize returns the size of dynamically encoded data in bits.
fn fixedSize(self: *BlockWriter, extra_bits: u32) u32 {
    return 3 +
        self.fixed_literal_encoding.bitLength(&self.literal_freq) +
        self.fixed_distance_encoding.bitLength(&self.distance_freq) +
        extra_bits;
}

const StoredSize = struct {
    size: u32,
    storable: bool,
};

/// storedSizeFits calculates the stored size, including header.
/// The function returns the size in bits and whether the block
/// fits inside a single block.
fn storedSizeFits(in: ?[]const u8) StoredSize {
    if (in == null) {
        return .{ .size = 0, .storable = false };
    }
    if (in.?.len <= HuffmanEncoder.max_store_block_size) {
        return .{ .size = @as(u32, @intCast((in.?.len + 5) * 8)), .storable = true };
    }
    return .{ .size = 0, .storable = false };
}

/// Write the header of a dynamic Huffman block to the output stream.
///
///  num_literals: The number of literals specified in codegen
///  num_distances: The number of distances specified in codegen
///  num_codegens: The number of codegens used in codegen
///  eof: Is it the end-of-file? (end of stream)
fn dynamicHeader(
    self: *BlockWriter,
    num_literals: u32,
    num_distances: u32,
    num_codegens: u32,
    eof: bool,
) Writer.Error!void {
    const first_bits: u32 = if (eof) 5 else 4;
    try self.bit_writer.writeBits(first_bits, 3);
    try self.bit_writer.writeBits(num_literals - 257, 5);
    try self.bit_writer.writeBits(num_distances - 1, 5);
    try self.bit_writer.writeBits(num_codegens - 4, 4);

    var i: u32 = 0;
    while (i < num_codegens) : (i += 1) {
        const value = self.codegen_encoding.codes[codegen_order[i]].len;
        try self.bit_writer.writeBits(value, 3);
    }

    i = 0;
    while (true) {
        const code_word: u32 = @as(u32, @intCast(self.codegen[i]));
        i += 1;
        if (code_word == end_code_mark) {
            break;
        }
        try self.writeCode(self.codegen_encoding.codes[@as(u32, @intCast(code_word))]);

        switch (code_word) {
            16 => {
                try self.bit_writer.writeBits(self.codegen[i], 2);
                i += 1;
            },
            17 => {
                try self.bit_writer.writeBits(self.codegen[i], 3);
                i += 1;
            },
            18 => {
                try self.bit_writer.writeBits(self.codegen[i], 7);
                i += 1;
            },
            else => {},
        }
    }
}

fn storedHeader(self: *BlockWriter, length: usize, eof: bool) Writer.Error!void {
    assert(length <= 65535);
    const flag: u32 = if (eof) 1 else 0;
    try self.bit_writer.writeBits(flag, 3);
    try self.flush();
    const l: u16 = @intCast(length);
    try self.bit_writer.writeBits(l, 16);
    try self.bit_writer.writeBits(~l, 16);
}

fn fixedHeader(self: *BlockWriter, eof: bool) Writer.Error!void {
    // Indicate that we are a fixed Huffman block
    var value: u32 = 2;
    if (eof) {
        value = 3;
    }
    try self.bit_writer.writeBits(value, 3);
}

/// Write a block of tokens with the smallest encoding. Will choose block type.
/// The original input can be supplied, and if the huffman encoded data
/// is larger than the original bytes, the data will be written as a
/// stored block.
/// If the input is null, the tokens will always be Huffman encoded.
pub fn write(self: *BlockWriter, tokens: []const Token, eof: bool, input: ?[]const u8) Writer.Error!void {
    const lit_and_dist = self.indexTokens(tokens);
    const num_literals = lit_and_dist.num_literals;
    const num_distances = lit_and_dist.num_distances;

    var extra_bits: u32 = 0;
    const ret = storedSizeFits(input);
    const stored_size = ret.size;
    const storable = ret.storable;

    if (storable) {
        // We only bother calculating the costs of the extra bits required by
        // the length of distance fields (which will be the same for both fixed
        // and dynamic encoding), if we need to compare those two encodings
        // against stored encoding.
        var length_code: u16 = Token.length_codes_start + 8;
        while (length_code < num_literals) : (length_code += 1) {
            // First eight length codes have extra size = 0.
            extra_bits += @as(u32, @intCast(self.literal_freq[length_code])) *
                @as(u32, @intCast(Token.lengthExtraBits(length_code)));
        }
        var distance_code: u16 = 4;
        while (distance_code < num_distances) : (distance_code += 1) {
            // First four distance codes have extra size = 0.
            extra_bits += @as(u32, @intCast(self.distance_freq[distance_code])) *
                @as(u32, @intCast(Token.distanceExtraBits(distance_code)));
        }
    }

    // Figure out smallest code.
    // Fixed Huffman baseline.
    var literal_encoding = &self.fixed_literal_encoding;
    var distance_encoding = &self.fixed_distance_encoding;
    var size = self.fixedSize(extra_bits);

    // Dynamic Huffman?
    var num_codegens: u32 = 0;

    // Generate codegen and codegenFrequencies, which indicates how to encode
    // the literal_encoding and the distance_encoding.
    self.generateCodegen(
        num_literals,
        num_distances,
        &self.literal_encoding,
        &self.distance_encoding,
    );
    self.codegen_encoding.generate(self.codegen_freq[0..], 7);
    const dynamic_size = self.dynamicSize(
        &self.literal_encoding,
        &self.distance_encoding,
        extra_bits,
    );
    const dyn_size = dynamic_size.size;
    num_codegens = dynamic_size.num_codegens;

    if (dyn_size < size) {
        size = dyn_size;
        literal_encoding = &self.literal_encoding;
        distance_encoding = &self.distance_encoding;
    }

    // Stored bytes?
    if (storable and stored_size < size) {
        try self.storedBlock(input.?, eof);
        return;
    }

    // Huffman.
    if (@intFromPtr(literal_encoding) == @intFromPtr(&self.fixed_literal_encoding)) {
        try self.fixedHeader(eof);
    } else {
        try self.dynamicHeader(num_literals, num_distances, num_codegens, eof);
    }

    // Write the tokens.
    try self.writeTokens(tokens, &literal_encoding.codes, &distance_encoding.codes);
}

pub fn storedBlock(self: *BlockWriter, input: []const u8, eof: bool) Writer.Error!void {
    try self.storedHeader(input.len, eof);
    try self.bit_writer.writeBytes(input);
}

/// writeBlockDynamic encodes a block using a dynamic Huffman table.
/// This should be used if the symbols used have a disproportionate
/// histogram distribution.
/// If input is supplied and the compression savings are below 1/16th of the
/// input size the block is stored.
fn dynamicBlock(
    self: *BlockWriter,
    tokens: []const Token,
    eof: bool,
    input: ?[]const u8,
) Writer.Error!void {
    const total_tokens = self.indexTokens(tokens);
    const num_literals = total_tokens.num_literals;
    const num_distances = total_tokens.num_distances;

    // Generate codegen and codegenFrequencies, which indicates how to encode
    // the literal_encoding and the distance_encoding.
    self.generateCodegen(
        num_literals,
        num_distances,
        &self.literal_encoding,
        &self.distance_encoding,
    );
    self.codegen_encoding.generate(self.codegen_freq[0..], 7);
    const dynamic_size = self.dynamicSize(&self.literal_encoding, &self.distance_encoding, 0);
    const size = dynamic_size.size;
    const num_codegens = dynamic_size.num_codegens;

    // Store bytes, if we don't get a reasonable improvement.

    const stored_size = storedSizeFits(input);
    const ssize = stored_size.size;
    const storable = stored_size.storable;
    if (storable and ssize < (size + (size >> 4))) {
        try self.storedBlock(input.?, eof);
        return;
    }

    // Write Huffman table.
    try self.dynamicHeader(num_literals, num_distances, num_codegens, eof);

    // Write the tokens.
    try self.writeTokens(tokens, &self.literal_encoding.codes, &self.distance_encoding.codes);
}

const TotalIndexedTokens = struct {
    num_literals: u32,
    num_distances: u32,
};

/// Indexes a slice of tokens followed by an end_block_marker, and updates
/// literal_freq and distance_freq, and generates literal_encoding
/// and distance_encoding.
/// The number of literal and distance tokens is returned.
fn indexTokens(self: *BlockWriter, tokens: []const Token) TotalIndexedTokens {
    var num_literals: u32 = 0;
    var num_distances: u32 = 0;

    for (self.literal_freq, 0..) |_, i| {
        self.literal_freq[i] = 0;
    }
    for (self.distance_freq, 0..) |_, i| {
        self.distance_freq[i] = 0;
    }

    for (tokens) |t| {
        if (t.kind == Token.Kind.literal) {
            self.literal_freq[t.literal()] += 1;
            continue;
        }
        self.literal_freq[t.lengthCode()] += 1;
        self.distance_freq[t.distanceCode()] += 1;
    }
    // add end_block_marker token at the end
    self.literal_freq[HuffmanEncoder.end_block_marker] += 1;

    // get the number of literals
    num_literals = @as(u32, @intCast(self.literal_freq.len));
    while (self.literal_freq[num_literals - 1] == 0) {
        num_literals -= 1;
    }
    // get the number of distances
    num_distances = @as(u32, @intCast(self.distance_freq.len));
    while (num_distances > 0 and self.distance_freq[num_distances - 1] == 0) {
        num_distances -= 1;
    }
    if (num_distances == 0) {
        // We haven't found a single match. If we want to go with the dynamic encoding,
        // we should count at least one distance to be sure that the distance huffman tree could be encoded.
        self.distance_freq[0] = 1;
        num_distances = 1;
    }
    self.literal_encoding.generate(&self.literal_freq, 15);
    self.distance_encoding.generate(&self.distance_freq, 15);
    return TotalIndexedTokens{
        .num_literals = num_literals,
        .num_distances = num_distances,
    };
}

/// Writes a slice of tokens to the output followed by and end_block_marker.
/// codes for literal and distance encoding must be supplied.
fn writeTokens(
    self: *BlockWriter,
    tokens: []const Token,
    le_codes: []Compress.HuffCode,
    oe_codes: []Compress.HuffCode,
) Writer.Error!void {
    for (tokens) |t| {
        if (t.kind == Token.Kind.literal) {
            try self.writeCode(le_codes[t.literal()]);
            continue;
        }

        // Write the length
        const le = t.lengthEncoding();
        try self.writeCode(le_codes[le.code]);
        if (le.extra_bits > 0) {
            try self.bit_writer.writeBits(le.extra_length, le.extra_bits);
        }

        // Write the distance
        const oe = t.distanceEncoding();
        try self.writeCode(oe_codes[oe.code]);
        if (oe.extra_bits > 0) {
            try self.bit_writer.writeBits(oe.extra_distance, oe.extra_bits);
        }
    }
    // add end_block_marker at the end
    try self.writeCode(le_codes[HuffmanEncoder.end_block_marker]);
}

/// Encodes a block of bytes as either Huffman encoded literals or uncompressed bytes
/// if the results only gains very little from compression.
pub fn huffmanBlock(self: *BlockWriter, input: []const u8, eof: bool) Writer.Error!void {
    // Add everything as literals
    histogram(input, &self.literal_freq);

    self.literal_freq[HuffmanEncoder.end_block_marker] = 1;

    const num_literals = HuffmanEncoder.end_block_marker + 1;
    self.distance_freq[0] = 1;
    const num_distances = 1;

    self.literal_encoding.generate(&self.literal_freq, 15);

    // Figure out smallest code.
    // Always use dynamic Huffman or Store
    var num_codegens: u32 = 0;

    // Generate codegen and codegenFrequencies, which indicates how to encode
    // the literal_encoding and the distance_encoding.
    self.generateCodegen(
        num_literals,
        num_distances,
        &self.literal_encoding,
        &self.huff_distance,
    );
    self.codegen_encoding.generate(self.codegen_freq[0..], 7);
    const dynamic_size = self.dynamicSize(&self.literal_encoding, &self.huff_distance, 0);
    const size = dynamic_size.size;
    num_codegens = dynamic_size.num_codegens;

    // Store bytes, if we don't get a reasonable improvement.
    const stored_size_ret = storedSizeFits(input);
    const ssize = stored_size_ret.size;
    const storable = stored_size_ret.storable;

    if (storable and ssize < (size + (size >> 4))) {
        try self.storedBlock(input, eof);
        return;
    }

    // Huffman.
    try self.dynamicHeader(num_literals, num_distances, num_codegens, eof);
    const encoding = self.literal_encoding.codes[0..257];

    for (input) |t| {
        const c = encoding[t];
        try self.bit_writer.writeBits(c.code, c.len);
    }
    try self.writeCode(encoding[HuffmanEncoder.end_block_marker]);
}

fn histogram(b: []const u8, h: *[286]u16) void {
    // Clear histogram
    for (h, 0..) |_, i| {
        h[i] = 0;
    }

    var lh = h.*[0..256];
    for (b) |t| {
        lh[t] += 1;
    }
}
