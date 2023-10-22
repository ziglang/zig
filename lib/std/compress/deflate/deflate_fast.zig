// This encoding algorithm, which prioritizes speed over output size, is
// based on Snappy's LZ77-style encoder: github.com/golang/snappy

const std = @import("std");
const math = std.math;
const mem = std.mem;

const Allocator = std.mem.Allocator;

const deflate_const = @import("deflate_const.zig");
const deflate = @import("compressor.zig");
const token = @import("token.zig");

const base_match_length = deflate_const.base_match_length;
const base_match_offset = deflate_const.base_match_offset;
const max_match_length = deflate_const.max_match_length;
const max_match_offset = deflate_const.max_match_offset;
const max_store_block_size = deflate_const.max_store_block_size;

const table_bits = 14; // Bits used in the table.
const table_mask = table_size - 1; // Mask for table indices. Redundant, but can eliminate bounds checks.
const table_shift = 32 - table_bits; // Right-shift to get the table_bits most significant bits of a uint32.
const table_size = 1 << table_bits; // Size of the table.

// Reset the buffer offset when reaching this.
// Offsets are stored between blocks as i32 values.
// Since the offset we are checking against is at the beginning
// of the buffer, we need to subtract the current and input
// buffer to not risk overflowing the i32.
const buffer_reset = math.maxInt(i32) - max_store_block_size * 2;

fn load32(b: []u8, i: i32) u32 {
    var s = b[@as(usize, @intCast(i)) .. @as(usize, @intCast(i)) + 4];
    return @as(u32, @intCast(s[0])) |
        @as(u32, @intCast(s[1])) << 8 |
        @as(u32, @intCast(s[2])) << 16 |
        @as(u32, @intCast(s[3])) << 24;
}

fn load64(b: []u8, i: i32) u64 {
    var s = b[@as(usize, @intCast(i))..@as(usize, @intCast(i + 8))];
    return @as(u64, @intCast(s[0])) |
        @as(u64, @intCast(s[1])) << 8 |
        @as(u64, @intCast(s[2])) << 16 |
        @as(u64, @intCast(s[3])) << 24 |
        @as(u64, @intCast(s[4])) << 32 |
        @as(u64, @intCast(s[5])) << 40 |
        @as(u64, @intCast(s[6])) << 48 |
        @as(u64, @intCast(s[7])) << 56;
}

fn hash(u: u32) u32 {
    return (u *% 0x1e35a7bd) >> table_shift;
}

// These constants are defined by the Snappy implementation so that its
// assembly implementation can fast-path some 16-bytes-at-a-time copies.
// They aren't necessary in the pure Go implementation, and may not be
// necessary in Zig, but using the same thresholds doesn't really hurt.
const input_margin = 16 - 1;
const min_non_literal_block_size = 1 + 1 + input_margin;

const TableEntry = struct {
    val: u32, // Value at destination
    offset: i32,
};

pub fn deflateFast() DeflateFast {
    return DeflateFast{
        .table = [_]TableEntry{.{ .val = 0, .offset = 0 }} ** table_size,
        .prev = undefined,
        .prev_len = 0,
        .cur = max_store_block_size,
        .allocator = undefined,
    };
}

