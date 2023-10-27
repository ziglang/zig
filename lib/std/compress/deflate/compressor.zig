const std = @import("std");
const assert = std.debug.assert;
const fmt = std.fmt;
const io = std.io;
const math = std.math;
const mem = std.mem;

const Allocator = std.mem.Allocator;

const deflate_const = @import("deflate_const.zig");
const fast = @import("deflate_fast.zig");
const hm_bw = @import("huffman_bit_writer.zig");
const token = @import("token.zig");

pub const Compression = enum(i5) {
    /// huffman_only disables Lempel-Ziv match searching and only performs Huffman
    /// entropy encoding. This mode is useful in compressing data that has
    /// already been compressed with an LZ style algorithm (e.g. Snappy or LZ4)
    /// that lacks an entropy encoder. Compression gains are achieved when
    /// certain bytes in the input stream occur more frequently than others.
    ///
    /// Note that huffman_only produces a compressed output that is
    /// RFC 1951 compliant. That is, any valid DEFLATE decompressor will
    /// continue to be able to decompress this output.
    huffman_only = -2,
    /// Same as level_6
    default_compression = -1,
    /// Does not attempt any compression; only adds the necessary DEFLATE framing.
    no_compression = 0,
    /// Prioritizes speed over output size, based on Snappy's LZ77-style encoder
    best_speed = 1,
    level_2 = 2,
    level_3 = 3,
    level_4 = 4,
    level_5 = 5,
    level_6 = 6,
    level_7 = 7,
    level_8 = 8,
    /// Prioritizes smaller output size over speed
    best_compression = 9,
};

const log_window_size = 15;
const window_size = 1 << log_window_size;
const window_mask = window_size - 1;

// The LZ77 step produces a sequence of literal tokens and <length, offset>
// pair tokens. The offset is also known as distance. The underlying wire
// format limits the range of lengths and offsets. For example, there are
// 256 legitimate lengths: those in the range [3, 258]. This package's
// compressor uses a higher minimum match length, enabling optimizations
// such as finding matches via 32-bit loads and compares.
const base_match_length = deflate_const.base_match_length; // The smallest match length per the RFC section 3.2.5
const min_match_length = 4; // The smallest match length that the compressor actually emits
const max_match_length = deflate_const.max_match_length;
const base_match_offset = deflate_const.base_match_offset; // The smallest match offset
const max_match_offset = deflate_const.max_match_offset; // The largest match offset

// The maximum number of tokens we put into a single flate block, just to
// stop things from getting too large.
const max_flate_block_tokens = 1 << 14;
const max_store_block_size = deflate_const.max_store_block_size;
const hash_bits = 17; // After 17 performance degrades
const hash_size = 1 << hash_bits;
const hash_mask = (1 << hash_bits) - 1;
const max_hash_offset = 1 << 24;

const skip_never = math.maxInt(u32);

const CompressionLevel = struct {
    good: u16,
    lazy: u16,
    nice: u16,
    chain: u16,
    fast_skip_hashshing: u32,
};

fn levels(compression: Compression) CompressionLevel {
    switch (compression) {
        .no_compression,
        .best_speed, // best_speed uses a custom algorithm; see deflate_fast.zig
        .huffman_only,
        => return .{
            .good = 0,
            .lazy = 0,
            .nice = 0,
            .chain = 0,
            .fast_skip_hashshing = 0,
        },
        // For levels 2-3 we don't bother trying with lazy matches.
        .level_2 => return .{
            .good = 4,
            .lazy = 0,
            .nice = 16,
            .chain = 8,
            .fast_skip_hashshing = 5,
        },
        .level_3 => return .{
            .good = 4,
            .lazy = 0,
            .nice = 32,
            .chain = 32,
            .fast_skip_hashshing = 6,
        },

        // Levels 4-9 use increasingly more lazy matching and increasingly stringent conditions for
        // "good enough".
        .level_4 => return .{
            .good = 4,
            .lazy = 4,
            .nice = 16,
            .chain = 16,
            .fast_skip_hashshing = skip_never,
        },
        .level_5 => return .{
            .good = 8,
            .lazy = 16,
            .nice = 32,
            .chain = 32,
            .fast_skip_hashshing = skip_never,
        },
        .default_compression,
        .level_6,
        => return .{
            .good = 8,
            .lazy = 16,
            .nice = 128,
            .chain = 128,
            .fast_skip_hashshing = skip_never,
        },
        .level_7 => return .{
            .good = 8,
            .lazy = 32,
            .nice = 128,
            .chain = 256,
            .fast_skip_hashshing = skip_never,
        },
        .level_8 => return .{
            .good = 32,
            .lazy = 128,
            .nice = 258,
            .chain = 1024,
            .fast_skip_hashshing = skip_never,
        },
        .best_compression => return .{
            .good = 32,
            .lazy = 258,
            .nice = 258,
            .chain = 4096,
            .fast_skip_hashshing = skip_never,
        },
    }
}

