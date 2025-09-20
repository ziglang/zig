//! Allocates statically ~224K (128K lookup, 96K tokens).
//!
//! The source of an `error.WriteFailed` is always the backing writer. After an
//! `error.WriteFailed`, the `.writer` becomes `.failing` and is unrecoverable.
//! After a `flush`, the writer also becomes `.failing` since the stream has
//! been finished. This behavior also applies to `Raw` and `Huffman`.

// Implementation details:
//   A chained hash table is used to find matches. `drain` always preserves `flate.history_len`
//   bytes to use as a history and avoids tokenizing the final bytes since they can be part of
//   a longer match with unwritten bytes (unless it is a `flush`). The minimum match searched
//   for is of length `seq_bytes`. If a match is made, a longer match is also checked for at
//   the next byte (lazy matching) if the last match does not meet the `Options.lazy` threshold.
//
//   Up to `block_token` tokens are accumalated in `buffered_tokens` and are outputted in
//   `write_block` which determines the optimal block type and frequencies.

const builtin = @import("builtin");
const std = @import("std");
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const Io = std.Io;
const Writer = Io.Writer;

const Compress = @This();
const token = @import("token.zig");
const flate = @import("../flate.zig");

/// Until #104 is implemented, a ?u15 takes 4 bytes, which is unacceptable
/// as it doubles the size of this already massive structure.
///
/// Also, there are no `to` / `from` methods because LLVM 21 does not
/// optimize away the conversion from and to `?u15`.
const PackedOptionalU15 = packed struct(u16) {
    value: u15,
    is_null: bool,

    pub fn int(p: PackedOptionalU15) u16 {
        return @bitCast(p);
    }

    pub const null_bit: PackedOptionalU15 = .{ .value = 0, .is_null = true };
};

/// After `flush` is called, all vtable calls with result in `error.WriteFailed.`
writer: Writer,
has_history: bool,
bit_writer: BitWriter,
buffered_tokens: struct {
    /// List of `TokenBufferEntryHeader`s and their trailing data.
    list: [@as(usize, block_tokens) * 3]u8,
    pos: u32,
    n: u16,
    lit_freqs: [286]u16,
    dist_freqs: [30]u16,

    pub const empty: @This() = .{
        .list = undefined,
        .pos = 0,
        .n = 0,
        .lit_freqs = @splat(0),
        .dist_freqs = @splat(0),
    };
},
lookup: struct {
    /// Indexes are the hashes of four-bytes sequences.
    ///
    /// Values are the positions in `chain` of the previous four bytes with the same hash.
    head: [1 << lookup_hash_bits]PackedOptionalU15,
    /// Values are the non-zero number of bytes backwards in the history with the same hash.
    ///
    /// The relationship of chain indexes and bytes relative to the latest history byte is
    /// `chain_pos -% chain_index = history_index`.
    chain: [32768]PackedOptionalU15,
    /// The index in `chain` which is of the newest byte of the history.
    chain_pos: u15,
},
container: flate.Container,
hasher: flate.Container.Hasher,
opts: Options,

const BitWriter = struct {
    output: *Writer,
    buffered: u7,
    buffered_n: u3,

    pub fn init(w: *Writer) BitWriter {
        return .{
            .output = w,
            .buffered = 0,
            .buffered_n = 0,
        };
    }

    /// Asserts `bits` is zero-extended
    pub fn write(b: *BitWriter, bits: u56, n: u6) Writer.Error!void {
        assert(@as(u8, b.buffered) >> b.buffered_n == 0);
        assert(@as(u57, bits) >> n == 0); // n may be 56 so u57 is needed
        const combined = @shlExact(@as(u64, bits), b.buffered_n) | b.buffered;
        const combined_bits = @as(u6, b.buffered_n) + n;

        const out = try b.output.writableSliceGreedy(8);
        mem.writeInt(u64, out[0..8], combined, .little);
        b.output.advance(combined_bits / 8);

        b.buffered_n = @truncate(combined_bits);
        b.buffered = @intCast(combined >> (combined_bits - b.buffered_n));
    }

    /// Assserts one byte can be written to `b.otuput` without rebasing.
    pub fn byteAlign(b: *BitWriter) void {
        b.output.unusedCapacitySlice()[0] = b.buffered;
        b.output.advance(@intFromBool(b.buffered_n != 0));
        b.buffered = 0;
        b.buffered_n = 0;
    }

    pub fn writeClen(
        b: *BitWriter,
        hclen: u4,
        clen_values: []u8,
        clen_extra: []u8,
        clen_codes: [19]u16,
        clen_bits: [19]u4,
    ) Writer.Error!void {
        // Write the first four clen entries seperately since they are always present,
        // and writing them all at once takes too many bits.
        try b.write(clen_bits[token.codegen_order[0]] |
            @shlExact(@as(u6, clen_bits[token.codegen_order[1]]), 3) |
            @shlExact(@as(u9, clen_bits[token.codegen_order[2]]), 6) |
            @shlExact(@as(u12, clen_bits[token.codegen_order[3]]), 9), 12);

        var i = hclen;
        var clen_bits_table: u45 = 0;
        while (i != 0) {
            i -= 1;
            clen_bits_table <<= 3;
            clen_bits_table |= clen_bits[token.codegen_order[4..][i]];
        }
        try b.write(clen_bits_table, @as(u6, hclen) * 3);

        for (clen_values, clen_extra) |value, extra| {
            try b.write(
                clen_codes[value] | @shlExact(@as(u16, extra), clen_bits[value]),
                clen_bits[value] + @as(u3, switch (value) {
                    0...15 => 0,
                    16 => 2,
                    17 => 3,
                    18 => 7,
                    else => unreachable,
                }),
            );
        }
    }
};

/// Number of tokens to accumulate before outputing as a block.
/// The maximum value is `math.maxInt(u16) - 1` since one token is reserved for end-of-block.
const block_tokens: u16 = 1 << 15;
const lookup_hash_bits = 15;
const Hash = u16; // `u[lookup_hash_bits]` is not used due to worse optimization (with LLVM 21)
const seq_bytes = 3; // not intended to be changed
const Seq = std.meta.Int(.unsigned, seq_bytes * 8);

const TokenBufferEntryHeader = packed struct(u16) {
    kind: enum(u1) {
        /// Followed by non-zero `data` byte literals.
        bytes,
        /// Followed by the length as a byte
        match,
    },
    data: u15,
};

const BlockHeader = packed struct(u3) {
    final: bool,
    kind: enum(u2) { stored, fixed, dynamic, _ },

    pub fn int(h: BlockHeader) u3 {
        return @bitCast(h);
    }

    pub const Dynamic = packed struct(u17) {
        regular: BlockHeader,
        hlit: u5,
        hdist: u5,
        hclen: u4,

        pub fn int(h: Dynamic) u17 {
            return @bitCast(h);
        }
    };
};

fn outputMatch(c: *Compress, dist: u15, len: u8) Writer.Error!void {
    // This must come first. Instead of ensuring a full block is never left buffered,
    // draining it is defered to allow end of stream to be indicated.
    if (c.buffered_tokens.n == block_tokens) {
        @branchHint(.unlikely); // LLVM 21 optimizes this branch as the more likely without
        try c.writeBlock(false);
    }
    const header: TokenBufferEntryHeader = .{ .kind = .match, .data = dist };
    c.buffered_tokens.list[c.buffered_tokens.pos..][0..2].* = @bitCast(header);
    c.buffered_tokens.list[c.buffered_tokens.pos + 2] = len;
    c.buffered_tokens.pos += 3;
    c.buffered_tokens.n += 1;

    c.buffered_tokens.lit_freqs[@as(usize, 257) + token.LenCode.fromVal(len).toInt()] += 1;
    c.buffered_tokens.dist_freqs[token.DistCode.fromVal(dist).toInt()] += 1;
}

fn outputBytes(c: *Compress, bytes: []const u8) Writer.Error!void {
    var remaining = bytes;
    while (remaining.len != 0) {
        if (c.buffered_tokens.n == block_tokens) {
            @branchHint(.unlikely); // LLVM 21 optimizes this branch as the more likely without
            try c.writeBlock(false);
        }

        const n = @min(remaining.len, block_tokens - c.buffered_tokens.n, math.maxInt(u15));
        assert(n != 0);
        const header: TokenBufferEntryHeader = .{ .kind = .bytes, .data = n };
        c.buffered_tokens.list[c.buffered_tokens.pos..][0..2].* = @bitCast(header);
        @memcpy(c.buffered_tokens.list[c.buffered_tokens.pos + 2 ..][0..n], remaining[0..n]);
        c.buffered_tokens.pos += @as(u32, 2) + n;
        c.buffered_tokens.n += n;

        for (remaining[0..n]) |b| {
            c.buffered_tokens.lit_freqs[b] += 1;
        }
        remaining = remaining[n..];
    }
}

fn hash(x: u32) Hash {
    return @intCast((x *% 0x9E3779B1) >> (32 - lookup_hash_bits));
}

/// Trades between speed and compression size.
///
/// Default paramaters are [taken from zlib]
/// (https://github.com/madler/zlib/blob/v1.3.1/deflate.c#L112)
pub const Options = struct {
    /// Perform less lookups when a match of at least this length has been found.
    good: u16,
    /// Stop when a match of at least this length has been found.
    nice: u16,
    /// Don't attempt a lazy match find when a match of at least this length has been found.
    lazy: u16,
    /// Check this many previous locations with the same hash for longer matches.
    chain: u16,

    // zig fmt: off
    pub const level_1: Options = .{ .good =  4, .nice =   8, .lazy =   0, .chain =    4 };
    pub const level_2: Options = .{ .good =  4, .nice =  16, .lazy =   0, .chain =    8 };
    pub const level_3: Options = .{ .good =  4, .nice =  32, .lazy =   0, .chain =   32 };
    pub const level_4: Options = .{ .good =  4, .nice =  16, .lazy =   4, .chain =   16 };
    pub const level_5: Options = .{ .good =  8, .nice =  32, .lazy =  16, .chain =   32 };
    pub const level_6: Options = .{ .good =  8, .nice = 128, .lazy =  16, .chain =  128 };
    pub const level_7: Options = .{ .good =  8, .nice = 128, .lazy =  32, .chain =  256 };
    pub const level_8: Options = .{ .good = 32, .nice = 258, .lazy = 128, .chain = 1024 };
    pub const level_9: Options = .{ .good = 32, .nice = 258, .lazy = 258, .chain = 4096 };
     // zig fmt: on
    pub const fastest = level_1;
    pub const default = level_6;
    pub const best = level_9;
};

/// It is asserted `buffer` is least `flate.max_history_len` bytes.
/// It is asserted `output` has a capacity of at least 8 bytes.
pub fn init(
    output: *Writer,
    buffer: []u8,
    container: flate.Container,
    opts: Options,
) Writer.Error!Compress {
    assert(output.buffer.len > 8);
    assert(buffer.len >= flate.max_window_len);

    // note that disallowing some of these simplifies matching logic
    assert(opts.chain != 0); // use `Huffman`, disallowing this simplies matching
    assert(opts.good >= 3 and opts.nice >= 3); // a match will (usually) not be found
    assert(opts.good <= 258 and opts.nice <= 258); // a longer match will not be found
    assert(opts.lazy <= opts.nice); // a longer match will (usually) not be found
    if (opts.good <= opts.lazy) assert(opts.chain >= 1 << 2); // chain can be reduced to zero

    try output.writeAll(container.header());
    return .{
        .writer = .{
            .buffer = buffer,
            .vtable = &.{
                .drain = drain,
                .flush = flush,
                .rebase = rebase,
            },
        },
        .has_history = false,
        .bit_writer = .init(output),
        .buffered_tokens = .empty,
        .lookup = .{
            // init `value` is max so there is 0xff pattern
            .head = @splat(.{ .value = math.maxInt(u15), .is_null = true }),
            .chain = undefined,
            .chain_pos = math.maxInt(u15),
        },
        .container = container,
        .opts = opts,
        .hasher = .init(container),
    };
}