// DeflateFast maintains the table for matches,
// and the previous byte block for cross block matching.
pub const DeflateFast = struct {
    table: [table_size]TableEntry,
    prev: []u8, // Previous block, zero length if unknown.
    prev_len: u32, // Previous block length
    cur: i32, // Current match offset.
    allocator: Allocator,

    const Self = @This();

    pub fn init(self: *Self, allocator: Allocator) !void {
        self.allocator = allocator;
        self.prev = try allocator.alloc(u8, max_store_block_size);
        self.prev_len = 0;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.prev);
        self.prev_len = 0;
    }

    // Encodes a block given in `src` and appends tokens to `dst` and returns the result.
    pub fn encode(self: *Self, dst: []token.Token, tokens_count: *u16, src: []u8) void {

        // Ensure that self.cur doesn't wrap.
        if (self.cur >= buffer_reset) {
            self.shiftOffsets();
        }

        // This check isn't in the Snappy implementation, but there, the caller
        // instead of the callee handles this case.
        if (src.len < min_non_literal_block_size) {
            self.cur += max_store_block_size;
            self.prev_len = 0;
            emitLiteral(dst, tokens_count, src);
            return;
        }

        // s_limit is when to stop looking for offset/length copies. The input_margin
        // lets us use a fast path for emitLiteral in the main loop, while we are
        // looking for copies.
        var s_limit = @as(i32, @intCast(src.len - input_margin));

        // next_emit is where in src the next emitLiteral should start from.
        var next_emit: i32 = 0;
        var s: i32 = 0;
        var cv: u32 = load32(src, s);
        var next_hash: u32 = hash(cv);

        outer: while (true) {
            // Copied from the C++ snappy implementation:
            //
            // Heuristic match skipping: If 32 bytes are scanned with no matches
            // found, start looking only at every other byte. If 32 more bytes are
            // scanned (or skipped), look at every third byte, etc.. When a match
            // is found, immediately go back to looking at every byte. This is a
            // small loss (~5% performance, ~0.1% density) for compressible data
            // due to more bookkeeping, but for non-compressible data (such as
            // JPEG) it's a huge win since the compressor quickly "realizes" the
            // data is incompressible and doesn't bother looking for matches
            // everywhere.
            //
            // The "skip" variable keeps track of how many bytes there are since
            // the last match; dividing it by 32 (ie. right-shifting by five) gives
            // the number of bytes to move ahead for each iteration.
            var skip: i32 = 32;

            var next_s: i32 = s;
            var candidate: TableEntry = undefined;
            while (true) {
                s = next_s;
                var bytes_between_hash_lookups = skip >> 5;
                next_s = s + bytes_between_hash_lookups;
                skip += bytes_between_hash_lookups;
                if (next_s > s_limit) {
                    break :outer;
                }
                candidate = self.table[next_hash & table_mask];
                var now = load32(src, next_s);
                self.table[next_hash & table_mask] = .{ .offset = s + self.cur, .val = cv };
                next_hash = hash(now);

                var offset = s - (candidate.offset - self.cur);
                if (offset > max_match_offset or cv != candidate.val) {
                    // Out of range or not matched.
                    cv = now;
                    continue;
                }
                break;
            }

            // A 4-byte match has been found. We'll later see if more than 4 bytes
            // match. But, prior to the match, src[next_emit..s] are unmatched. Emit
            // them as literal bytes.
            emitLiteral(dst, tokens_count, src[@as(usize, @intCast(next_emit))..@as(usize, @intCast(s))]);

            // Call emitCopy, and then see if another emitCopy could be our next
            // move. Repeat until we find no match for the input immediately after
            // what was consumed by the last emitCopy call.
            //
            // If we exit this loop normally then we need to call emitLiteral next,
            // though we don't yet know how big the literal will be. We handle that
            // by proceeding to the next iteration of the main loop. We also can
            // exit this loop via goto if we get close to exhausting the input.
            while (true) {
                // Invariant: we have a 4-byte match at s, and no need to emit any
                // literal bytes prior to s.

                // Extend the 4-byte match as long as possible.
                //
                s += 4;
                var t = candidate.offset - self.cur + 4;
                var l = self.matchLen(s, t, src);

                // matchToken is flate's equivalent of Snappy's emitCopy. (length,offset)
                dst[tokens_count.*] = token.matchToken(
                    @as(u32, @intCast(l + 4 - base_match_length)),
                    @as(u32, @intCast(s - t - base_match_offset)),
                );
                tokens_count.* += 1;
                s += l;
                next_emit = s;
                if (s >= s_limit) {
                    break :outer;
                }

                // We could immediately start working at s now, but to improve
                // compression we first update the hash table at s-1 and at s. If
                // another emitCopy is not our next move, also calculate next_hash
                // at s+1. At least on amd64 architecture, these three hash calculations
                // are faster as one load64 call (with some shifts) instead of
                // three load32 calls.
                var x = load64(src, s - 1);
                var prev_hash = hash(@as(u32, @truncate(x)));
                self.table[prev_hash & table_mask] = TableEntry{
                    .offset = self.cur + s - 1,
                    .val = @as(u32, @truncate(x)),
                };
                x >>= 8;
                var curr_hash = hash(@as(u32, @truncate(x)));
                candidate = self.table[curr_hash & table_mask];
                self.table[curr_hash & table_mask] = TableEntry{
                    .offset = self.cur + s,
                    .val = @as(u32, @truncate(x)),
                };

                var offset = s - (candidate.offset - self.cur);
                if (offset > max_match_offset or @as(u32, @truncate(x)) != candidate.val) {
                    cv = @as(u32, @truncate(x >> 8));
                    next_hash = hash(cv);
                    s += 1;
                    break;
                }
            }
        }

        if (@as(u32, @intCast(next_emit)) < src.len) {
            emitLiteral(dst, tokens_count, src[@as(usize, @intCast(next_emit))..]);
        }
        self.cur += @as(i32, @intCast(src.len));
        self.prev_len = @as(u32, @intCast(src.len));
        @memcpy(self.prev[0..self.prev_len], src);
        return;
    }

    fn emitLiteral(dst: []token.Token, tokens_count: *u16, lit: []u8) void {
        for (lit) |v| {
            dst[tokens_count.*] = token.literalToken(@as(u32, @intCast(v)));
            tokens_count.* += 1;
        }
        return;
    }

    // matchLen returns the match length between src[s..] and src[t..].
    // t can be negative to indicate the match is starting in self.prev.
    // We assume that src[s-4 .. s] and src[t-4 .. t] already match.
    fn matchLen(self: *Self, s: i32, t: i32, src: []u8) i32 {
        var s1 = @as(u32, @intCast(s)) + max_match_length - 4;
        if (s1 > src.len) {
            s1 = @as(u32, @intCast(src.len));
        }

        // If we are inside the current block
        if (t >= 0) {
            var b = src[@as(usize, @intCast(t))..];
            var a = src[@as(usize, @intCast(s))..@as(usize, @intCast(s1))];
            b = b[0..a.len];
            // Extend the match to be as long as possible.
            for (a, 0..) |_, i| {
                if (a[i] != b[i]) {
                    return @as(i32, @intCast(i));
                }
            }
            return @as(i32, @intCast(a.len));
        }

        // We found a match in the previous block.
        var tp = @as(i32, @intCast(self.prev_len)) + t;
        if (tp < 0) {
            return 0;
        }

        // Extend the match to be as long as possible.
        var a = src[@as(usize, @intCast(s))..@as(usize, @intCast(s1))];
        var b = self.prev[@as(usize, @intCast(tp))..@as(usize, @intCast(self.prev_len))];
        if (b.len > a.len) {
            b = b[0..a.len];
        }
        a = a[0..b.len];
        for (b, 0..) |_, i| {
            if (a[i] != b[i]) {
                return @as(i32, @intCast(i));
            }
        }

        // If we reached our limit, we matched everything we are
        // allowed to in the previous block and we return.
        var n = @as(i32, @intCast(b.len));
        if (@as(u32, @intCast(s + n)) == s1) {
            return n;
        }

        // Continue looking for more matches in the current block.
        a = src[@as(usize, @intCast(s + n))..@as(usize, @intCast(s1))];
        b = src[0..a.len];
        for (a, 0..) |_, i| {
            if (a[i] != b[i]) {
                return @as(i32, @intCast(i)) + n;
            }
        }
        return @as(i32, @intCast(a.len)) + n;
    }

    // Reset resets the encoding history.
    // This ensures that no matches are made to the previous block.
    pub fn reset(self: *Self) void {
        self.prev_len = 0;
        // Bump the offset, so all matches will fail distance check.
        // Nothing should be >= self.cur in the table.
        self.cur += max_match_offset;

        // Protect against self.cur wraparound.
        if (self.cur >= buffer_reset) {
            self.shiftOffsets();
        }
    }

    // shiftOffsets will shift down all match offset.
    // This is only called in rare situations to prevent integer overflow.
    //
    // See https://golang.org/issue/18636 and https://golang.org/issues/34121.
    fn shiftOffsets(self: *Self) void {
        if (self.prev_len == 0) {
            // We have no history; just clear the table.
            for (self.table, 0..) |_, i| {
                self.table[i] = TableEntry{ .val = 0, .offset = 0 };
            }
            self.cur = max_match_offset + 1;
            return;
        }

        // Shift down everything in the table that isn't already too far away.
        for (self.table, 0..) |_, i| {
            var v = self.table[i].offset - self.cur + max_match_offset + 1;
            if (v < 0) {
                // We want to reset self.cur to max_match_offset + 1, so we need to shift
                // all table entries down by (self.cur - (max_match_offset + 1)).
                // Because we ignore matches > max_match_offset, we can cap
                // any negative offsets at 0.
                v = 0;
            }
            self.table[i].offset = v;
        }
        self.cur = max_match_offset + 1;
    }
};