// matchLen returns the number of matching bytes in a and b
// up to length 'max'. Both slices must be at least 'max'
// bytes in size.
fn matchLen(a: []u8, b: []u8, max: u32) u32 {
    var bounded_a = a[0..max];
    var bounded_b = b[0..max];
    for (bounded_a, 0..) |av, i| {
        if (bounded_b[i] != av) {
            return @as(u32, @intCast(i));
        }
    }
    return max;
}

const hash_mul = 0x1e35a7bd;

// hash4 returns a hash representation of the first 4 bytes
// of the supplied slice.
// The caller must ensure that b.len >= 4.
fn hash4(b: []u8) u32 {
    return ((@as(u32, b[3]) |
        @as(u32, b[2]) << 8 |
        @as(u32, b[1]) << 16 |
        @as(u32, b[0]) << 24) *% hash_mul) >> (32 - hash_bits);
}

// bulkHash4 will compute hashes using the same
// algorithm as hash4
fn bulkHash4(b: []u8, dst: []u32) u32 {
    if (b.len < min_match_length) {
        return 0;
    }
    var hb =
        @as(u32, b[3]) |
        @as(u32, b[2]) << 8 |
        @as(u32, b[1]) << 16 |
        @as(u32, b[0]) << 24;

    dst[0] = (hb *% hash_mul) >> (32 - hash_bits);
    var end = b.len - min_match_length + 1;
    var i: u32 = 1;
    while (i < end) : (i += 1) {
        hb = (hb << 8) | @as(u32, b[i + 3]);
        dst[i] = (hb *% hash_mul) >> (32 - hash_bits);
    }

    return hb;
}

pub const CompressorOptions = struct {
    level: Compression = .default_compression,
    dictionary: ?[]const u8 = null,
};

/// Returns a new Compressor compressing data at the given level.
/// Following zlib, levels range from 1 (best_speed) to 9 (best_compression);
/// higher levels typically run slower but compress more. Level 0
/// (no_compression) does not attempt any compression; it only adds the
/// necessary DEFLATE framing.
/// Level -1 (default_compression) uses the default compression level.
/// Level -2 (huffman_only) will use Huffman compression only, giving
/// a very fast compression for all types of input, but sacrificing considerable
/// compression efficiency.
///
/// `dictionary` is optional and initializes the new `Compressor` with a preset dictionary.
/// The returned Compressor behaves as if the dictionary had been written to it without producing
/// any compressed output. The compressed data written to hm_bw can only be decompressed by a
/// Decompressor initialized with the same dictionary.
///
/// The compressed data will be passed to the provided `writer`, see `writer()` and `write()`.
pub fn compressor(
    allocator: Allocator,
    writer: anytype,
    options: CompressorOptions,
) !Compressor(@TypeOf(writer)) {
    return Compressor(@TypeOf(writer)).init(allocator, writer, options);
}