fn drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
    errdefer w.* = .failing;
    // There may have not been enough space in the buffer and the write was sent directly here.
    // However, it is required that all data goes through the buffer to keep a history.
    //
    // Additionally, ensuring the buffer is always full ensures there is always a full history
    // after.
    const data_n = w.buffer.len - w.end;
    _ = w.fixedDrain(data, splat) catch {};
    assert(w.end == w.buffer.len);
    try rebaseInner(w, 0, 1, false);
    return data_n;
}

fn flush(w: *Writer) Writer.Error!void {
    defer w.* = .failing;
    const c: *Compress = @fieldParentPtr("writer", w);
    try rebaseInner(w, 0, w.buffer.len - flate.history_len, true);
    try c.bit_writer.output.rebase(0, 1);
    c.bit_writer.byteAlign();
    try c.hasher.writeFooter(c.bit_writer.output);
}

fn rebase(w: *Writer, preserve: usize, capacity: usize) Writer.Error!void {
    return rebaseInner(w, preserve, capacity, false);
}

pub const rebase_min_preserve = flate.history_len;
pub const rebase_reserved_capacity = (token.max_length + 1) + seq_bytes;

fn rebaseInner(w: *Writer, preserve: usize, capacity: usize, eos: bool) Writer.Error!void {
    if (!eos) {
        assert(@max(preserve, rebase_min_preserve) + (capacity + rebase_reserved_capacity) <= w.buffer.len);
        assert(w.end >= flate.history_len + rebase_reserved_capacity); // Above assert should
        // fail since rebase is only called when `capacity` is not present. This assertion is
        // important because a full history is required at the end.
    } else {
        assert(preserve == 0 and capacity == w.buffer.len - flate.history_len);
    }

    const c: *Compress = @fieldParentPtr("writer", w);
    const buffered = w.buffered();

    const start = @as(usize, flate.history_len) * @intFromBool(c.has_history);
    const lit_end: usize = if (!eos)
        buffered.len - rebase_reserved_capacity - (preserve -| flate.history_len)
    else
        buffered.len -| (seq_bytes - 1);

    var i = start;
    var last_unmatched = i;
    // Read from `w.buffer` instead of `buffered` since the latter may not
    // have enough bytes. If this is the case, this variable is not used.
    var seq: Seq = mem.readInt(
        std.meta.Int(.unsigned, (seq_bytes - 1) * 8),
        w.buffer[i..][0 .. seq_bytes - 1],
        .big,
    );
    if (buffered[i..].len < seq_bytes - 1) {
        @branchHint(.unlikely);
        assert(eos);
        seq = undefined;
        assert(i >= lit_end);
    }

    while (i < lit_end) {
        var match_start = i;
        seq <<= 8;
        seq |= buffered[i + (seq_bytes - 1)];
        var match = c.matchAndAddHash(i, hash(seq), token.min_length - 1, c.opts.chain, c.opts.good);
        i += 1;
        if (match.len < token.min_length) continue;

        var match_unadded = match.len - 1;
        lazy: {
            if (match.len >= c.opts.lazy) break :lazy;
            if (match.len >= c.writer.buffered()[i..].len) {
                @branchHint(.unlikely); // Only end of stream
                break :lazy;
            }

            var chain = c.opts.chain;
            var good = c.opts.good;
            if (match.len >= good) {
                chain >>= 2;
                good = math.maxInt(u8); // Reduce only once
            }

            seq <<= 8;
            seq |= buffered[i + (seq_bytes - 1)];
            const lazy = c.matchAndAddHash(i, hash(seq), match.len, chain, good);
            match_unadded -= 1;
            i += 1;

            if (lazy.len > match.len) {
                match_start += 1;
                match = lazy;
                match_unadded = match.len - 1;
            }
        }

        assert(i + match_unadded == match_start + match.len);
        assert(mem.eql(
            u8,
            buffered[match_start..][0..match.len],
            buffered[match_start - 1 - match.dist ..][0..match.len],
        )); // This assert also seems to help codegen.

        try c.outputBytes(buffered[last_unmatched..match_start]);
        try c.outputMatch(@intCast(match.dist), @intCast(match.len - 3));

        last_unmatched = match_start + match.len;
        if (last_unmatched + seq_bytes >= w.end) {
            @branchHint(.unlikely);
            assert(eos);
            i = undefined;
            break;
        }

        while (true) {
            seq <<= 8;
            seq |= buffered[i + (seq_bytes - 1)];
            _ = c.addHash(i, hash(seq));
            i += 1;

            match_unadded -= 1;
            if (match_unadded == 0) break;
        }
        assert(i == match_start + match.len);
    }

    if (eos) {
        i = undefined; // (from match hashing logic)
        try c.outputBytes(buffered[last_unmatched..]);
        c.hasher.update(buffered[start..]);
        try c.writeBlock(true);
        return;
    }

    try c.outputBytes(buffered[last_unmatched..i]);
    c.hasher.update(buffered[start..i]);

    const preserved = buffered[i - flate.history_len ..];
    assert(preserved.len > @max(rebase_min_preserve, preserve));
    @memmove(w.buffer[0..preserved.len], preserved);
    w.end = preserved.len;
    c.has_history = true;
}

fn addHash(c: *Compress, i: usize, h: Hash) void {
    assert(h == hash(mem.readInt(Seq, c.writer.buffer[i..][0..seq_bytes], .big)));

    const l = &c.lookup;
    l.chain_pos +%= 1;

    // Equivilent to the below, however LLVM 21 does not optimize `@subWithOverflow` well at all.
    // const replaced_i, const no_replace = @subWithOverflow(i, flate.history_len);
    // if (no_replace == 0) {
    if (i >= flate.history_len) {
        @branchHint(.likely);
        const replaced_i = i - flate.history_len;
        // The following is the same as the below except uses a 32-bit load to help optimizations
        // const replaced_seq = mem.readInt(Seq, c.writer.buffer[replaced_i..][0..seq_bytes], .big);
        comptime assert(@sizeOf(Seq) <= @sizeOf(u32));
        const replaced_u32 = mem.readInt(u32, c.writer.buffered()[replaced_i..][0..4], .big);
        const replaced_seq: Seq = @intCast(replaced_u32 >> (32 - @bitSizeOf(Seq)));

        const replaced_h = hash(replaced_seq);
        // The following is equivilent to the below since LLVM 21 doesn't optimize it well.
        // l.head[replaced_h].is_null = l.head[replaced_h].is_null or
        //     l.head[replaced_h].int() == l.chain_pos;
        const empty_head = l.head[replaced_h].int() == l.chain_pos;
        const null_flag = PackedOptionalU15.int(.{ .is_null = empty_head, .value = 0 });
        l.head[replaced_h] = @bitCast(l.head[replaced_h].int() | null_flag);
    }

    const prev_chain_index = l.head[h];
    l.chain[l.chain_pos] = @bitCast((l.chain_pos -% prev_chain_index.value) |
        (prev_chain_index.int() & PackedOptionalU15.null_bit.int())); // Preserves null
    l.head[h] = .{ .value = l.chain_pos, .is_null = false };
}

/// If the match is shorter, the returned value can be any value `<= old`.
fn betterMatchLen(old: u16, prev: []const u8, bytes: []const u8) u16 {
    assert(old < @min(bytes.len, token.max_length));
    assert(prev.len >= bytes.len);
    assert(bytes.len >= token.min_length);

    var i: u16 = 0;
    const Block = std.meta.Int(.unsigned, @min(math.divCeil(
        comptime_int,
        math.ceilPowerOfTwoAssert(usize, @bitSizeOf(usize)),
        8,
    ) catch unreachable, 256) * 8);

    if (bytes.len < token.max_length) {
        @branchHint(.unlikely); // Only end of stream

        while (bytes[i..].len >= @sizeOf(Block)) {
            const a = mem.readInt(Block, prev[i..][0..@sizeOf(Block)], .little);
            const b = mem.readInt(Block, bytes[i..][0..@sizeOf(Block)], .little);
            const diff = a ^ b;
            if (diff != 0) {
                @branchHint(.likely);
                i += @ctz(diff) / 8;
                return i;
            }
            i += @sizeOf(Block);
        }

        while (i != bytes.len and prev[i] == bytes[i]) {
            i += 1;
        }
        assert(i < token.max_length);
        return i;
    }

    if (old >= @sizeOf(Block)) {
        // Check that a longer end is present, otherwise the match is always worse
        const a = mem.readInt(Block, prev[old + 1 - @sizeOf(Block) ..][0..@sizeOf(Block)], .little);
        const b = mem.readInt(Block, bytes[old + 1 - @sizeOf(Block) ..][0..@sizeOf(Block)], .little);
        if (a != b) return i;
    }

    while (true) {
        const a = mem.readInt(Block, prev[i..][0..@sizeOf(Block)], .little);
        const b = mem.readInt(Block, bytes[i..][0..@sizeOf(Block)], .little);
        const diff = a ^ b;
        if (diff != 0) {
            i += @ctz(diff) / 8;
            return i;
        }
        i += @sizeOf(Block);
        if (i == 256) break;
    }

    const a = mem.readInt(u16, prev[i..][0..2], .little);
    const b = mem.readInt(u16, bytes[i..][0..2], .little);
    const diff = a ^ b;
    i += @ctz(diff) / 8;
    assert(i <= token.max_length);
    return i;
}

test betterMatchLen {
    try std.testing.fuzz({}, testFuzzedMatchLen, .{});
}

fn testFuzzedMatchLen(_: void, input: []const u8) !void {
    @disableInstrumentation();
    var r: Io.Reader = .fixed(input);
    var buf: [1024]u8 = undefined;
    var w: Writer = .fixed(&buf);
    var old = r.takeLeb128(u9) catch 0;
    var bytes_off = @max(1, r.takeLeb128(u10) catch 258);
    const prev_back = @max(1, r.takeLeb128(u10) catch 258);

    while (r.takeByte()) |byte| {
        const op: packed struct(u8) {
            kind: enum(u2) { splat, copy, insert_imm, insert },
            imm: u6,

            pub fn immOrByte(op_s: @This(), r_s: *Io.Reader) usize {
                return if (op_s.imm == 0) op_s.imm else @as(usize, r_s.takeByte() catch 0) + 64;
            }
        } = @bitCast(byte);
        (switch (op.kind) {
            .splat => w.splatByteAll(r.takeByte() catch 0, op.immOrByte(&r)),
            .copy => write: {
                const start = w.buffered().len -| op.immOrByte(&r);
                const len = @min(w.buffered().len - start, r.takeByte() catch 3);
                break :write w.writeAll(w.buffered()[start..][0..len]);
            },
            .insert_imm => w.writeByte(op.imm),
            .insert => w.writeAll(r.take(
                @min(r.bufferedLen(), @as(usize, op.imm) + 1),
            ) catch unreachable),
        }) catch break;
    } else |_| {}

    w.splatByteAll(0, (1 + 3) -| w.buffered().len) catch unreachable;
    bytes_off = @min(bytes_off, @as(u10, @intCast(w.buffered().len - 3)));
    const prev_off = bytes_off -| prev_back;
    assert(prev_off < bytes_off);
    const prev = w.buffered()[prev_off..];
    const bytes = w.buffered()[bytes_off..];
    old = @min(old, bytes.len - 1, token.max_length - 1);

    const diff_index = mem.indexOfDiff(u8, prev, bytes).?; // unwrap since lengths are not same
    const expected_len = @min(diff_index, 258);
    errdefer std.debug.print(
        \\prev : '{any}'
        \\bytes: '{any}'
        \\old     : {}
        \\expected: {?}
        \\actual  : {}
    ++ "\n", .{
        prev,                                           bytes,                            old,
        if (old < expected_len) expected_len else null, betterMatchLen(old, prev, bytes),
    });
    if (old < expected_len) {
        try std.testing.expectEqual(expected_len, betterMatchLen(old, prev, bytes));
    } else {
        try std.testing.expect(betterMatchLen(old, prev, bytes) <= old);
    }
}

