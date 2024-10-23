//! Used in deflate (compression), holds uncompressed data form which Tokens are
//! produces. In combination with Lookup it is used to find matches in history data.
//!
const std = @import("std");
const consts = @import("consts.zig");

const expect = testing.expect;
const assert = std.debug.assert;
const testing = std.testing;

const hist_len = consts.history.len;
const buffer_len = 2 * hist_len;
const min_lookahead = consts.match.min_length + consts.match.max_length;
const max_rp = buffer_len - min_lookahead;

const Self = @This();

buffer: [buffer_len]u8 = undefined,
wp: usize = 0, // write position
rp: usize = 0, // read position
fp: isize = 0, // last flush position, tokens are build from fp..rp

/// Returns number of bytes written, or 0 if buffer is full and need to slide.
pub fn write(self: *Self, buf: []const u8) usize {
    if (self.rp >= max_rp) return 0; // need to slide

    const n = @min(buf.len, buffer_len - self.wp);
    @memcpy(self.buffer[self.wp .. self.wp + n], buf[0..n]);
    self.wp += n;
    return n;
}

/// Slide buffer for hist_len.
/// Drops old history, preserves between hist_len and hist_len - min_lookahead.
/// Returns number of bytes removed.
pub fn slide(self: *Self) u16 {
    assert(self.rp >= max_rp and self.wp >= self.rp);
    const n = self.wp - hist_len;
    @memcpy(self.buffer[0..n], self.buffer[hist_len..self.wp]);
    self.rp -= hist_len;
    self.wp -= hist_len;
    self.fp -= hist_len;
    return @intCast(n);
}

/// Data from the current position (read position). Those part of the buffer is
/// not converted to tokens yet.
fn lookahead(self: *Self) []const u8 {
    assert(self.wp >= self.rp);
    return self.buffer[self.rp..self.wp];
}

/// Returns part of the lookahead buffer. If should_flush is set no lookahead is
/// preserved otherwise preserves enough data for the longest match. Returns
/// null if there is not enough data.
pub fn activeLookahead(self: *Self, should_flush: bool) ?[]const u8 {
    const min: usize = if (should_flush) 0 else min_lookahead;
    const lh = self.lookahead();
    return if (lh.len > min) lh else null;
}

/// Advances read position, shrinks lookahead.
pub fn advance(self: *Self, n: u16) void {
    assert(self.wp >= self.rp + n);
    self.rp += n;
}

/// Returns writable part of the buffer, where new uncompressed data can be
/// written.
pub fn writable(self: *Self) []u8 {
    return self.buffer[self.wp..];
}

/// Notification of what part of writable buffer is filled with data.
pub fn written(self: *Self, n: usize) void {
    self.wp += n;
}

/// Finds match length between previous and current position.
/// Used in hot path!
pub fn match(self: *Self, prev_pos: u16, curr_pos: u16, min_len: u16) u16 {
    const max_len: usize = @min(self.wp - curr_pos, consts.match.max_length);
    // lookahead buffers from previous and current positions
    const prev_lh = self.buffer[prev_pos..][0..max_len];
    const curr_lh = self.buffer[curr_pos..][0..max_len];

    // If we already have match (min_len > 0),
    // test the first byte above previous len a[min_len] != b[min_len]
    // and then all the bytes from that position to zero.
    // That is likely positions to find difference than looping from first bytes.
    var i: usize = min_len;
    if (i > 0) {
        if (max_len <= i) return 0;
        while (true) {
            if (prev_lh[i] != curr_lh[i]) return 0;
            if (i == 0) break;
            i -= 1;
        }
        i = min_len;
    }
    while (i < max_len) : (i += 1)
        if (prev_lh[i] != curr_lh[i]) break;
    return if (i >= consts.match.min_length) @intCast(i) else 0;
}

/// Current position of non-compressed data. Data before rp are already converted
/// to tokens.
pub fn pos(self: *Self) u16 {
    return @intCast(self.rp);
}

/// Notification that token list is cleared.
pub fn flush(self: *Self) void {
    self.fp = @intCast(self.rp);
}

/// Part of the buffer since last flush or null if there was slide in between (so
/// fp becomes negative).
pub fn tokensBuffer(self: *Self) ?[]const u8 {
    assert(self.fp <= self.rp);
    if (self.fp < 0) return null;
    return self.buffer[@intCast(self.fp)..self.rp];
}

test match {
    const data = "Blah blah blah blah blah!";
    var win: Self = .{};
    try expect(win.write(data) == data.len);
    try expect(win.wp == data.len);
    try expect(win.rp == 0);

    // length between l symbols
    try expect(win.match(1, 6, 0) == 18);
    try expect(win.match(1, 11, 0) == 13);
    try expect(win.match(1, 16, 0) == 8);
    try expect(win.match(1, 21, 0) == 0);

    // position 15 = "blah blah!"
    // position 20 = "blah!"
    try expect(win.match(15, 20, 0) == 4);
    try expect(win.match(15, 20, 3) == 4);
    try expect(win.match(15, 20, 4) == 0);
}

test slide {
    var win: Self = .{};
    win.wp = Self.buffer_len - 11;
    win.rp = Self.buffer_len - 111;
    win.buffer[win.rp] = 0xab;
    try expect(win.lookahead().len == 100);
    try expect(win.tokensBuffer().?.len == win.rp);

    const n = win.slide();
    try expect(n == 32757);
    try expect(win.buffer[win.rp] == 0xab);
    try expect(win.rp == Self.hist_len - 111);
    try expect(win.wp == Self.hist_len - 11);
    try expect(win.lookahead().len == 100);
    try expect(win.tokensBuffer() == null);
}