pub fn Compressor(comptime WriterType: anytype) type {
    return struct {
        const Self = @This();

        /// A Writer takes data written to it and writes the compressed
        /// form of that data to an underlying writer.
        pub const Writer = io.Writer(*Self, Error, write);

        /// Returns a Writer that takes data written to it and writes the compressed
        /// form of that data to an underlying writer.
        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub const Error = WriterType.Error;

        allocator: Allocator,

        compression: Compression,
        compression_level: CompressionLevel,

        // Inner writer wrapped in a HuffmanBitWriter
        hm_bw: hm_bw.HuffmanBitWriter(WriterType) = undefined,
        bulk_hasher: *const fn ([]u8, []u32) u32,

        sync: bool, // requesting flush
        best_speed_enc: *fast.DeflateFast, // Encoder for best_speed

        // Input hash chains
        // hash_head[hashValue] contains the largest inputIndex with the specified hash value
        // If hash_head[hashValue] is within the current window, then
        // hash_prev[hash_head[hashValue] & window_mask] contains the previous index
        // with the same hash value.
        chain_head: u32,
        hash_head: []u32, // [hash_size]u32,
        hash_prev: []u32, // [window_size]u32,
        hash_offset: u32,

        // input window: unprocessed data is window[index..window_end]
        index: u32,
        window: []u8,
        window_end: usize,
        block_start: usize, // window index where current tokens start
        byte_available: bool, // if true, still need to process window[index-1].

        // queued output tokens
        tokens: []token.Token,
        tokens_count: u16,

        // deflate state
        length: u32,
        offset: u32,
        hash: u32,
        max_insert_index: usize,
        err: bool,

        // hash_match must be able to contain hashes for the maximum match length.
        hash_match: []u32, // [max_match_length - 1]u32,

        // dictionary
        dictionary: ?[]const u8,

        fn fillDeflate(self: *Self, b: []const u8) u32 {
            if (self.index >= 2 * window_size - (min_match_length + max_match_length)) {
                // shift the window by window_size
                mem.copyForwards(u8, self.window, self.window[window_size .. 2 * window_size]);
                self.index -= window_size;
                self.window_end -= window_size;
                if (self.block_start >= window_size) {
                    self.block_start -= window_size;
                } else {
                    self.block_start = math.maxInt(u32);
                }
                self.hash_offset += window_size;
                if (self.hash_offset > max_hash_offset) {
                    var delta = self.hash_offset - 1;
                    self.hash_offset -= delta;
                    self.chain_head -|= delta;

                    // Iterate over slices instead of arrays to avoid copying
                    // the entire table onto the stack (https://golang.org/issue/18625).
                    for (self.hash_prev, 0..) |v, i| {
                        if (v > delta) {
                            self.hash_prev[i] = @as(u32, @intCast(v - delta));
                        } else {
                            self.hash_prev[i] = 0;
                        }
                    }
                    for (self.hash_head, 0..) |v, i| {
                        if (v > delta) {
                            self.hash_head[i] = @as(u32, @intCast(v - delta));
                        } else {
                            self.hash_head[i] = 0;
                        }
                    }
                }
            }
            const n = std.compress.deflate.copy(self.window[self.window_end..], b);
            self.window_end += n;
            return @as(u32, @intCast(n));
        }

        fn writeBlock(self: *Self, tokens: []token.Token, index: usize) !void {
            if (index > 0) {
                var window: ?[]u8 = null;
                if (self.block_start <= index) {
                    window = self.window[self.block_start..index];
                }
                self.block_start = index;
                try self.hm_bw.writeBlock(tokens, false, window);
                return;
            }
            return;
        }

        // fillWindow will fill the current window with the supplied
        // dictionary and calculate all hashes.
        // This is much faster than doing a full encode.
        // Should only be used after a reset.
        fn fillWindow(self: *Self, in_b: []const u8) void {
            var b = in_b;
            // Do not fill window if we are in store-only mode (look at the fill() function to see
            // Compressions which use fillStore() instead of fillDeflate()).
            if (self.compression == .no_compression or
                self.compression == .huffman_only or
                self.compression == .best_speed)
            {
                return;
            }

            // fillWindow() must not be called with stale data
            assert(self.index == 0 and self.window_end == 0);

            // If we are given too much, cut it.
            if (b.len > window_size) {
                b = b[b.len - window_size ..];
            }
            // Add all to window.
            @memcpy(self.window[0..b.len], b);
            var n = b.len;

            // Calculate 256 hashes at the time (more L1 cache hits)
            var loops = (n + 256 - min_match_length) / 256;
            var j: usize = 0;
            while (j < loops) : (j += 1) {
                var index = j * 256;
                var end = index + 256 + min_match_length - 1;
                if (end > n) {
                    end = n;
                }
                var to_check = self.window[index..end];
                var dst_size = to_check.len - min_match_length + 1;

                if (dst_size <= 0) {
                    continue;
                }

                var dst = self.hash_match[0..dst_size];
                _ = self.bulk_hasher(to_check, dst);
                var new_h: u32 = 0;
                for (dst, 0..) |val, i| {
                    var di = i + index;
                    new_h = val;
                    var hh = &self.hash_head[new_h & hash_mask];
                    // Get previous value with the same hash.
                    // Our chain should point to the previous value.
                    self.hash_prev[di & window_mask] = hh.*;
                    // Set the head of the hash chain to us.
                    hh.* = @as(u32, @intCast(di + self.hash_offset));
                }
                self.hash = new_h;
            }
            // Update window information.
            self.window_end = n;
            self.index = @as(u32, @intCast(n));
        }

        const Match = struct {
            length: u32,
            offset: u32,
            ok: bool,
        };

        // Try to find a match starting at pos whose length is greater than prev_length.
        // We only look at self.compression_level.chain possibilities before giving up.
        fn findMatch(
            self: *Self,
            pos: u32,
            prev_head: u32,
            prev_length: u32,
            lookahead: u32,
        ) Match {
            var length: u32 = 0;
            var offset: u32 = 0;
            var ok: bool = false;

            var min_match_look: u32 = max_match_length;
            if (lookahead < min_match_look) {
                min_match_look = lookahead;
            }

            var win = self.window[0 .. pos + min_match_look];

            // We quit when we get a match that's at least nice long
            var nice = win.len - pos;
            if (self.compression_level.nice < nice) {
                nice = self.compression_level.nice;
            }

            // If we've got a match that's good enough, only look in 1/4 the chain.
            var tries = self.compression_level.chain;
            length = prev_length;
            if (length >= self.compression_level.good) {
                tries >>= 2;
            }

            var w_end = win[pos + length];
            var w_pos = win[pos..];
            var min_index = pos -| window_size;

            var i = prev_head;
            while (tries > 0) : (tries -= 1) {
                if (w_end == win[i + length]) {
                    var n = matchLen(win[i..], w_pos, min_match_look);

                    if (n > length and (n > min_match_length or pos - i <= 4096)) {
                        length = n;
                        offset = pos - i;
                        ok = true;
                        if (n >= nice) {
                            // The match is good enough that we don't try to find a better one.
                            break;
                        }
                        w_end = win[pos + n];
                    }
                }
                if (i == min_index) {
                    // hash_prev[i & window_mask] has already been overwritten, so stop now.
                    break;
                }

                if (@as(u32, @intCast(self.hash_prev[i & window_mask])) < self.hash_offset) {
                    break;
                }

                i = @as(u32, @intCast(self.hash_prev[i & window_mask])) - self.hash_offset;
                if (i < min_index) {
                    break;
                }
            }

            return Match{ .length = length, .offset = offset, .ok = ok };
        }

        fn writeStoredBlock(self: *Self, buf: []u8) !void {
            try self.hm_bw.writeStoredHeader(buf.len, false);
            try self.hm_bw.writeBytes(buf);
        }

        // encSpeed will compress and store the currently added data,
        // if enough has been accumulated or we at the end of the stream.
        fn encSpeed(self: *Self) !void {
            // We only compress if we have max_store_block_size.
            if (self.window_end < max_store_block_size) {
                if (!self.sync) {
                    return;
                }

                // Handle small sizes.
                if (self.window_end < 128) {
                    switch (self.window_end) {
                        0 => return,
                        1...16 => {
                            try self.writeStoredBlock(self.window[0..self.window_end]);
                        },
                        else => {
                            try self.hm_bw.writeBlockHuff(false, self.window[0..self.window_end]);
                            self.err = self.hm_bw.err;
                        },
                    }
                    self.window_end = 0;
                    self.best_speed_enc.reset();
                    return;
                }
            }
            // Encode the block.
            self.tokens_count = 0;
            self.best_speed_enc.encode(
                self.tokens,
                &self.tokens_count,
                self.window[0..self.window_end],
            );

            // If we removed less than 1/16th, Huffman compress the block.
            if (self.tokens_count > self.window_end - (self.window_end >> 4)) {
                try self.hm_bw.writeBlockHuff(false, self.window[0..self.window_end]);
            } else {
                try self.hm_bw.writeBlockDynamic(
                    self.tokens[0..self.tokens_count],
                    false,
                    self.window[0..self.window_end],
                );
            }
            self.err = self.hm_bw.err;
            self.window_end = 0;
        }

        fn initDeflate(self: *Self) !void {
            self.window = try self.allocator.alloc(u8, 2 * window_size);
            self.hash_offset = 1;
            self.tokens = try self.allocator.alloc(token.Token, max_flate_block_tokens);
            self.tokens_count = 0;
            @memset(self.tokens, 0);
            self.length = min_match_length - 1;
            self.offset = 0;
            self.byte_available = false;
            self.index = 0;
            self.hash = 0;
            self.chain_head = 0;
            self.bulk_hasher = bulkHash4;
        }

        fn deflate(self: *Self) !void {
            if (self.window_end - self.index < min_match_length + max_match_length and !self.sync) {
                return;
            }

            self.max_insert_index = self.window_end -| (min_match_length - 1);
            if (self.index < self.max_insert_index) {
                self.hash = hash4(self.window[self.index .. self.index + min_match_length]);
            }

            while (true) {
                assert(self.index <= self.window_end);

                var lookahead = self.window_end -| self.index;
                if (lookahead < min_match_length + max_match_length) {
                    if (!self.sync) {
                        break;
                    }
                    assert(self.index <= self.window_end);

                    if (lookahead == 0) {
                        // Flush current output block if any.
                        if (self.byte_available) {
                            // There is still one pending token that needs to be flushed
                            self.tokens[self.tokens_count] = token.literalToken(@as(u32, @intCast(self.window[self.index - 1])));
                            self.tokens_count += 1;
                            self.byte_available = false;
                        }
                        if (self.tokens.len > 0) {
                            try self.writeBlock(self.tokens[0..self.tokens_count], self.index);
                            self.tokens_count = 0;
                        }
                        break;
                    }
                }
                if (self.index < self.max_insert_index) {
                    // Update the hash
                    self.hash = hash4(self.window[self.index .. self.index + min_match_length]);
                    var hh = &self.hash_head[self.hash & hash_mask];
                    self.chain_head = @as(u32, @intCast(hh.*));
                    self.hash_prev[self.index & window_mask] = @as(u32, @intCast(self.chain_head));
                    hh.* = @as(u32, @intCast(self.index + self.hash_offset));
                }
                var prev_length = self.length;
                var prev_offset = self.offset;
                self.length = min_match_length - 1;
                self.offset = 0;
                var min_index = self.index -| window_size;

                if (self.hash_offset <= self.chain_head and
                    self.chain_head - self.hash_offset >= min_index and
                    (self.compression_level.fast_skip_hashshing != skip_never and
                    lookahead > min_match_length - 1 or
                    self.compression_level.fast_skip_hashshing == skip_never and
                    lookahead > prev_length and
                    prev_length < self.compression_level.lazy))
                {
                    {
                        var fmatch = self.findMatch(
                            self.index,
                            self.chain_head -| self.hash_offset,
                            min_match_length - 1,
                            @as(u32, @intCast(lookahead)),
                        );
                        if (fmatch.ok) {
                            self.length = fmatch.length;
                            self.offset = fmatch.offset;
                        }
                    }
                }
                if (self.compression_level.fast_skip_hashshing != skip_never and
                    self.length >= min_match_length or
                    self.compression_level.fast_skip_hashshing == skip_never and
                    prev_length >= min_match_length and
                    self.length <= prev_length)
                {
                    // There was a match at the previous step, and the current match is
                    // not better. Output the previous match.
                    if (self.compression_level.fast_skip_hashshing != skip_never) {
                        self.tokens[self.tokens_count] = token.matchToken(@as(u32, @intCast(self.length - base_match_length)), @as(u32, @intCast(self.offset - base_match_offset)));
                        self.tokens_count += 1;
                    } else {
                        self.tokens[self.tokens_count] = token.matchToken(
                            @as(u32, @intCast(prev_length - base_match_length)),
                            @as(u32, @intCast(prev_offset -| base_match_offset)),
                        );
                        self.tokens_count += 1;
                    }
                    // Insert in the hash table all strings up to the end of the match.
                    // index and index-1 are already inserted. If there is not enough
                    // lookahead, the last two strings are not inserted into the hash
                    // table.
                    if (self.length <= self.compression_level.fast_skip_hashshing) {
                        var newIndex: u32 = 0;
                        if (self.compression_level.fast_skip_hashshing != skip_never) {
                            newIndex = self.index + self.length;
                        } else {
                            newIndex = self.index + prev_length - 1;
                        }
                        var index = self.index;
                        index += 1;
                        while (index < newIndex) : (index += 1) {
                            if (index < self.max_insert_index) {
                                self.hash = hash4(self.window[index .. index + min_match_length]);
                                // Get previous value with the same hash.
                                // Our chain should point to the previous value.
                                var hh = &self.hash_head[self.hash & hash_mask];
                                self.hash_prev[index & window_mask] = hh.*;
                                // Set the head of the hash chain to us.
                                hh.* = @as(u32, @intCast(index + self.hash_offset));
                            }
                        }
                        self.index = index;

                        if (self.compression_level.fast_skip_hashshing == skip_never) {
                            self.byte_available = false;
                            self.length = min_match_length - 1;
                        }
                    } else {
                        // For matches this long, we don't bother inserting each individual
                        // item into the table.
                        self.index += self.length;
                        if (self.index < self.max_insert_index) {
                            self.hash = hash4(self.window[self.index .. self.index + min_match_length]);
                        }
                    }
                    if (self.tokens_count == max_flate_block_tokens) {
                        // The block includes the current character
                        try self.writeBlock(self.tokens[0..self.tokens_count], self.index);
                        self.tokens_count = 0;
                    }
                } else {
                    if (self.compression_level.fast_skip_hashshing != skip_never or self.byte_available) {
                        var i = self.index -| 1;
                        if (self.compression_level.fast_skip_hashshing != skip_never) {
                            i = self.index;
                        }
                        self.tokens[self.tokens_count] = token.literalToken(@as(u32, @intCast(self.window[i])));
                        self.tokens_count += 1;
                        if (self.tokens_count == max_flate_block_tokens) {
                            try self.writeBlock(self.tokens[0..self.tokens_count], i + 1);
                            self.tokens_count = 0;
                        }
                    }
                    self.index += 1;
                    if (self.compression_level.fast_skip_hashshing == skip_never) {
                        self.byte_available = true;
                    }
                }
            }
        }

        fn fillStore(self: *Self, b: []const u8) u32 {
            const n = std.compress.deflate.copy(self.window[self.window_end..], b);
            self.window_end += n;
            return @as(u32, @intCast(n));
        }

        fn store(self: *Self) !void {
            if (self.window_end > 0 and (self.window_end == max_store_block_size or self.sync)) {
                try self.writeStoredBlock(self.window[0..self.window_end]);
                self.window_end = 0;
            }
        }

        // storeHuff compresses and stores the currently added data
        // when the self.window is full or we are at the end of the stream.
        fn storeHuff(self: *Self) !void {
            if (self.window_end < self.window.len and !self.sync or self.window_end == 0) {
                return;
            }
            try self.hm_bw.writeBlockHuff(false, self.window[0..self.window_end]);
            self.err = self.hm_bw.err;
            self.window_end = 0;
        }

        pub fn bytesWritten(self: *Self) usize {
            return self.hm_bw.bytes_written;
        }

        /// Writes the compressed form of `input` to the underlying writer.
        pub fn write(self: *Self, input: []const u8) !usize {
            var buf = input;

            // writes data to hm_bw, which will eventually write the
            // compressed form of data to its underlying writer.
            while (buf.len > 0) {
                try self.step();
                var filled = self.fill(buf);
                buf = buf[filled..];
            }

            return input.len;
        }

        /// Flushes any pending data to the underlying writer.
        /// It is useful mainly in compressed network protocols, to ensure that
        /// a remote reader has enough data to reconstruct a packet.
        /// Flush does not return until the data has been written.
        /// Calling `flush()` when there is no pending data still causes the Writer
        /// to emit a sync marker of at least 4 bytes.
        /// If the underlying writer returns an error, `flush()` returns that error.
        ///
        /// In the terminology of the zlib library, Flush is equivalent to Z_SYNC_FLUSH.
        pub fn flush(self: *Self) !void {
            self.sync = true;
            try self.step();
            try self.hm_bw.writeStoredHeader(0, false);
            try self.hm_bw.flush();
            self.sync = false;
            return;
        }

        fn step(self: *Self) !void {
            switch (self.compression) {
                .no_compression => return self.store(),
                .huffman_only => return self.storeHuff(),
                .best_speed => return self.encSpeed(),
                .default_compression,
                .level_2,
                .level_3,
                .level_4,
                .level_5,
                .level_6,
                .level_7,
                .level_8,
                .best_compression,
                => return self.deflate(),
            }
        }

        fn fill(self: *Self, b: []const u8) u32 {
            switch (self.compression) {
                .no_compression => return self.fillStore(b),
                .huffman_only => return self.fillStore(b),
                .best_speed => return self.fillStore(b),
                .default_compression,
                .level_2,
                .level_3,
                .level_4,
                .level_5,
                .level_6,
                .level_7,
                .level_8,
                .best_compression,
                => return self.fillDeflate(b),
            }
        }

        fn init(
            allocator: Allocator,
            in_writer: WriterType,
            options: CompressorOptions,
        ) !Self {
            var s = Self{
                .allocator = undefined,
                .compression = undefined,
                .compression_level = undefined,
                .hm_bw = undefined, // HuffmanBitWriter
                .bulk_hasher = undefined,
                .sync = false,
                .best_speed_enc = undefined, // Best speed encoder
                .chain_head = 0,
                .hash_head = undefined,
                .hash_prev = undefined, // previous hash
                .hash_offset = 0,
                .index = 0,
                .window = undefined,
                .window_end = 0,
                .block_start = 0,
                .byte_available = false,
                .tokens = undefined,
                .tokens_count = 0,
                .length = 0,
                .offset = 0,
                .hash = 0,
                .max_insert_index = 0,
                .err = false, // Error
                .hash_match = undefined,
                .dictionary = options.dictionary,
            };

            s.hm_bw = try hm_bw.huffmanBitWriter(allocator, in_writer);
            s.allocator = allocator;

            s.hash_head = try allocator.alloc(u32, hash_size);
            s.hash_prev = try allocator.alloc(u32, window_size);
            s.hash_match = try allocator.alloc(u32, max_match_length - 1);
            @memset(s.hash_head, 0);
            @memset(s.hash_prev, 0);
            @memset(s.hash_match, 0);

            switch (options.level) {
                .no_compression => {
                    s.compression = options.level;
                    s.compression_level = levels(options.level);
                    s.window = try allocator.alloc(u8, max_store_block_size);
                    s.tokens = try allocator.alloc(token.Token, 0);
                },
                .huffman_only => {
                    s.compression = options.level;
                    s.compression_level = levels(options.level);
                    s.window = try allocator.alloc(u8, max_store_block_size);
                    s.tokens = try allocator.alloc(token.Token, 0);
                },
                .best_speed => {
                    s.compression = options.level;
                    s.compression_level = levels(options.level);
                    s.window = try allocator.alloc(u8, max_store_block_size);
                    s.tokens = try allocator.alloc(token.Token, max_store_block_size);
                    s.best_speed_enc = try allocator.create(fast.DeflateFast);
                    s.best_speed_enc.* = fast.deflateFast();
                    try s.best_speed_enc.init(allocator);
                },
                .default_compression => {
                    s.compression = .level_6;
                    s.compression_level = levels(.level_6);
                    try s.initDeflate();
                    if (options.dictionary != null) {
                        s.fillWindow(options.dictionary.?);
                    }
                },
                .level_2,
                .level_3,
                .level_4,
                .level_5,
                .level_6,
                .level_7,
                .level_8,
                .best_compression,
                => {
                    s.compression = options.level;
                    s.compression_level = levels(options.level);
                    try s.initDeflate();
                    if (options.dictionary != null) {
                        s.fillWindow(options.dictionary.?);
                    }
                },
            }
            return s;
        }

        /// Release all allocated memory.
        pub fn deinit(self: *Self) void {
            self.hm_bw.deinit();
            self.allocator.free(self.window);
            self.allocator.free(self.tokens);
            self.allocator.free(self.hash_head);
            self.allocator.free(self.hash_prev);
            self.allocator.free(self.hash_match);
            if (self.compression == .best_speed) {
                self.best_speed_enc.deinit();
                self.allocator.destroy(self.best_speed_enc);
            }
        }

        /// Reset discards the inner writer's state and replace the inner writer with new_writer.
        /// new_writer must be of the same type as the previous writer.
        pub fn reset(self: *Self, new_writer: WriterType) void {
            self.hm_bw.reset(new_writer);
            self.sync = false;
            switch (self.compression) {
                // Reset window
                .no_compression => self.window_end = 0,
                // Reset window, tokens, and encoder
                .best_speed => {
                    self.window_end = 0;
                    self.tokens_count = 0;
                    self.best_speed_enc.reset();
                },
                // Reset everything and reinclude the dictionary if there is one
                .huffman_only,
                .default_compression,
                .level_2,
                .level_3,
                .level_4,
                .level_5,
                .level_6,
                .level_7,
                .level_8,
                .best_compression,
                => {
                    self.chain_head = 0;
                    @memset(self.hash_head, 0);
                    @memset(self.hash_prev, 0);
                    self.hash_offset = 1;
                    self.index = 0;
                    self.window_end = 0;
                    self.block_start = 0;
                    self.byte_available = false;
                    self.tokens_count = 0;
                    self.length = min_match_length - 1;
                    self.offset = 0;
                    self.hash = 0;
                    self.max_insert_index = 0;

                    if (self.dictionary != null) {
                        self.fillWindow(self.dictionary.?);
                    }
                },
            }
        }

        /// Writes any pending data to the underlying writer.
        pub fn close(self: *Self) !void {
            self.sync = true;
            try self.step();
            try self.hm_bw.writeStoredHeader(0, true);
            try self.hm_bw.flush();
            return;
        }
    };
}