fn matchAndAddHash(c: *Compress, i: usize, h: Hash, gt: u16, max_chain: u16, good_: u16) struct {
    dist: u16,
    len: u16,
} {
    const l = &c.lookup;
    const buffered = c.writer.buffered();

    var chain_limit = max_chain;
    var best_dist: u16 = undefined;
    var best_len = gt;
    const nice = @min(c.opts.nice, buffered[i..].len);
    var good = good_;

    search: {
        if (l.head[h].is_null) break :search;
        // Actually a u15, but LLVM 21 does not optimize that as well (it truncates it each use).
        var dist: u16 = l.chain_pos -% l.head[h].value;
        while (true) {
            chain_limit -= 1;

            const match_len = betterMatchLen(best_len, buffered[i - 1 - dist ..], buffered[i..]);
            if (match_len > best_len) {
                best_dist = dist;
                best_len = match_len;
                if (best_len >= nice) break;
                if (best_len >= good) {
                    chain_limit >>= 2;
                    good = math.maxInt(u8); // Reduce only once
                }
            }

            if (chain_limit == 0) break;
            const next_chain_index = l.chain_pos -% @as(u15, @intCast(dist));
            // Equivilent to the below, however LLVM 21 optimizes the below worse.
            // if (l.chain[next_chain_index].is_null) break;
            // dist, const out_of_window = @addWithOverflow(dist, l.chain[next_chain_index].value);
            // if (out_of_window == 1) break;
            dist +%= l.chain[next_chain_index].int(); // wrapping for potential null bit
            comptime assert(flate.history_len == PackedOptionalU15.int(.null_bit));
            // Also, doing >= flate.history_len gives worse codegen with LLVM 21.
            if ((dist | l.chain[next_chain_index].int()) & flate.history_len != 0) break;
        }
    }

    c.addHash(i, h);
    return .{ .dist = best_dist, .len = best_len };
}

fn clenHlen(freqs: [19]u16) u4 {
    // Note that the first four codes (16, 17, 18, and 0) are always present.
    if (builtin.mode != .ReleaseSmall and (std.simd.suggestVectorLength(u16) orelse 1) >= 8) {
        const V = @Vector(16, u16);
        const hlen_mul: V = comptime m: {
            var hlen_mul: [16]u16 = undefined;
            for (token.codegen_order[3..], 0..) |i, hlen| {
                hlen_mul[i] = hlen;
            }
            break :m hlen_mul;
        };
        const encoded = freqs[0..16].* != @as(V, @splat(0));
        return @intCast(@reduce(.Max, @intFromBool(encoded) * hlen_mul));
    } else {
        var max: u4 = 0;
        for (token.codegen_order[4..], 1..) |i, len| {
            max = if (freqs[i] == 0) max else @intCast(len);
        }
        return max;
    }
}

test clenHlen {
    var freqs: [19]u16 = @splat(0);
    try std.testing.expectEqual(0, clenHlen(freqs));
    for (token.codegen_order, 1..) |i, len| {
        freqs[i] = 1;
        try std.testing.expectEqual(len -| 4, clenHlen(freqs));
        freqs[i] = 0;
    }
}

/// Returns the number of values followed by the bitsize of the extra bits.
fn buildClen(
    dyn_bits: []const u4,
    out_values: []u8,
    out_extra: []u8,
    out_freqs: *[19]u16,
) struct { u16, u16 } {
    assert(dyn_bits.len <= out_values.len);
    assert(out_values.len == out_extra.len);

    var len: u16 = 0;
    var extra_bitsize: u16 = 0;

    var remaining_bits = dyn_bits;
    var prev: u4 = 0;
    while (true) {
        const b = remaining_bits[0];
        const n_max = @min(@as(u8, if (b != 0)
            if (b != prev) 1 else 6
        else
            138), remaining_bits.len);
        prev = b;

        var n: u8 = 0;
        while (true) {
            remaining_bits = remaining_bits[1..];
            n += 1;
            if (n == n_max or remaining_bits[0] != b) break;
        }
        const code, const extra, const xsize = switch (n) {
            0 => unreachable,
            1...2 => .{ b, 0, 0 },
            3...10 => .{
                @as(u8, 16) + @intFromBool(b == 0),
                n - 3,
                @as(u8, 2) + @intFromBool(b == 0),
            },
            11...138 => .{ 18, n - 11, 7 },
            else => unreachable,
        };
        while (true) {
            out_values[len] = code;
            out_extra[len] = extra;
            out_freqs[code] += 1;
            extra_bitsize += xsize;
            len += 1;
            if (n != 2) {
                @branchHint(.likely);
                break;
            }
            // Code needs outputted once more
            n = 1;
        }
        if (remaining_bits.len == 0) break;
    }

    return .{ len, extra_bitsize };
}

test buildClen {
    //dyn_bits: []u4,
    //out_values: *[288 + 30]u8,
    //out_extra: *[288 + 30]u8,
    //out_freqs: *[19]u16,
    //struct { u16, u16 }
    var out_values: [288 + 30]u8 = undefined;
    var out_extra: [288 + 30]u8 = undefined;
    var out_freqs: [19]u16 = @splat(0);
    const len, const extra_bitsize = buildClen(&([_]u4{
        1, // A
        2, 2, // B
        3, 3, 3, // C
        4, 4, 4, 4, // D
        5, // E
        5, 5, 5, 5, 5, 5, //
        5, 5, 5, 5, 5, 5,
        5, 5,
        0, 1, // F
        0, 0, 1, // G
    } ++ @as([138 + 10]u4, @splat(0)) // H
    ), &out_values, &out_extra, &out_freqs);
    try std.testing.expectEqualSlices(u8, &.{
        1, // A
        2, 2, // B
        3, 3, 3, // C
        4, 16, // D
        5, 16, 16, 5, 5, // E
        0, 1, // F
        0, 0, 1, // G
        18, 17, // H
    }, out_values[0..len]);
    try std.testing.expectEqualSlices(u8, &.{
        0, // A
        0, 0, // B
        0, 0, 0, // C
        0, (0), // D
        0, (3), (3), 0, 0, // E
        0, 0, // F
        0, 0, 0, // G
        (127), (7), // H
    }, out_extra[0..len]);
    try std.testing.expectEqual(2 + 2 + 2 + 7 + 3, extra_bitsize);
    try std.testing.expectEqualSlices(u16, &.{
        3, 3, 2, 3, 1, 3, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        3, 1, 1,
    }, &out_freqs);
}

fn writeBlock(c: *Compress, eos: bool) Writer.Error!void {
    const toks = &c.buffered_tokens;
    if (!eos) assert(toks.n == block_tokens);
    assert(toks.lit_freqs[256] == 0);
    toks.lit_freqs[256] = 1;

    var dyn_codes_buf: [286 + 30]u16 = undefined;
    var dyn_bits_buf: [286 + 30]u4 = @splat(0);

    const dyn_lit_codes_bitsize, const dyn_last_lit = huffman.build(
        &toks.lit_freqs,
        dyn_codes_buf[0..286],
        dyn_bits_buf[0..286],
        15,
        true,
    );
    const dyn_lit_len = @max(257, dyn_last_lit + 1);

    const dyn_dist_codes_bitsize, const dyn_last_dist = huffman.build(
        &toks.dist_freqs,
        dyn_codes_buf[dyn_lit_len..][0..30],
        dyn_bits_buf[dyn_lit_len..][0..30],
        15,
        true,
    );
    const dyn_dist_len = @max(1, dyn_last_dist + 1);

    var clen_values: [288 + 30]u8 = undefined;
    var clen_extra: [288 + 30]u8 = undefined;
    var clen_freqs: [19]u16 = @splat(0);
    const clen_len, const clen_extra_bitsize = buildClen(
        dyn_bits_buf[0 .. dyn_lit_len + dyn_dist_len],
        &clen_values,
        &clen_extra,
        &clen_freqs,
    );

    var clen_codes: [19]u16 = undefined;
    var clen_bits: [19]u4 = @splat(0);
    const clen_codes_bitsize, _ = huffman.build(
        &clen_freqs,
        &clen_codes,
        &clen_bits,
        7,
        false,
    );
    const hclen = clenHlen(clen_freqs);

    const dynamic_bitsize = @as(u32, 14) +
        (4 + @as(u6, hclen)) * 3 + clen_codes_bitsize + clen_extra_bitsize +
        dyn_lit_codes_bitsize + dyn_dist_codes_bitsize;
    const fixed_bitsize = n: {
        const freq7 = 1; // eos
        var freq8: u16 = 0;
        var freq9: u16 = 0;
        var freq12: u16 = 0; // 7 + 5 - match freqs always have corresponding 5-bit dist freq
        var freq13: u16 = 0; // 8 + 5
        for (toks.lit_freqs[0..144]) |f| freq8 += f;
        for (toks.lit_freqs[144..256]) |f| freq9 += f;
        assert(toks.lit_freqs[256] == 1);
        for (toks.lit_freqs[257..280]) |f| freq12 += f;
        for (toks.lit_freqs[280..286]) |f| freq13 += f;
        break :n @as(u32, freq7) * 7 +
            @as(u32, freq8) * 8 + @as(u32, freq9) * 9 +
            @as(u32, freq12) * 12 + @as(u32, freq13) * 13;
    };

    stored: {
        for (toks.dist_freqs) |n| if (n != 0) break :stored;
        // No need to check len frequencies since they each have a corresponding dist frequency
        assert(for (toks.lit_freqs[257..]) |f| (if (f != 0) break false) else true);

        // No matches. If the stored size is smaller than the huffman-encoded version, it will be
        // outputed in a store block. This is not done with matches since the original input would
        // need to be stored since the window may slid, and it may also exceed 65535 bytes. This
        // should be OK since most inputs with matches should be more compressable anyways.
        const stored_align_bits = -%(c.bit_writer.buffered_n +% 3);
        const stored_bitsize = stored_align_bits + @as(u32, 32) + @as(u32, toks.n) * 8;
        if (@min(dynamic_bitsize, fixed_bitsize) < stored_bitsize) break :stored;

        try c.bit_writer.write(BlockHeader.int(.{ .kind = .stored, .final = eos }), 3);
        try c.bit_writer.output.rebase(0, 5);
        c.bit_writer.byteAlign();
        c.bit_writer.output.writeInt(u16, c.buffered_tokens.n, .little) catch unreachable;
        c.bit_writer.output.writeInt(u16, ~c.buffered_tokens.n, .little) catch unreachable;

        // Relatively small buffer since regular draining will
        // always consume slightly less than 2 << 15 bytes.
        var vec_buf: [4][]const u8 = undefined;
        var vec_n: usize = 0;
        var i: usize = 0;

        assert(c.buffered_tokens.pos != 0);
        while (i != c.buffered_tokens.pos) {
            const h: TokenBufferEntryHeader = @bitCast(toks.list[i..][0..2].*);
            assert(h.kind == .bytes);

            i += 2;
            vec_buf[vec_n] = toks.list[i..][0..h.data];
            i += h.data;

            vec_n += 1;
            if (i == c.buffered_tokens.pos or vec_n == vec_buf.len) {
                try c.bit_writer.output.writeVecAll(vec_buf[0..vec_n]);
                vec_n = 0;
            }
        }

        toks.* = .empty;
        return;
    }

    const lit_codes, const lit_bits, const dist_codes, const dist_bits =
        if (dynamic_bitsize < fixed_bitsize) codes: {
            try c.bit_writer.write(BlockHeader.Dynamic.int(.{
                .regular = .{ .final = eos, .kind = .dynamic },
                .hlit = @intCast(dyn_lit_len - 257),
                .hdist = @intCast(dyn_dist_len - 1),
                .hclen = hclen,
            }), 17);
            try c.bit_writer.writeClen(
                hclen,
                clen_values[0..clen_len],
                clen_extra[0..clen_len],
                clen_codes,
                clen_bits,
            );
            break :codes .{
                dyn_codes_buf[0..dyn_lit_len],
                dyn_bits_buf[0..dyn_lit_len],
                dyn_codes_buf[dyn_lit_len..][0..dyn_dist_len],
                dyn_bits_buf[dyn_lit_len..][0..dyn_dist_len],
            };
        } else codes: {
            try c.bit_writer.write(BlockHeader.int(.{ .final = eos, .kind = .fixed }), 3);
            break :codes .{
                &token.fixed_lit_codes,
                &token.fixed_lit_bits,
                &token.fixed_dist_codes,
                &token.fixed_dist_bits,
            };
        };

    var i: usize = 0;
    while (i != toks.pos) {
        const h: TokenBufferEntryHeader = @bitCast(toks.list[i..][0..2].*);
        i += 2;
        if (h.kind == .bytes) {
            for (toks.list[i..][0..h.data]) |b| {
                try c.bit_writer.write(lit_codes[b], lit_bits[b]);
            }
            i += h.data;
        } else {
            const dist = h.data;
            const len = toks.list[i];
            i += 1;
            const dist_code = token.DistCode.fromVal(dist);
            const len_code = token.LenCode.fromVal(len);
            const dist_val = dist_code.toInt();
            const lit_val = @as(u16, 257) + len_code.toInt();

            var out: u48 = lit_codes[lit_val];
            var out_bits: u6 = lit_bits[lit_val];
            out |= @shlExact(@as(u20, len - len_code.base()), @intCast(out_bits));
            out_bits += len_code.extraBits();

            out |= @shlExact(@as(u35, dist_codes[dist_val]), out_bits);
            out_bits += dist_bits[dist_val];
            out |= @shlExact(@as(u48, dist - dist_code.base()), out_bits);
            out_bits += dist_code.extraBits();

            try c.bit_writer.write(out, out_bits);
        }
    }
    try c.bit_writer.write(lit_codes[256], lit_bits[256]);

    toks.* = .empty;
}

