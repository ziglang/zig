/// Lookup of the previous locations for the same 4 byte data. Works on hash of
/// 4 bytes data. Head contains position of the first match for each hash. Chain
/// points to the previous position of the same hash given the current location.
///
const std = @import("std");
const testing = std.testing;
const expect = testing.expect;
const consts = @import("consts.zig");

const Self = @This();

const prime4 = 0x9E3779B1; // 4 bytes prime number 2654435761
const chain_len = 2 * consts.history.len;

// Maps hash => first position
head: [consts.lookup.len]u16 = [_]u16{0} ** consts.lookup.len,
// Maps position => previous positions for the same hash value
chain: [chain_len]u16 = [_]u16{0} ** (chain_len),

// Calculates hash of the 4 bytes from data.
// Inserts `pos` position of that hash in the lookup tables.
// Returns previous location with the same hash value.
pub fn add(self: *Self, data: []const u8, pos: u16) u16 {
    if (data.len < 4) return 0;
    const h = hash(data[0..4]);
    return self.set(h, pos);
}

// Returns previous location with the same hash value given the current
// position.
pub fn prev(self: *Self, pos: u16) u16 {
    return self.chain[pos];
}

fn set(self: *Self, h: u32, pos: u16) u16 {
    const p = self.head[h];
    self.head[h] = pos;
    self.chain[pos] = p;
    return p;
}

// Slide all positions in head and chain for `n`
pub fn slide(self: *Self, n: u16) void {
    for (&self.head) |*v| {
        v.* -|= n;
    }
    var i: usize = 0;
    while (i < n) : (i += 1) {
        self.chain[i] = self.chain[i + n] -| n;
    }
}

// Add `len` 4 bytes hashes from `data` into lookup.
// Position of the first byte is `pos`.
pub fn bulkAdd(self: *Self, data: []const u8, len: u16, pos: u16) void {
    if (len == 0 or data.len < consts.match.min_length) {
        return;
    }
    var hb =
        @as(u32, data[3]) |
        @as(u32, data[2]) << 8 |
        @as(u32, data[1]) << 16 |
        @as(u32, data[0]) << 24;
    _ = self.set(hashu(hb), pos);

    var i = pos;
    for (4..@min(len + 3, data.len)) |j| {
        hb = (hb << 8) | @as(u32, data[j]);
        i += 1;
        _ = self.set(hashu(hb), i);
    }
}

// Calculates hash of the first 4 bytes of `b`.
fn hash(b: *const [4]u8) u32 {
    return hashu(@as(u32, b[3]) |
        @as(u32, b[2]) << 8 |
        @as(u32, b[1]) << 16 |
        @as(u32, b[0]) << 24);
}

fn hashu(v: u32) u32 {
    return @intCast((v *% prime4) >> consts.lookup.shift);
}

test add {
    const data = [_]u8{
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x01, 0x02, 0x03,
    };

    var h: Self = .{};
    for (data, 0..) |_, i| {
        const p = h.add(data[i..], @intCast(i));
        if (i >= 8 and i < 24) {
            try expect(p == i - 8);
        } else {
            try expect(p == 0);
        }
    }

    const v = Self.hash(data[2 .. 2 + 4]);
    try expect(h.head[v] == 2 + 16);
    try expect(h.chain[2 + 16] == 2 + 8);
    try expect(h.chain[2 + 8] == 2);
}

test bulkAdd {
    const data = "Lorem ipsum dolor sit amet, consectetur adipiscing elit.";

    // one by one
    var h: Self = .{};
    for (data, 0..) |_, i| {
        _ = h.add(data[i..], @intCast(i));
    }

    // in bulk
    var bh: Self = .{};
    bh.bulkAdd(data, data.len, 0);

    try testing.expectEqualSlices(u16, &h.head, &bh.head);
    try testing.expectEqualSlices(u16, &h.chain, &bh.chain);
}