// tests

const expect = std.testing.expect;
const testing = std.testing;

const ArrayList = std.ArrayList;

const DeflateTest = struct {
    in: []const u8,
    level: Compression,
    out: []const u8,
};

var deflate_tests = [_]DeflateTest{
    // Level 0
    .{
        .in = &[_]u8{},
        .level = .no_compression,
        .out = &[_]u8{ 1, 0, 0, 255, 255 },
    },

    // Level -1
    .{
        .in = &[_]u8{0x11},
        .level = .default_compression,
        .out = &[_]u8{ 18, 4, 4, 0, 0, 255, 255 },
    },
    .{
        .in = &[_]u8{0x11},
        .level = .level_6,
        .out = &[_]u8{ 18, 4, 4, 0, 0, 255, 255 },
    },

    // Level 4
    .{
        .in = &[_]u8{0x11},
        .level = .level_4,
        .out = &[_]u8{ 18, 4, 4, 0, 0, 255, 255 },
    },

    // Level 0
    .{
        .in = &[_]u8{0x11},
        .level = .no_compression,
        .out = &[_]u8{ 0, 1, 0, 254, 255, 17, 1, 0, 0, 255, 255 },
    },
    .{
        .in = &[_]u8{ 0x11, 0x12 },
        .level = .no_compression,
        .out = &[_]u8{ 0, 2, 0, 253, 255, 17, 18, 1, 0, 0, 255, 255 },
    },
    .{
        .in = &[_]u8{ 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11 },
        .level = .no_compression,
        .out = &[_]u8{ 0, 8, 0, 247, 255, 17, 17, 17, 17, 17, 17, 17, 17, 1, 0, 0, 255, 255 },
    },

    // Level 2
    .{
        .in = &[_]u8{},
        .level = .level_2,
        .out = &[_]u8{ 1, 0, 0, 255, 255 },
    },
    .{
        .in = &[_]u8{0x11},
        .level = .level_2,
        .out = &[_]u8{ 18, 4, 4, 0, 0, 255, 255 },
    },
    .{
        .in = &[_]u8{ 0x11, 0x12 },
        .level = .level_2,
        .out = &[_]u8{ 18, 20, 2, 4, 0, 0, 255, 255 },
    },
    .{
        .in = &[_]u8{ 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11 },
        .level = .level_2,
        .out = &[_]u8{ 18, 132, 2, 64, 0, 0, 0, 255, 255 },
    },

    // Level 9
    .{
        .in = &[_]u8{},
        .level = .best_compression,
        .out = &[_]u8{ 1, 0, 0, 255, 255 },
    },
    .{
        .in = &[_]u8{0x11},
        .level = .best_compression,
        .out = &[_]u8{ 18, 4, 4, 0, 0, 255, 255 },
    },
    .{
        .in = &[_]u8{ 0x11, 0x12 },
        .level = .best_compression,
        .out = &[_]u8{ 18, 20, 2, 4, 0, 0, 255, 255 },
    },
    .{
        .in = &[_]u8{ 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x11 },
        .level = .best_compression,
        .out = &[_]u8{ 18, 132, 2, 64, 0, 0, 0, 255, 255 },
    },
};

test "deflate" {
    for (deflate_tests) |dt| {
        var output = ArrayList(u8).init(testing.allocator);
        defer output.deinit();

        var comp = try compressor(testing.allocator, output.writer(), .{ .level = dt.level });
        _ = try comp.write(dt.in);
        try comp.close();
        comp.deinit();

        try testing.expectEqualSlices(u8, dt.out, output.items);
    }
}

test "bulkHash4" {
    for (deflate_tests) |x| {
        if (x.out.len < min_match_length) {
            continue;
        }
        // double the test data
        var out = try testing.allocator.alloc(u8, x.out.len * 2);
        defer testing.allocator.free(out);
        @memcpy(out[0..x.out.len], x.out);
        @memcpy(out[x.out.len..], x.out);

        var j: usize = 4;
        while (j < out.len) : (j += 1) {
            var y = out[0..j];

            var dst = try testing.allocator.alloc(u32, y.len - min_match_length + 1);
            defer testing.allocator.free(dst);

            _ = bulkHash4(y, dst);
            for (dst, 0..) |got, i| {
                var want = hash4(y[i..]);
                try testing.expectEqual(want, got);
            }
        }
    }
}