/// Huffman tree construction.
///
/// The approach for building the huffman tree is [taken from zlib]
/// (https://github.com/madler/zlib/blob/v1.3.1/trees.c#L625) with some modifications.
const huffman = struct {
    const max_leafs = 286;
    const max_nodes = max_leafs * 2;

    const Node = struct {
        freq: u16,
        depth: u16,

        pub const Index = u16;

        pub fn smaller(a: Node, b: Node) bool {
            return if (a.freq != b.freq) a.freq < b.freq else a.depth < b.depth;
        }
    };

    fn heapSiftDown(nodes: []Node, heap: []Node.Index, start: usize) void {
        var i = start;
        while (true) {
            var min = i;
            const l = i * 2 + 1;
            const r = l + 1;
            min = if (l < heap.len and nodes[heap[l]].smaller(nodes[heap[min]])) l else min;
            min = if (r < heap.len and nodes[heap[r]].smaller(nodes[heap[min]])) r else min;
            if (i == min) break;
            mem.swap(Node.Index, &heap[i], &heap[min]);
            i = min;
        }
    }

    fn heapRemoveRoot(nodes: []Node, heap: []Node.Index) void {
        heap[0] = heap[heap.len - 1];
        heapSiftDown(nodes, heap[0 .. heap.len - 1], 0);
    }

    /// Returns the total bits to encode `freqs` followed by the index of the last non-zero bits.
    /// For `freqs[i]` == 0, `out_codes[i]` will be undefined.
    /// It is asserted `out_bits` is zero-filled.
    /// It is asserted `out_bits.len` is at least a length of
    /// one if ncomplete trees are allowed and two otherwise.
    pub fn build(
        freqs: []const u16,
        out_codes: []u16,
        out_bits: []u4,
        max_bits: u4,
        incomplete_allowed: bool,
    ) struct { u32, u16 } {
        assert(out_codes.len - 1 >= @intFromBool(incomplete_allowed));
        // freqs and out_codes are in the loop to assert they are all the same length
        for (freqs, out_codes, out_bits) |_, _, n| assert(n == 0);
        assert(out_codes.len <= @as(u16, 1) << max_bits);

        // Indexes 0..freqs are leafs, indexes max_leafs.. are internal nodes.
        var tree_nodes: [max_nodes]Node = undefined;
        var tree_parent_nodes: [max_nodes]Node.Index = undefined;
        var nodes_end: u16 = max_leafs;
        // Dual-purpose buffer. Nodes are ordered by least frequency or when equal, least depth.
        // The start is a min heap of level-zero nodes.
        // The end is a sorted buffer of nodes with the greatest first.
        var node_buf: [max_nodes]Node.Index = undefined;
        var heap_end: u16 = 0;
        var sorted_start: u16 = node_buf.len;

        for (0.., freqs) |n, freq| {
            tree_nodes[n] = .{ .freq = freq, .depth = 0 };
            node_buf[heap_end] = @intCast(n);
            heap_end += @intFromBool(freq != 0);
        }

        // There must be at least one code at minimum,
        node_buf[heap_end] = 0;
        heap_end += @intFromBool(heap_end == 0);
        // and at least two if incomplete must be avoided.
        if (heap_end == 1 and incomplete_allowed) {
            @branchHint(.unlikely); // LLVM 21 optimizes this branch as the more likely without

            // Codes must have at least one-bit, so this is a special case.
            out_bits[node_buf[0]] = 1;
            out_codes[node_buf[0]] = 0;
            return .{ freqs[node_buf[0]], node_buf[0] };
        }
        const last_nonzero = @max(node_buf[heap_end - 1], 1); // For heap_end > 1, last is not be 0
        node_buf[heap_end] = @intFromBool(node_buf[0] == 0);
        heap_end += @intFromBool(heap_end == 1);

        // Heapify the array of frequencies
        const heapify_final = heap_end - 1;
        const heapify_start = (heapify_final - 1) / 2; // Parent of final node
        var heapify_i = heapify_start;
        while (true) {
            heapSiftDown(&tree_nodes, node_buf[0..heap_end], heapify_i);
            if (heapify_i == 0) break;
            heapify_i -= 1;
        }

        // Build optimal tree. `max_bits` is not enforced yet.
        while (heap_end > 1) {
            const a = node_buf[0];
            heapRemoveRoot(&tree_nodes, node_buf[0..heap_end]);
            heap_end -= 1;
            const b = node_buf[0];

            sorted_start -= 2;
            node_buf[sorted_start..][0..2].* = .{ b, a };

            tree_nodes[nodes_end] = .{
                .freq = tree_nodes[a].freq + tree_nodes[b].freq,
                .depth = @max(tree_nodes[a].depth, tree_nodes[b].depth) + 1,
            };
            defer nodes_end += 1;
            tree_parent_nodes[a] = nodes_end;
            tree_parent_nodes[b] = nodes_end;

            node_buf[0] = nodes_end;
            heapSiftDown(&tree_nodes, node_buf[0..heap_end], 0);
        }
        sorted_start -= 1;
        node_buf[sorted_start] = node_buf[0];

        var bit_counts: [16]u16 = @splat(0);
        buildBits(out_bits, &bit_counts, &tree_parent_nodes, node_buf[sorted_start..], max_bits);
        return .{ buildValues(freqs, out_codes, out_bits, bit_counts), last_nonzero };
    }

    fn buildBits(
        out_bits: []u4,
        bit_counts: *[16]u16,
        parent_nodes: *[max_nodes]Node.Index,
        sorted: []Node.Index,
        max_bits: u4,
    ) void {
        var internal_node_bits: [max_nodes - max_leafs]u4 = undefined;
        var overflowed: u16 = 0;

        internal_node_bits[sorted[0] - max_leafs] = 0; // root
        for (sorted[1..]) |i| {
            const parent_bits = internal_node_bits[parent_nodes[i] - max_leafs];
            overflowed += @intFromBool(parent_bits == max_bits);
            const bits = parent_bits + @intFromBool(parent_bits != max_bits);
            bit_counts[bits] += @intFromBool(i < max_leafs);
            (if (i >= max_leafs) &internal_node_bits[i - max_leafs] else &out_bits[i]).* = bits;
        }

        if (overflowed == 0) {
            @branchHint(.likely);
            return;
        }

        outer: while (true) {
            var deepest: u4 = max_bits - 1;
            while (bit_counts[deepest] == 0) deepest -= 1;
            while (overflowed != 0) {
                // Insert an internal node under the leaf and move an overflow as its sibling
                bit_counts[deepest] -= 1;
                bit_counts[deepest + 1] += 2;
                // Only overflow moved. Its sibling's depth is one less, however is still >= depth.
                bit_counts[max_bits] -= 1;
                overflowed -= 2;

                if (overflowed == 0) break :outer;
                deepest += 1;
                if (deepest == max_bits) continue :outer;
            }
        }

        // Reassign bit lengths
        assert(bit_counts[0] == 0);
        var i: usize = 0;
        for (1.., bit_counts[1..]) |bits, all| {
            var remaining = all;
            while (remaining != 0) {
                defer i += 1;
                if (sorted[i] >= max_leafs) continue;
                out_bits[sorted[i]] = @intCast(bits);
                remaining -= 1;
            }
        }
        assert(for (sorted[i..]) |n| { // all leafs consumed
            if (n < max_leafs) break false;
        } else true);
    }

    fn buildValues(freqs: []const u16, out_codes: []u16, bits: []u4, bit_counts: [16]u16) u32 {
        var code: u16 = 0;
        var base: [16]u16 = undefined;
        assert(bit_counts[0] == 0);
        for (bit_counts[1..], base[1..]) |c, *b| {
            b.* = code;
            code +%= c;
            code <<= 1;
        }
        var freq_sums: [16]u16 = @splat(0);
        for (out_codes, bits, freqs) |*c, b, f| {
            c.* = @bitReverse(base[b]) >> -%b;
            base[b] += 1; // For `b == 0` this is fine since v is specified to be undefined.
            freq_sums[b] += f;
        }
        return @reduce(.Add, @as(@Vector(16, u32), freq_sums) * std.simd.iota(u32, 16));
    }

    test build {
        var codes: [8]u16 = undefined;
        var bits: [8]u4 = undefined;

        const regular_freqs: [8]u16 = .{ 1, 1, 0, 8, 8, 0, 2, 4 };
        // The optimal tree for the above frequencies is
        // 4             1   1
        //                \ /
        // 3           2   #
        //              \ /
        // 2   8   8 4   #
        //      \ /   \ /
        // 1     #     #
        //        \   /
        // 0        #
        bits = @splat(0);
        var n, var lnz = build(&regular_freqs, &codes, &bits, 15, true);
        codes[2] = 0;
        codes[5] = 0;
        try std.testing.expectEqualSlices(u4, &.{ 4, 4, 0, 2, 2, 0, 3, 2 }, &bits);
        try std.testing.expectEqualSlices(u16, &.{
            0b0111, 0b1111, 0, 0b00, 0b10, 0, 0b011, 0b01,
        }, &codes);
        try std.testing.expectEqual(54, n);
        try std.testing.expectEqual(7, lnz);
        // When constrained to 3 bits, it becomes
        // 3        1   1 2   4
        //           \ /   \ /
        // 2   8   8  #     #
        //      \ /    \   /
        // 1     #       #
        //        \     /
        // 0         #
        bits = @splat(0);
        n, lnz = build(&regular_freqs, &codes, &bits, 3, true);
        codes[2] = 0;
        codes[5] = 0;
        try std.testing.expectEqualSlices(u4, &.{ 3, 3, 0, 2, 2, 0, 3, 3 }, &bits);
        try std.testing.expectEqualSlices(u16, &.{
            0b001, 0b101, 0, 0b00, 0b10, 0, 0b011, 0b111,
        }, &codes);
        try std.testing.expectEqual(56, n);
        try std.testing.expectEqual(7, lnz);

        // Empty tree. At least one code should be present
        bits = @splat(0);
        n, lnz = build(&.{ 0, 0 }, codes[0..2], bits[0..2], 15, true);
        try std.testing.expectEqualSlices(u4, &.{ 1, 0 }, bits[0..2]);
        try std.testing.expectEqual(0b0, codes[0]);
        try std.testing.expectEqual(0, n);
        try std.testing.expectEqual(0, lnz);

        // Check all incompletable frequencies are completed
        for ([_][2]u16{ .{ 0, 0 }, .{ 0, 1 }, .{ 1, 0 } }) |incomplete| {
            // Empty tree. Both codes should be present to prevent incomplete trees
            bits = @splat(0);
            n, lnz = build(&incomplete, codes[0..2], bits[0..2], 15, false);
            try std.testing.expectEqualSlices(u4, &.{ 1, 1 }, bits[0..2]);
            try std.testing.expectEqualSlices(u16, &.{ 0b0, 0b1 }, codes[0..2]);
            try std.testing.expectEqual(incomplete[0] + incomplete[1], n);
            try std.testing.expectEqual(1, lnz);
        }

        try std.testing.fuzz({}, checkFuzzedBuildFreqs, .{});
    }

    fn checkFuzzedBuildFreqs(_: void, freqs: []const u8) !void {
        @disableInstrumentation();
        var r: Io.Reader = .fixed(freqs);
        var freqs_limit: u16 = 65535;
        var freqs_buf: [max_leafs]u16 = undefined;
        var nfreqs: u15 = 0;

        const params: packed struct(u8) {
            max_bits: u4,
            _: u3,
            incomplete_allowed: bool,
        } = @bitCast(r.takeByte() catch 255);
        while (nfreqs != freqs_buf.len) {
            const leb = r.takeLeb128(u16);
            const f = if (leb) |f| @min(f, freqs_limit) else |e| switch (e) {
                error.ReadFailed => unreachable,
                error.EndOfStream => 0,
                error.Overflow => freqs_limit,
            };
            freqs_buf[nfreqs] = f;
            nfreqs += 1;
            freqs_limit -= f;
            if (leb == error.EndOfStream and nfreqs - 1 > @intFromBool(params.incomplete_allowed))
                break;
        }

        var codes_buf: [max_leafs]u16 = undefined;
        var bits_buf: [max_leafs]u4 = @splat(0);
        const total_bits, const last_nonzero = build(
            freqs_buf[0..nfreqs],
            codes_buf[0..nfreqs],
            bits_buf[0..nfreqs],
            @max(math.log2_int_ceil(u15, nfreqs), params.max_bits),
            params.incomplete_allowed,
        );

        var has_bitlen_one: bool = false;
        var expected_total_bits: u32 = 0;
        var expected_last_nonzero: ?u16 = null;
        var weighted_sum: u32 = 0;
        for (freqs_buf[0..nfreqs], bits_buf[0..nfreqs], 0..) |f, nb, i| {
            has_bitlen_one = has_bitlen_one or nb == 1;
            weighted_sum += @shlExact(@as(u16, 1), 15 - nb) & ((1 << 15) - 1);
            expected_total_bits += @as(u32, f) * nb;
            if (nb != 0) expected_last_nonzero = @intCast(i);
        }

        errdefer std.log.err(
            \\ params: {}
            \\ freqs: {any}
            \\ bits: {any}
            \\ # freqs: {}
            \\ max bits: {} 
            \\ weighted sum: {}
            \\ has_bitlen_one: {}
            \\ expected/actual total bits: {}/{}
            \\ expected/actual last nonzero: {?}/{}
        ++ "\n", .{
            params,
            freqs_buf[0..nfreqs],
            bits_buf[0..nfreqs],
            nfreqs,
            @max(math.log2_int_ceil(u15, nfreqs), params.max_bits),
            weighted_sum,
            has_bitlen_one,
            expected_total_bits,
            total_bits,
            expected_last_nonzero,
            last_nonzero,
        });

        try std.testing.expectEqual(expected_total_bits, total_bits);
        try std.testing.expectEqual(expected_last_nonzero, last_nonzero);
        if (weighted_sum > 1 << 15)
            return error.OversubscribedHuffmanTree;
        if (weighted_sum < 1 << 15 and
            !(params.incomplete_allowed and has_bitlen_one and weighted_sum == 1 << 14))
            return error.IncompleteHuffmanTree;
    }
};