test "best speed match 1/3" {
    const expectEqual = std.testing.expectEqual;

    {
        var previous = [_]u8{ 0, 0, 0, 1, 2 };
        var e = DeflateFast{
            .prev = &previous,
            .prev_len = previous.len,
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var current = [_]u8{ 3, 4, 5, 0, 1, 2, 3, 4, 5 };
        var got: i32 = e.matchLen(3, -3, &current);
        try expectEqual(@as(i32, 6), got);
    }
    {
        var previous = [_]u8{ 0, 0, 0, 1, 2 };
        var e = DeflateFast{
            .prev = &previous,
            .prev_len = previous.len,
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var current = [_]u8{ 2, 4, 5, 0, 1, 2, 3, 4, 5 };
        var got: i32 = e.matchLen(3, -3, &current);
        try expectEqual(@as(i32, 3), got);
    }
    {
        var previous = [_]u8{ 0, 0, 0, 1, 1 };
        var e = DeflateFast{
            .prev = &previous,
            .prev_len = previous.len,
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var current = [_]u8{ 3, 4, 5, 0, 1, 2, 3, 4, 5 };
        var got: i32 = e.matchLen(3, -3, &current);
        try expectEqual(@as(i32, 2), got);
    }
    {
        var previous = [_]u8{ 0, 0, 0, 1, 2 };
        var e = DeflateFast{
            .prev = &previous,
            .prev_len = previous.len,
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var current = [_]u8{ 2, 2, 2, 2, 1, 2, 3, 4, 5 };
        var got: i32 = e.matchLen(0, -1, &current);
        try expectEqual(@as(i32, 4), got);
    }
    {
        var previous = [_]u8{ 0, 0, 0, 1, 2, 3, 4, 5, 2, 2 };
        var e = DeflateFast{
            .prev = &previous,
            .prev_len = previous.len,
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var current = [_]u8{ 2, 2, 2, 2, 1, 2, 3, 4, 5 };
        var got: i32 = e.matchLen(4, -7, &current);
        try expectEqual(@as(i32, 5), got);
    }
    {
        var previous = [_]u8{ 9, 9, 9, 9, 9 };
        var e = DeflateFast{
            .prev = &previous,
            .prev_len = previous.len,
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var current = [_]u8{ 2, 2, 2, 2, 1, 2, 3, 4, 5 };
        var got: i32 = e.matchLen(0, -1, &current);
        try expectEqual(@as(i32, 0), got);
    }
    {
        var previous = [_]u8{ 9, 9, 9, 9, 9 };
        var e = DeflateFast{
            .prev = &previous,
            .prev_len = previous.len,
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var current = [_]u8{ 9, 2, 2, 2, 1, 2, 3, 4, 5 };
        var got: i32 = e.matchLen(1, 0, &current);
        try expectEqual(@as(i32, 0), got);
    }
}

test "best speed match 2/3" {
    const expectEqual = std.testing.expectEqual;

    {
        var previous = [_]u8{};
        var e = DeflateFast{
            .prev = &previous,
            .prev_len = previous.len,
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var current = [_]u8{ 9, 2, 2, 2, 1, 2, 3, 4, 5 };
        var got: i32 = e.matchLen(1, -5, &current);
        try expectEqual(@as(i32, 0), got);
    }
    {
        var previous = [_]u8{};
        var e = DeflateFast{
            .prev = &previous,
            .prev_len = previous.len,
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var current = [_]u8{ 9, 2, 2, 2, 1, 2, 3, 4, 5 };
        var got: i32 = e.matchLen(1, -1, &current);
        try expectEqual(@as(i32, 0), got);
    }
    {
        var previous = [_]u8{};
        var e = DeflateFast{
            .prev = &previous,
            .prev_len = previous.len,
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var current = [_]u8{ 2, 2, 2, 2, 1, 2, 3, 4, 5 };
        var got: i32 = e.matchLen(1, 0, &current);
        try expectEqual(@as(i32, 3), got);
    }
    {
        var previous = [_]u8{ 3, 4, 5 };
        var e = DeflateFast{
            .prev = &previous,
            .prev_len = previous.len,
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var current = [_]u8{ 3, 4, 5 };
        var got: i32 = e.matchLen(0, -3, &current);
        try expectEqual(@as(i32, 3), got);
    }
}

test "best speed match 2/2" {
    const testing = std.testing;
    const expectEqual = testing.expectEqual;

    const Case = struct {
        previous: u32,
        current: u32,
        s: i32,
        t: i32,
        expected: i32,
    };

    const cases = [_]Case{
        .{
            .previous = 1000,
            .current = 1000,
            .s = 0,
            .t = -1000,
            .expected = max_match_length - 4,
        },
        .{
            .previous = 200,
            .s = 0,
            .t = -200,
            .current = 500,
            .expected = max_match_length - 4,
        },
        .{
            .previous = 200,
            .s = 1,
            .t = 0,
            .current = 500,
            .expected = max_match_length - 4,
        },
        .{
            .previous = max_match_length - 4,
            .s = 0,
            .t = -(max_match_length - 4),
            .current = 500,
            .expected = max_match_length - 4,
        },
        .{
            .previous = 200,
            .s = 400,
            .t = -200,
            .current = 500,
            .expected = 100,
        },
        .{
            .previous = 10,
            .s = 400,
            .t = 200,
            .current = 500,
            .expected = 100,
        },
    };

    for (cases) |c| {
        var previous = try testing.allocator.alloc(u8, c.previous);
        defer testing.allocator.free(previous);
        @memset(previous, 0);

        var current = try testing.allocator.alloc(u8, c.current);
        defer testing.allocator.free(current);
        @memset(current, 0);

        var e = DeflateFast{
            .prev = previous,
            .prev_len = @as(u32, @intCast(previous.len)),
            .table = undefined,
            .allocator = undefined,
            .cur = 0,
        };
        var got: i32 = e.matchLen(c.s, c.t, current);
        try expectEqual(@as(i32, c.expected), got);
    }
}

test "best speed shift offsets" {
    const testing = std.testing;
    const expect = std.testing.expect;

    // Test if shiftoffsets properly preserves matches and resets out-of-range matches
    // seen in https://github.com/golang/go/issues/4142
    var enc = deflateFast();
    try enc.init(testing.allocator);
    defer enc.deinit();

    // test_data may not generate internal matches.
    var test_data = [32]u8{
        0xf5, 0x25, 0xf2, 0x55, 0xf6, 0xc1, 0x1f, 0x0b, 0x10, 0xa1,
        0xd0, 0x77, 0x56, 0x38, 0xf1, 0x9c, 0x7f, 0x85, 0xc5, 0xbd,
        0x16, 0x28, 0xd4, 0xf9, 0x03, 0xd4, 0xc0, 0xa1, 0x1e, 0x58,
        0x5b, 0xc9,
    };

    var tokens = [_]token.Token{0} ** 32;
    var tokens_count: u16 = 0;

    // Encode the testdata with clean state.
    // Second part should pick up matches from the first block.
    tokens_count = 0;
    enc.encode(&tokens, &tokens_count, &test_data);
    var want_first_tokens = tokens_count;
    tokens_count = 0;
    enc.encode(&tokens, &tokens_count, &test_data);
    var want_second_tokens = tokens_count;

    try expect(want_first_tokens > want_second_tokens);

    // Forward the current indicator to before wraparound.
    enc.cur = buffer_reset - @as(i32, @intCast(test_data.len));

    // Part 1 before wrap, should match clean state.
    tokens_count = 0;
    enc.encode(&tokens, &tokens_count, &test_data);
    var got = tokens_count;
    try testing.expectEqual(want_first_tokens, got);

    // Verify we are about to wrap.
    try testing.expectEqual(@as(i32, buffer_reset), enc.cur);

    // Part 2 should match clean state as well even if wrapped.
    tokens_count = 0;
    enc.encode(&tokens, &tokens_count, &test_data);
    got = tokens_count;
    try testing.expectEqual(want_second_tokens, got);

    // Verify that we wrapped.
    try expect(enc.cur < buffer_reset);

    // Forward the current buffer, leaving the matches at the bottom.
    enc.cur = buffer_reset;
    enc.shiftOffsets();

    // Ensure that no matches were picked up.
    tokens_count = 0;
    enc.encode(&tokens, &tokens_count, &test_data);
    got = tokens_count;
    try testing.expectEqual(want_first_tokens, got);
}

test "best speed reset" {
    // test that encoding is consistent across a warparound of the table offset.
    // See https://github.com/golang/go/issues/34121
    const fmt = std.fmt;
    const testing = std.testing;

    const ArrayList = std.ArrayList;

    const input_size = 65536;
    var input = try testing.allocator.alloc(u8, input_size);
    defer testing.allocator.free(input);

    var i: usize = 0;
    while (i < input_size) : (i += 1) {
        _ = try fmt.bufPrint(input, "asdfasdfasdfasdf{d}{d}fghfgujyut{d}yutyu\n", .{ i, i, i });
    }
    // This is specific to level 1 (best_speed).
    const level = .best_speed;
    const offset: usize = 1;

    // We do an encode with a clean buffer to compare.
    var want = ArrayList(u8).init(testing.allocator);
    defer want.deinit();
    var clean_comp = try deflate.compressor(
        testing.allocator,
        want.writer(),
        .{ .level = level },
    );
    defer clean_comp.deinit();

    // Write 3 times, close.
    try clean_comp.writer().writeAll(input);
    try clean_comp.writer().writeAll(input);
    try clean_comp.writer().writeAll(input);
    try clean_comp.close();

    var o = offset;
    while (o <= 256) : (o *= 2) {
        var discard = ArrayList(u8).init(testing.allocator);
        defer discard.deinit();

        var comp = try deflate.compressor(
            testing.allocator,
            discard.writer(),
            .{ .level = level },
        );
        defer comp.deinit();

        // Reset until we are right before the wraparound.
        // Each reset adds max_match_offset to the offset.
        i = 0;
        var limit = (buffer_reset - input.len - o - max_match_offset) / max_match_offset;
        while (i < limit) : (i += 1) {
            // skip ahead to where we are close to wrap around...
            comp.reset(discard.writer());
        }
        var got = ArrayList(u8).init(testing.allocator);
        defer got.deinit();
        comp.reset(got.writer());

        // Write 3 times, close.
        try comp.writer().writeAll(input);
        try comp.writer().writeAll(input);
        try comp.writer().writeAll(input);
        try comp.close();

        // output must match at wraparound
        try testing.expectEqualSlices(u8, want.items, got.items);
    }
}