test {
    _ = huffman;
}

/// [0] is a gradient where the probability of lower values decreases across it
/// [1] is completely random and hence uncompressable
fn testingFreqBufs() !*[2][65536]u8 {
    const fbufs = try std.testing.allocator.create([2][65536]u8);
    var prng: std.Random.DefaultPrng = .init(std.testing.random_seed);
    prng.random().bytes(&fbufs[0]);
    prng.random().bytes(&fbufs[1]);
    for (0.., &fbufs[0], fbufs[1]) |i, *grad, rand| {
        const prob = @as(u8, @intCast(255 - i / (fbufs[0].len * 256)));
        grad.* /= @max(1, rand / @max(1, prob));
    }
    return fbufs;
}

fn testingCheckDecompressedMatches(
    flate_bytes: []const u8,
    expected_size: u32,
    expected_hash: flate.Container.Hasher,
) !void {
    const container: flate.Container = expected_hash;
    var data_hash: flate.Container.Hasher = .init(container);
    var data_size: u32 = 0;
    var flate_r: Io.Reader = .fixed(flate_bytes);
    var deflate_buf: [flate.max_window_len]u8 = undefined;
    var deflate: flate.Decompress = .init(&flate_r, container, &deflate_buf);

    while (deflate.reader.peekGreedy(1)) |bytes| {
        data_size += @intCast(bytes.len);
        data_hash.update(bytes);
        deflate.reader.toss(bytes.len);
    } else |e| switch (e) {
        error.ReadFailed => return deflate.err.?,
        error.EndOfStream => {},
    }

    try testingCheckContainerHash(
        expected_size,
        expected_hash,
        data_hash,
        data_size,
        deflate.container_metadata,
    );
}

fn testingCheckContainerHash(
    expected_size: u32,
    expected_hash: flate.Container.Hasher,
    actual_hash: flate.Container.Hasher,
    actual_size: u32,
    actual_meta: flate.Container.Metadata,
) !void {
    try std.testing.expectEqual(expected_size, actual_size);
    switch (actual_hash) {
        .raw => {},
        .gzip => |gz| {
            const expected_crc = expected_hash.gzip.crc.final();
            try std.testing.expectEqual(expected_size, actual_meta.gzip.count);
            try std.testing.expectEqual(expected_crc, gz.crc.final());
            try std.testing.expectEqual(expected_crc, actual_meta.gzip.crc);
        },
        .zlib => |zl| {
            const expected_adler = expected_hash.zlib.adler;
            try std.testing.expectEqual(expected_adler, zl.adler);
            try std.testing.expectEqual(expected_adler, actual_meta.zlib.adler);
        },
    }
}

const PackedContainer = packed struct(u2) {
    raw: bool,
    other: enum(u1) { gzip, zlib },

    pub fn val(c: @This()) flate.Container {
        return if (c.raw) .raw else switch (c.other) {
            .gzip => .gzip,
            .zlib => .zlib,
        };
    }
};

test Compress {
    const fbufs = try testingFreqBufs();
    defer if (!builtin.fuzz) std.testing.allocator.destroy(fbufs);
    try std.testing.fuzz(fbufs, testFuzzedCompressInput, .{});
}

fn testFuzzedCompressInput(fbufs: *const [2][65536]u8, input: []const u8) !void {
    var in: Io.Reader = .fixed(input);
    var opts: packed struct(u51) {
        container: PackedContainer,
        buf_size: u16,
        good: u8,
        nice: u8,
        lazy: u8,
        /// Not a `u16` to limit it for performance
        chain: u9,
    } = @bitCast(in.takeLeb128(u51) catch 0);
    var expected_hash: flate.Container.Hasher = .init(opts.container.val());
    var expected_size: u32 = 0;

    var flate_buf: [128 * 1024]u8 = undefined;
    var flate_w: Writer = .fixed(&flate_buf);
    var deflate_buf: [flate.max_window_len * 2]u8 = undefined;
    var deflate_w = try Compress.init(
        &flate_w,
        deflate_buf[0 .. flate.max_window_len + @as(usize, opts.buf_size)],
        opts.container.val(),
        .{
            .good = @as(u16, opts.good) + 3,
            .nice = @as(u16, opts.nice) + 3,
            .lazy = @as(u16, @min(opts.lazy, opts.nice)) + 3,
            .chain = @max(1, opts.chain, @as(u8, 4) * @intFromBool(opts.good <= opts.lazy)),
        },
    );

    // It is ensured that more bytes are not written then this to ensure this run
    // does not take too long and that `flate_buf` does not run out of space.
    const flate_buf_blocks = flate_buf.len / block_tokens;
    // Allow a max overhead of 64 bytes per block since the implementation does not gaurauntee it
    // writes store blocks when optimal. This comes from taking less than 32 bytes to write an
    // optimal dynamic block header of mostly bitlen 8 codes and the end of block literal plus
    // `(65536 / 256) / 8`, which is is the maximum number of extra bytes from bitlen 9 codes. An
    // extra 32 bytes is reserved on top of that for container headers and footers.
    const max_size = flate_buf.len - (flate_buf_blocks * 64 + 32);

    while (true) {
        const data: packed struct(u36) {
            is_rebase: bool,
            is_bytes: bool,
            params: packed union {
                copy: packed struct(u34) {
                    len_lo: u5,
                    dist: u15,
                    len_hi: u4,
                    _: u10,
                },
                bytes: packed struct(u34) {
                    kind: enum(u1) { gradient, random },
                    off_hi: u4,
                    len_lo: u10,
                    off_mi: u4,
                    len_hi: u5,
                    off_lo: u8,
                    _: u2,
                },
                rebase: packed struct(u34) {
                    preserve: u17,
                    capacity: u17,
                },
            },
        } = @bitCast(in.takeLeb128(u36) catch |e| switch (e) {
            error.ReadFailed => unreachable,
            error.Overflow => 0,
            error.EndOfStream => break,
        });

        const buffered = deflate_w.writer.buffered();
        // Required for repeating patterns and since writing from `buffered` is illegal
        var copy_buf: [512]u8 = undefined;

        if (data.is_rebase) {
            const usable_capacity = deflate_w.writer.buffer.len - rebase_reserved_capacity;
            const preserve = @min(data.params.rebase.preserve, usable_capacity);
            const capacity = @min(data.params.rebase.capacity, usable_capacity -
                @max(rebase_min_preserve, preserve));
            try deflate_w.writer.rebase(preserve, capacity);
            continue;
        }

        const max_bytes = max_size -| expected_size;
        const bytes = if (!data.is_bytes and buffered.len != 0) bytes: {
            const dist = @min(buffered.len, @as(u32, data.params.copy.dist) + 1);
            const len = @min(
                @max(@shlExact(@as(u9, data.params.copy.len_hi), 5) | data.params.copy.len_lo, 1),
                max_bytes,
            );
            // Reuse the implementation's history. Otherwise our own would need maintained.
            const bytes_start = buffered[buffered.len - dist ..];
            const history_bytes = bytes_start[0..@min(bytes_start.len, len)];

            @memcpy(copy_buf[0..history_bytes.len], history_bytes);
            const new_history = len - history_bytes.len;
            if (history_bytes.len != len) for ( // check needed for `- dist`
                copy_buf[history_bytes.len..][0..new_history],
                copy_buf[history_bytes.len - dist ..][0..new_history],
            ) |*next, prev| {
                next.* = prev;
            };
            break :bytes copy_buf[0..len];
        } else bytes: {
            const off = @shlExact(@as(u16, data.params.bytes.off_hi), 12) |
                @shlExact(@as(u16, data.params.bytes.off_mi), 8) |
                data.params.bytes.off_lo;
            const len = @shlExact(@as(u16, data.params.bytes.len_hi), 10) |
                data.params.bytes.len_lo;
            const fbuf = &fbufs[@intFromEnum(data.params.bytes.kind)];
            break :bytes fbuf[off..][0..@min(len, fbuf.len - off, max_bytes)];
        };
        assert(bytes.len <= max_bytes);
        try deflate_w.writer.writeAll(bytes);
        expected_hash.update(bytes);
        expected_size += @intCast(bytes.len);
    }

    try deflate_w.writer.flush();
    try testingCheckDecompressedMatches(flate_w.buffered(), expected_size, expected_hash);
}

/// Does not compress data
pub const Raw = struct {
    /// After `flush` is called, all vtable calls with result in `error.WriteFailed.`
    writer: Writer,
    output: *Writer,
    hasher: flate.Container.Hasher,

    const max_block_size: u16 = 65535;
    const full_header: [5]u8 = .{
        BlockHeader.int(.{ .final = false, .kind = .stored }),
        255,
        255,
        0,
        0,
    };

    /// While there is no minimum buffer size, it is recommended
    /// to be at least `flate.max_window_len` for optimal output.
    pub fn init(output: *Writer, buffer: []u8, container: flate.Container) Writer.Error!Raw {
        try output.writeAll(container.header());
        return .{
            .writer = .{
                .buffer = buffer,
                .vtable = &.{
                    .drain = Raw.drain,
                    .flush = Raw.flush,
                    .rebase = Raw.rebase,
                },
            },
            .output = output,
            .hasher = .init(container),
        };
    }

    fn drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
        errdefer w.* = .failing;
        const r: *Raw = @fieldParentPtr("writer", w);
        const min_block = @min(w.buffer.len, max_block_size);
        const pattern = data[data.len - 1];
        var partial_header: [5]u8 = undefined;

        var vecs: [16][]const u8 = undefined;
        var vecs_n: usize = 0;
        const data_bytes = Writer.countSplat(data, splat);
        const total_bytes = w.end + data_bytes;
        var rem_bytes = total_bytes;
        var rem_splat = splat;
        var rem_data = data;
        var rem_data_elem: []const u8 = w.buffered();

        assert(rem_bytes > min_block);
        while (rem_bytes > min_block) { // not >= to allow `min_block` blocks to be marked as final
            // also, it handles the case of `min_block` being zero (no buffer)
            const block_size: u16 = @min(rem_bytes, max_block_size);
            rem_bytes -= block_size;

            if (vecs_n == vecs.len) {
                try r.output.writeVecAll(&vecs);
                vecs_n = 0;
            }
            vecs[vecs_n] = if (block_size == 65535)
                &full_header
            else header: {
                partial_header[0] = BlockHeader.int(.{ .final = false, .kind = .stored });
                mem.writeInt(u16, partial_header[1..3], block_size, .little);
                mem.writeInt(u16, partial_header[3..5], ~block_size, .little);
                break :header &partial_header;
            };
            vecs_n += 1;

            var block_limit: Io.Limit = .limited(block_size);
            while (true) {
                if (vecs_n == vecs.len) {
                    try r.output.writeVecAll(&vecs);
                    vecs_n = 0;
                }

                const vec = block_limit.sliceConst(rem_data_elem);
                vecs[vecs_n] = vec;
                vecs_n += 1;
                r.hasher.update(vec);

                const is_pattern = rem_splat != splat and vec.len == pattern.len;
                if (is_pattern) assert(pattern.len != 0); // exceeded countSplat

                if (!is_pattern or rem_splat == 0 or pattern.len > @intFromEnum(block_limit) / 2) {
                    rem_data_elem = rem_data_elem[vec.len..];
                    block_limit = block_limit.subtract(vec.len).?;

                    if (rem_data_elem.len == 0) {
                        rem_data_elem = rem_data[0];
                        if (rem_data.len != 1) {
                            rem_data = rem_data[1..];
                        } else if (rem_splat != 0) {
                            rem_splat -= 1;
                        } else {
                            // All of `data` has been consumed.
                            assert(block_limit == .nothing);
                            assert(rem_bytes == 0);
                            // Since `rem_bytes` and `block_limit` are zero, these won't be used.
                            rem_data = undefined;
                            rem_data_elem = undefined;
                            rem_splat = undefined;
                        }
                    }
                    if (block_limit == .nothing) break;
                } else {
                    const out_splat = @intFromEnum(block_limit) / pattern.len;
                    assert(out_splat >= 2);

                    try r.output.writeSplatAll(vecs[0..vecs_n], out_splat);
                    for (1..out_splat) |_| r.hasher.update(vec);

                    vecs_n = 0;
                    block_limit = block_limit.subtract(pattern.len * out_splat).?;
                    if (rem_splat >= out_splat) {
                        // `out_splat` contains `rem_data`, however one more needs subtracted
                        // anyways since the next pattern is also being taken.
                        rem_splat -= out_splat;
                    } else {
                        // All of `data` has been consumed.
                        assert(block_limit == .nothing);
                        assert(rem_bytes == 0);
                        // Since `rem_bytes` and `block_limit` are zero, these won't be used.
                        rem_data = undefined;
                        rem_data_elem = undefined;
                        rem_splat = undefined;
                    }
                    if (block_limit == .nothing) break;
                }
            }
        }

        if (vecs_n != 0) { // can be the case if a splat was sent
            try r.output.writeVecAll(vecs[0..vecs_n]);
        }

        if (rem_bytes > data_bytes) {
            assert(rem_bytes - data_bytes == rem_data_elem.len);
            assert(&rem_data_elem[0] == &w.buffer[total_bytes - rem_bytes]);
        }
        return w.consume(total_bytes - rem_bytes);
    }

    fn flush(w: *Writer) Writer.Error!void {
        defer w.* = .failing;
        try Raw.rebaseInner(w, 0, w.buffer.len, true);
    }

    fn rebase(w: *Writer, preserve: usize, capacity: usize) Writer.Error!void {
        errdefer w.* = .failing;
        try Raw.rebaseInner(w, preserve, capacity, false);
    }

    fn rebaseInner(w: *Writer, preserve: usize, capacity: usize, eos: bool) Writer.Error!void {
        const r: *Raw = @fieldParentPtr("writer", w);
        assert(preserve + capacity <= w.buffer.len);
        if (eos) assert(capacity == w.buffer.len);

        var partial_header: [5]u8 = undefined;
        var footer_buf: [8]u8 = undefined;
        const preserved = @min(w.end, preserve);
        var remaining = w.buffer[0 .. w.end - preserved];

        var vecs: [16][]const u8 = undefined;
        var vecs_n: usize = 0;
        while (remaining.len > max_block_size) { // not >= so there is always a block down below
            if (vecs_n == vecs.len) {
                try r.output.writeVecAll(&vecs);
                vecs_n = 0;
            }
            vecs[vecs_n + 0] = &full_header;
            vecs[vecs_n + 1] = remaining[0..max_block_size];
            r.hasher.update(vecs[vecs_n + 1]);
            vecs_n += 2;
            remaining = remaining[max_block_size..];
        }

        // eos check required for empty block
        if (w.buffer.len - (remaining.len + preserved) < capacity or eos) {
            // A partial write is necessary to reclaim enough buffer space
            const block_size: u16 = @intCast(remaining.len);
            partial_header[0] = BlockHeader.int(.{ .final = eos, .kind = .stored });
            mem.writeInt(u16, partial_header[1..3], block_size, .little);
            mem.writeInt(u16, partial_header[3..5], ~block_size, .little);

            if (vecs_n == vecs.len) {
                try r.output.writeVecAll(&vecs);
                vecs_n = 0;
            }
            vecs[vecs_n + 0] = &partial_header;
            vecs[vecs_n + 1] = remaining[0..block_size];
            r.hasher.update(vecs[vecs_n + 1]);
            vecs_n += 2;
            remaining = remaining[block_size..];
            assert(remaining.len == 0);

            if (eos and r.hasher != .raw) {
                // the footer is done here instead of `flush` so it can be included in the vector
                var footer_w: Writer = .fixed(&footer_buf);
                r.hasher.writeFooter(&footer_w) catch unreachable;
                assert(footer_w.end != 0);

                if (vecs_n == vecs.len) {
                    try r.output.writeVecAll(&vecs);
                    return r.output.writeAll(footer_w.buffered());
                } else {
                    vecs[vecs_n] = footer_w.buffered();
                    vecs_n += 1;
                }
            }
        }

        try r.output.writeVecAll(vecs[0..vecs_n]);
        _ = w.consume(w.end - preserved - remaining.len);
    }
};

test Raw {
    const data_buf = try std.testing.allocator.create([4 * 65536]u8);
    defer if (!builtin.fuzz) std.testing.allocator.destroy(data_buf);
    var prng: std.Random.DefaultPrng = .init(std.testing.random_seed);
    prng.random().bytes(data_buf);
    try std.testing.fuzz(data_buf, testFuzzedRawInput, .{});
}

fn countVec(data: []const []const u8) usize {
    var bytes: usize = 0;
    for (data) |d| bytes += d.len;
    return bytes;
}

fn testFuzzedRawInput(data_buf: *const [4 * 65536]u8, input: []const u8) !void {
    const HashedStoreWriter = struct {
        writer: Writer,
        state: enum {
            header,
            block_header,
            block_body,
            final_block_body,
            footer,
            end,
        },
        block_remaining: u16,
        container: flate.Container,
        data_hash: flate.Container.Hasher,
        data_size: usize,
        footer_hash: u32,
        footer_size: u32,

        pub fn init(buf: []u8, container: flate.Container) @This() {
            return .{
                .writer = .{
                    .vtable = &.{
                        .drain = @This().drain,
                        .flush = @This().flush,
                    },
                    .buffer = buf,
                },
                .state = .header,
                .block_remaining = 0,
                .container = container,
                .data_hash = .init(container),
                .data_size = 0,
                .footer_hash = undefined,
                .footer_size = undefined,
            };
        }

        /// Note that this implementation is somewhat dependent on the implementation of
        /// `Raw` by expecting headers / footers to be continous in data elements. It
        /// also expects the header to be the same as `flate.Container.header` and not
        /// for multiple streams to be concatenated.
        fn drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
            errdefer w.* = .failing;
            var h: *@This() = @fieldParentPtr("writer", w);

            var rem_splat = splat;
            var rem_data = data;
            var rem_data_elem: []const u8 = w.buffered();

            data_loop: while (true) {
                const wanted = switch (h.state) {
                    .header => h.container.headerSize(),
                    .block_header => 5,
                    .block_body, .final_block_body => h.block_remaining,
                    .footer => h.container.footerSize(),
                    .end => 1,
                };

                if (wanted != 0) {
                    while (rem_data_elem.len == 0) {
                        rem_data_elem = rem_data[0];
                        if (rem_data.len != 1) {
                            rem_data = rem_data[1..];
                        } else {
                            if (rem_splat == 0) {
                                break :data_loop;
                            } else {
                                rem_splat -= 1;
                            }
                        }
                    }
                }

                const bytes = Io.Limit.limited(wanted).sliceConst(rem_data_elem);
                rem_data_elem = rem_data_elem[bytes.len..];

                switch (h.state) {
                    .header => {
                        if (bytes.len < wanted)
                            return error.WriteFailed; // header eos
                        if (!mem.eql(u8, bytes, h.container.header()))
                            return error.WriteFailed; // wrong header
                        h.state = .block_header;
                    },
                    .block_header => {
                        if (bytes.len < wanted)
                            return error.WriteFailed; // store block header eos
                        const header: BlockHeader = @bitCast(@as(u3, @truncate(bytes[0])));
                        if (header.kind != .stored)
                            return error.WriteFailed; // non-store block
                        const len = mem.readInt(u16, bytes[1..3], .little);
                        const nlen = mem.readInt(u16, bytes[3..5], .little);
                        if (nlen != ~len)
                            return error.WriteFailed; // wrong nlen
                        h.block_remaining = len;
                        h.state = if (!header.final) .block_body else .final_block_body;
                    },
                    .block_body, .final_block_body => {
                        h.data_hash.update(bytes);
                        h.data_size += bytes.len;
                        h.block_remaining -= @intCast(bytes.len);
                        if (h.block_remaining == 0) {
                            h.state = if (h.state != .final_block_body) .block_header else .footer;
                        }
                    },
                    .footer => {
                        if (bytes.len < wanted)
                            return error.WriteFailed; // footer eos
                        switch (h.container) {
                            .raw => {},
                            .gzip => {
                                h.footer_hash = mem.readInt(u32, bytes[0..4], .little);
                                h.footer_size = mem.readInt(u32, bytes[4..8], .little);
                            },
                            .zlib => {
                                h.footer_hash = mem.readInt(u32, bytes[0..4], .big);
                            },
                        }
                        h.state = .end;
                    },
                    .end => return error.WriteFailed, // data past end
                }
            }

            w.end = 0;
            return Writer.countSplat(data, splat);
        }

        fn flush(w: *Writer) Writer.Error!void {
            defer w.* = .failing; // Clears buffer even if state hasn't reached `end`
            _ = try @This().drain(w, &.{""}, 0);
        }
    };

    var in: Io.Reader = .fixed(input);
    const opts: packed struct(u19) {
        container: PackedContainer,
        buf_len: u17,
    } = @bitCast(in.takeLeb128(u19) catch 0);
    var output: HashedStoreWriter = .init(&.{}, opts.container.val());
    var r_buf: [2 * 65536]u8 = undefined;
    var r: Raw = try .init(
        &output.writer,
        r_buf[0 .. opts.buf_len +% flate.max_window_len],
        opts.container.val(),
    );

    var data_base: u18 = 0;
    var expected_hash: flate.Container.Hasher = .init(opts.container.val());
    var expected_size: u32 = 0;
    var vecs: [32][]const u8 = undefined;
    var vecs_n: usize = 0;

    while (in.seek != in.end) {
        const VecInfo = packed struct(u58) {
            output: bool,
            /// If set, `data_len` and `splat` are reinterpreted as `capacity`
            /// and `preserve_len` respectively and `output` is treated as set.
            rebase: bool,
            block_aligning_len: bool,
            block_aligning_splat: bool,
            data_len: u18,
            splat: u18,
            data_off: u18,
        };
        var vec_info: VecInfo = @bitCast(in.takeLeb128(u58) catch |e| switch (e) {
            error.ReadFailed => unreachable,
            error.Overflow, error.EndOfStream => 0,
        });

        {
            const buffered = r.writer.buffered().len + countVec(vecs[0..vecs_n]);
            const to_align = mem.alignForwardAnyAlign(usize, buffered, Raw.max_block_size) - buffered;
            assert((buffered + to_align) % Raw.max_block_size == 0);

            if (vec_info.block_aligning_len) {
                vec_info.data_len = @intCast(to_align);
            } else if (vec_info.block_aligning_splat and vec_info.data_len != 0 and
                to_align % vec_info.data_len == 0)
            {
                vec_info.splat = @divExact(@as(u18, @intCast(to_align)), vec_info.data_len) -% 1;
            }
        }

        var splat = if (vec_info.output and !vec_info.rebase) vec_info.splat +% 1 else 1;
        add_vec: {
            if (vec_info.rebase) break :add_vec;
            if (expected_size +| math.mulWide(u18, vec_info.data_len, splat) >
                10 * (1 << 16))
            {
                // Skip this vector to avoid this test taking too long.
                // 10 maximum sized blocks is choosen as the limit since it is two more
                // than the maximum the implementation can output in one drain.
                splat = 1;
                break :add_vec;
            }

            vecs[vecs_n] = data_buf[@min(
                data_base +% vec_info.data_off,
                data_buf.len - vec_info.data_len,
            )..][0..vec_info.data_len];

            data_base +%= vec_info.data_len +% 3; // extra 3 to help catch aliasing bugs

            for (0..splat) |_| expected_hash.update(vecs[vecs_n]);
            expected_size += @as(u32, @intCast(vecs[vecs_n].len)) * splat;
            vecs_n += 1;
        }

        const want_drain = vecs_n == vecs.len or vec_info.output or vec_info.rebase or
            in.seek == in.end;
        if (want_drain and vecs_n != 0) {
            try r.writer.writeSplatAll(vecs[0..vecs_n], splat);
            vecs_n = 0;
        } else assert(splat == 1);

        if (vec_info.rebase) {
            try r.writer.rebase(vec_info.data_len, @min(
                r.writer.buffer.len -| vec_info.data_len,
                vec_info.splat,
            ));
        }
    }

    try r.writer.flush();
    try output.writer.flush();

    try std.testing.expectEqual(.end, output.state);
    try std.testing.expectEqual(expected_size, output.data_size);
    switch (output.data_hash) {
        .raw => {},
        .gzip => |gz| {
            const expected_crc = expected_hash.gzip.crc.final();
            try std.testing.expectEqual(expected_crc, gz.crc.final());
            try std.testing.expectEqual(expected_crc, output.footer_hash);
            try std.testing.expectEqual(expected_size, output.footer_size);
        },
        .zlib => |zl| {
            const expected_adler = expected_hash.zlib.adler;
            try std.testing.expectEqual(expected_adler, zl.adler);
            try std.testing.expectEqual(expected_adler, output.footer_hash);
        },
    }
}

/// Only performs huffman compression on data, does no matching.
pub const Huffman = struct {
    writer: Writer,
    bit_writer: BitWriter,
    hasher: flate.Container.Hasher,

    const max_tokens: u16 = 65535 - 1; // one is reserved for EOF

    /// While there is no minimum buffer size, it is recommended
    /// to be at least `flate.max_window_len` to improve compression.
    ///
    /// It is asserted `output` has a capacity of at least 8 bytes.
    pub fn init(output: *Writer, buffer: []u8, container: flate.Container) Writer.Error!Huffman {
        assert(output.buffer.len > 8);

        try output.writeAll(container.header());
        return .{
            .writer = .{
                .buffer = buffer,
                .vtable = &.{
                    .drain = Huffman.drain,
                    .flush = Huffman.flush,
                    .rebase = Huffman.rebase,
                },
            },
            .bit_writer = .init(output),
            .hasher = .init(container),
        };
    }

    fn drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
        {
            //std.debug.print("drain {} (buffered)", .{w.buffered().len});
            //for (data) |d| std.debug.print("\n\t+ {}", .{d.len});
            //std.debug.print(" x {}\n\n", .{splat});
        }

        const h: *Huffman = @fieldParentPtr("writer", w);
        const min_block = @min(w.buffer.len, max_tokens);
        const pattern = data[data.len - 1];

        const data_bytes = Writer.countSplat(data, splat);
        const total_bytes = w.end + data_bytes;
        var rem_bytes = total_bytes;
        var rem_splat = splat;
        var rem_data = data;
        var rem_data_elem: []const u8 = w.buffered();

        assert(rem_bytes > min_block);
        while (rem_bytes > min_block) { // not >= to allow `min_block` blocks to be marked as final
            // also, it handles the case of `min_block` being zero (no buffer)
            const block_size: u16 = @min(rem_bytes, max_tokens);
            rem_bytes -= block_size;

            // Count frequencies
            comptime assert(max_tokens != 65535);
            var freqs: [257]u16 = @splat(0);
            freqs[256] = 1;

            const start_splat = rem_splat;
            const start_data = rem_data;
            const start_data_elem = rem_data_elem;

            var block_limit: Io.Limit = .limited(block_size);
            while (true) {
                const bytes = block_limit.sliceConst(rem_data_elem);
                const is_pattern = rem_splat != splat and bytes.len == pattern.len;

                const mul = if (!is_pattern) 1 else @intFromEnum(block_limit) / pattern.len;
                assert(mul != 0);
                if (is_pattern) assert(mul <= rem_splat + 1); // one more for `rem_data`

                for (bytes) |b| freqs[b] += @intCast(mul);
                rem_data_elem = rem_data_elem[bytes.len..];
                block_limit = block_limit.subtract(bytes.len * mul).?;

                if (rem_data_elem.len == 0) {
                    rem_data_elem = rem_data[0];
                    if (rem_data.len != 1) {
                        rem_data = rem_data[1..];
                    } else if (rem_splat >= mul) {
                        // if the counter was not the pattern, `mul` is always one, otherwise,
                        // `mul` contains `rem_data`,  however one more needs subtracted anyways
                        // since the next pattern is also being taken.
                        rem_splat -= mul;
                    } else {
                        // All of `data` has been consumed.
                        assert(block_limit == .nothing);
                        assert(rem_bytes == 0);
                        // Since `rem_bytes` and `block_limit` are zero, these won't be used.
                        rem_data = undefined;
                        rem_data_elem = undefined;
                        rem_splat = undefined;
                    }
                }
                if (block_limit == .nothing) break;
            }

            // Output block
            rem_splat = start_splat;
            rem_data = start_data;
            rem_data_elem = start_data_elem;
            block_limit = .limited(block_size);

            var codes_buf: CodesBuf = .init;
            if (try h.outputHeader(&freqs, &codes_buf, block_size, false)) |table| {
                while (true) {
                    const bytes = block_limit.sliceConst(rem_data_elem);
                    rem_data_elem = rem_data_elem[bytes.len..];
                    block_limit = block_limit.subtract(bytes.len).?;

                    h.hasher.update(bytes);
                    for (bytes) |b| {
                        try h.bit_writer.write(table.codes[b], table.bits[b]);
                    }

                    if (rem_data_elem.len == 0) {
                        rem_data_elem = rem_data[0];
                        if (rem_data.len != 1) {
                            rem_data = rem_data[1..];
                        } else if (rem_splat != 0) {
                            rem_splat -= 1;
                        } else {
                            // All of `data` has been consumed.
                            assert(block_limit == .nothing);
                            assert(rem_bytes == 0);
                            // Since `rem_bytes` and `block_limit` are zero, these won't be used.
                            rem_data = undefined;
                            rem_data_elem = undefined;
                            rem_splat = undefined;
                        }
                    }
                    if (block_limit == .nothing) break;
                }
                try h.bit_writer.write(table.codes[256], table.bits[256]);
            } else while (true) {
                // Store block

                // Write data that is not a full vector element
                const in_pattern = rem_splat != splat;
                const vec_elem_i, const in_data =
                    @subWithOverflow(data.len - (rem_data.len - @intFromBool(in_pattern)), 1);
                const is_elem = in_data == 0 and data[vec_elem_i].len == rem_data_elem.len;

                if (!is_elem or rem_data_elem.len > @intFromEnum(block_limit)) {
                    block_limit = block_limit.subtract(rem_data_elem.len) orelse {
                        try h.bit_writer.output.writeAll(rem_data_elem[0..@intFromEnum(block_limit)]);
                        h.hasher.update(rem_data_elem[0..@intFromEnum(block_limit)]);
                        rem_data_elem = rem_data_elem[@intFromEnum(block_limit)..];
                        assert(rem_data_elem.len != 0);
                        break;
                    };
                    try h.bit_writer.output.writeAll(rem_data_elem);
                    h.hasher.update(rem_data_elem);
                } else {
                    // Put `rem_data_elem` back in `rem_data`
                    if (!in_pattern) {
                        rem_data = data[vec_elem_i..];
                    } else {
                        rem_splat += 1;
                    }
                }
                rem_data_elem = undefined; // it is always updated below

                // Send through as much of the original vector as possible
                var vec_n: usize = 0;
                var vlimit = block_limit;
                const vec_splat = while (rem_data[vec_n..].len != 1) {
                    vlimit = vlimit.subtract(rem_data[vec_n].len) orelse break 1;
                    vec_n += 1;
                } else vec_splat: {
                    // For `pattern.len == 0`, the value of `vec_splat` does not matter.
                    const vec_splat = @intFromEnum(vlimit) / @max(1, pattern.len);
                    if (pattern.len != 0) assert(vec_splat <= rem_splat + 1);
                    vlimit = vlimit.subtract(pattern.len * vec_splat).?;
                    vec_n += 1;
                    break :vec_splat vec_splat;
                };

                const n = if (vec_n != 0) n: {
                    assert(@intFromEnum(block_limit) - @intFromEnum(vlimit) ==
                        Writer.countSplat(rem_data[0..vec_n], vec_splat));
                    break :n try h.bit_writer.output.writeSplat(rem_data[0..vec_n], vec_splat);
                } else 0; // Still go into the case below to advance the vector
                block_limit = block_limit.subtract(n).?;
                var consumed: Io.Limit = .limited(n);

                while (rem_data.len != 1) {
                    const elem = rem_data[0];
                    rem_data = rem_data[1..];
                    consumed = consumed.subtract(elem.len) orelse {
                        h.hasher.update(elem[0..@intFromEnum(consumed)]);
                        rem_data_elem = elem[@intFromEnum(consumed)..];
                        break;
                    };
                    h.hasher.update(elem);
                } else {
                    if (pattern.len == 0) {
                        // All of `data` has been consumed. However, the general
                        // case below does not work since it divides by zero.
                        assert(consumed == .nothing);
                        assert(block_limit == .nothing);
                        assert(rem_bytes == 0);
                        // Since `rem_bytes` and `block_limit` are zero, these won't be used.
                        rem_splat = undefined;
                        rem_data = undefined;
                        rem_data_elem = undefined;
                        break;
                    }

                    const splatted = @intFromEnum(consumed) / pattern.len;
                    const partial = @intFromEnum(consumed) % pattern.len;
                    for (0..splatted) |_| h.hasher.update(pattern);
                    h.hasher.update(pattern[0..partial]);

                    const taken_splat = splatted + 1;
                    if (rem_splat >= taken_splat) {
                        rem_splat -= taken_splat;
                        rem_data_elem = pattern[partial..];
                    } else {
                        // All of `data` has been consumed.
                        assert(partial == 0);
                        assert(block_limit == .nothing);
                        assert(rem_bytes == 0);
                        // Since `rem_bytes` and `block_limit` are zero, these won't be used.
                        rem_data = undefined;
                        rem_data_elem = undefined;
                        rem_splat = undefined;
                    }
                }

                if (block_limit == .nothing) break;
            }
        }

        if (rem_bytes > data_bytes) {
            assert(rem_bytes - data_bytes == rem_data_elem.len);
            assert(&rem_data_elem[0] == &w.buffer[total_bytes - rem_bytes]);
        }
        return w.consume(total_bytes - rem_bytes);
    }

    fn flush(w: *Writer) Writer.Error!void {
        defer w.* = .failing;
        const h: *Huffman = @fieldParentPtr("writer", w);
        try Huffman.rebaseInner(w, 0, w.buffer.len, true);
        try h.bit_writer.output.rebase(0, 1);
        h.bit_writer.byteAlign();
        try h.hasher.writeFooter(h.bit_writer.output);
    }

    fn rebase(w: *Writer, preserve: usize, capacity: usize) Writer.Error!void {
        errdefer w.* = .failing;
        try Huffman.rebaseInner(w, preserve, capacity, false);
    }

    fn rebaseInner(w: *Writer, preserve: usize, capacity: usize, eos: bool) Writer.Error!void {
        const h: *Huffman = @fieldParentPtr("writer", w);
        assert(preserve + capacity <= w.buffer.len);
        if (eos) assert(capacity == w.buffer.len);

        const preserved = @min(w.end, preserve);
        var remaining = w.buffer[0 .. w.end - preserved];
        while (remaining.len > max_tokens) { // not >= so there is always a block down below
            const bytes = remaining[0..max_tokens];
            remaining = remaining[max_tokens..];
            try h.outputBytes(bytes, false);
        }

        // eos check required for empty block
        if (w.buffer.len - (remaining.len + preserved) < capacity or eos) {
            const bytes = remaining;
            remaining = &.{};
            try h.outputBytes(bytes, eos);
        }

        _ = w.consume(w.end - preserved - remaining.len);
    }

    fn outputBytes(h: *Huffman, bytes: []const u8, eos: bool) Writer.Error!void {
        comptime assert(max_tokens != 65535);
        assert(bytes.len <= max_tokens);
        var freqs: [257]u16 = @splat(0);
        freqs[256] = 1;
        for (bytes) |b| freqs[b] += 1;
        h.hasher.update(bytes);

        var codes_buf: CodesBuf = .init;
        if (try h.outputHeader(&freqs, &codes_buf, @intCast(bytes.len), eos)) |table| {
            for (bytes) |b| {
                try h.bit_writer.write(table.codes[b], table.bits[b]);
            }
            try h.bit_writer.write(table.codes[256], table.bits[256]);
        } else {
            try h.bit_writer.output.writeAll(bytes);
        }
    }

    const CodesBuf = struct {
        dyn_codes: [258]u16,
        dyn_bits: [258]u4,

        pub const init: CodesBuf = .{
            .dyn_codes = @as([257]u16, undefined) ++ .{0},
            .dyn_bits = @as([257]u4, @splat(0)) ++ .{1},
        };
    };

    /// Returns null if the block is stored.
    fn outputHeader(
        h: *Huffman,
        freqs: *const [257]u16,
        buf: *CodesBuf,
        bytes: u16,
        eos: bool,
    ) Writer.Error!?struct {
        codes: *const [257]u16,
        bits: *const [257]u4,
    } {
        assert(freqs[256] == 1);
        const dyn_codes_bitsize, _ = huffman.build(
            freqs,
            buf.dyn_codes[0..257],
            buf.dyn_bits[0..257],
            15,
            true,
        );

        var clen_values: [258]u8 = undefined;
        var clen_extra: [258]u8 = undefined;
        var clen_freqs: [19]u16 = @splat(0);
        const clen_len, const clen_extra_bitsize = buildClen(
            &buf.dyn_bits,
            &clen_values,
            &clen_extra,
            &clen_freqs,
        );

        var clen_codes: [19]u16 = undefined;
        var clen_bits: [19]u4 = @splat(0);
        const clen_codes_bitsize, _ = huffman.build(
            &clen_freqs,
            &clen_codes,
            &clen_bits,
            7,
            false,
        );
        const hclen = clenHlen(clen_freqs);

        const dynamic_bitsize = @as(u32, 14) +
            (4 + @as(u6, hclen)) * 3 + clen_codes_bitsize + clen_extra_bitsize +
            dyn_codes_bitsize;
        const fixed_bitsize = n: {
            const freq7 = 1; // eos
            var freq9: u16 = 0;
            for (freqs[144..256]) |f| freq9 += f;
            const freq8: u16 = bytes - freq9;
            break :n @as(u32, freq7) * 7 + @as(u32, freq8) * 8 + @as(u32, freq9) * 9;
        };
        const stored_bitsize = n: {
            const stored_align_bits = -%(h.bit_writer.buffered_n +% 3);
            break :n stored_align_bits + @as(u32, 32) + @as(u32, bytes) * 8;
        };

        //std.debug.print("@ {}{{{}}} ", .{ h.bit_writer.output.end, h.bit_writer.buffered_n });
        //std.debug.print("#{} -> s {} f {} d {}\n", .{ bytes, stored_bitsize, fixed_bitsize, dynamic_bitsize });

        if (stored_bitsize <= @min(dynamic_bitsize, fixed_bitsize)) {
            try h.bit_writer.write(BlockHeader.int(.{ .kind = .stored, .final = eos }), 3);
            try h.bit_writer.output.rebase(0, 5);
            h.bit_writer.byteAlign();
            h.bit_writer.output.writeInt(u16, bytes, .little) catch unreachable;
            h.bit_writer.output.writeInt(u16, ~bytes, .little) catch unreachable;
            return null;
        }

        if (fixed_bitsize <= dynamic_bitsize) {
            try h.bit_writer.write(BlockHeader.int(.{ .final = eos, .kind = .fixed }), 3);
            return .{
                .codes = token.fixed_lit_codes[0..257],
                .bits = token.fixed_lit_bits[0..257],
            };
        } else {
            try h.bit_writer.write(BlockHeader.Dynamic.int(.{
                .regular = .{ .final = eos, .kind = .dynamic },
                .hlit = 0,
                .hdist = 0,
                .hclen = hclen,
            }), 17);
            try h.bit_writer.writeClen(
                hclen,
                clen_values[0..clen_len],
                clen_extra[0..clen_len],
                clen_codes,
                clen_bits,
            );
            return .{ .codes = buf.dyn_codes[0..257], .bits = buf.dyn_bits[0..257] };
        }
    }
};

test Huffman {
    const fbufs = try testingFreqBufs();
    defer if (!builtin.fuzz) std.testing.allocator.destroy(fbufs);
    try std.testing.fuzz(fbufs, testFuzzedHuffmanInput, .{});
}

/// This function is derived from `testFuzzedRawInput` with a few changes for fuzzing `Huffman`.
fn testFuzzedHuffmanInput(fbufs: *const [2][65536]u8, input: []const u8) !void {
    var in: Io.Reader = .fixed(input);
    const opts: packed struct(u19) {
        container: PackedContainer,
        buf_len: u17,
    } = @bitCast(in.takeLeb128(u19) catch 0);
    var flate_buf: [2 * 65536]u8 = undefined;
    var flate_w: Writer = .fixed(&flate_buf);
    var h_buf: [2 * 65536]u8 = undefined;
    var h: Huffman = try .init(
        &flate_w,
        h_buf[0 .. opts.buf_len +% flate.max_window_len],
        opts.container.val(),
    );

    var expected_hash: flate.Container.Hasher = .init(opts.container.val());
    var expected_size: u32 = 0;
    var vecs: [32][]const u8 = undefined;
    var vecs_n: usize = 0;

    while (in.seek != in.end) {
        const VecInfo = packed struct(u55) {
            output: bool,
            /// If set, `data_len` and `splat` are reinterpreted as `capacity`
            /// and `preserve_len` respectively and `output` is treated as set.
            rebase: bool,
            block_aligning_len: bool,
            block_aligning_splat: bool,
            data_off_hi: u8,
            random_data: u1,
            data_len: u16,
            splat: u18,
            /// This is less useful as each value is part of the same gradient 'step'
            data_off_lo: u8,
        };
        var vec_info: VecInfo = @bitCast(in.takeLeb128(u55) catch |e| switch (e) {
            error.ReadFailed => unreachable,
            error.Overflow, error.EndOfStream => 0,
        });

        {
            const buffered = h.writer.buffered().len + countVec(vecs[0..vecs_n]);
            const to_align = mem.alignForwardAnyAlign(usize, buffered, Huffman.max_tokens) - buffered;
            assert((buffered + to_align) % Huffman.max_tokens == 0);

            if (vec_info.block_aligning_len) {
                vec_info.data_len = @intCast(to_align);
            } else if (vec_info.block_aligning_splat and vec_info.data_len != 0 and
                to_align % vec_info.data_len == 0)
            {
                vec_info.splat = @divExact(@as(u18, @intCast(to_align)), vec_info.data_len) -% 1;
            }
        }

        var splat = if (vec_info.output and !vec_info.rebase) vec_info.splat +% 1 else 1;
        add_vec: {
            if (vec_info.rebase) break :add_vec;
            if (expected_size +| math.mulWide(u18, vec_info.data_len, splat) > 4 * (1 << 16)) {
                // Skip this vector to avoid this test taking too long.
                splat = 1;
                break :add_vec;
            }

            const data_buf = &fbufs[vec_info.random_data];
            vecs[vecs_n] = data_buf[@min(
                (@as(u16, vec_info.data_off_hi) << 8) | vec_info.data_off_lo,
                data_buf.len - vec_info.data_len,
            )..][0..vec_info.data_len];

            for (0..splat) |_| expected_hash.update(vecs[vecs_n]);
            expected_size += @as(u32, @intCast(vecs[vecs_n].len)) * splat;
            vecs_n += 1;
        }

        const want_drain = vecs_n == vecs.len or vec_info.output or vec_info.rebase or
            in.seek == in.end;
        if (want_drain and vecs_n != 0) {
            var n = h.writer.buffered().len + Writer.countSplat(vecs[0..vecs_n], splat);
            const oos = h.writer.writeSplatAll(vecs[0..vecs_n], splat) == error.WriteFailed;
            n -= h.writer.buffered().len;
            const block_lim = math.divCeil(usize, n, Huffman.max_tokens) catch unreachable;
            const lim = flate_w.end + 6 * block_lim + n; // 6 since block header may span two bytes
            if (flate_w.end > lim) return error.OverheadTooLarge;
            if (oos) return;

            vecs_n = 0;
        } else assert(splat == 1);

        if (vec_info.rebase) {
            const old_end = flate_w.end;
            var n = h.writer.buffered().len;
            const oos = h.writer.rebase(vec_info.data_len, @min(
                h.writer.buffer.len -| vec_info.data_len,
                vec_info.splat,
            )) == error.WriteFailed;
            n -= h.writer.buffered().len;
            const block_lim = math.divCeil(usize, n, Huffman.max_tokens) catch unreachable;
            const lim = old_end + 6 * block_lim + n; // 6 since block header may span two bytes
            if (flate_w.end > lim) return error.OverheadTooLarge;
            if (oos) return;
        }
    }

    {
        const old_end = flate_w.end;
        const n = h.writer.buffered().len;
        const oos = h.writer.flush() == error.WriteFailed;
        assert(h.writer.buffered().len == 0);
        const block_lim = @max(1, math.divCeil(usize, n, Huffman.max_tokens) catch unreachable);
        const lim = old_end + 6 * block_lim + n + opts.container.val().footerSize();
        if (flate_w.end > lim) return error.OverheadTooLarge;
        if (oos) return;
    }

    try testingCheckDecompressedMatches(flate_w.buffered(), expected_size, expected_hash);
}
