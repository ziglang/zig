//! The SHA-1 function is now considered cryptographically broken.
//! Namely, it is feasible to find multiple inputs producing the same hash.
//! For a fast-performing, cryptographically secure hash function, see SHA512/256, BLAKE2 or BLAKE3.

const Sha1 = @This();
const std = @import("../std.zig");
const mem = std.mem;
const math = std.math;
const assert = std.debug.assert;
const Writer = std.Io.Writer;

pub const block_length = 64;
pub const digest_length = 20;

s: [5]u32,
total_len: u64,
writer: Writer,

pub fn init(buffer: []u8) Sha1 {
    assert(buffer.len >= block_length);
    return .{
        .s = .{ 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0 },
        .total_len = 0,
        .writer = .{
            .buffer = buffer,
            .vtable = &vtable,
        },
    };
}

pub fn copy(sha1: *Sha1, buffer: []u8) Sha1 {
    assert(buffer.len >= block_length);
    const mine = sha1.writer.buffered();
    assert(mine.len <= block_length);
    @memcpy(buffer[0..mine.len], mine);
    return .{
        .s = sha1.s,
        .total_len = sha1.total_len,
        .writer = .{
            .buffer = buffer,
            .end = mine.len,
            .vtable = &vtable,
        },
    };
}

const vtable: Writer.VTable = .{ .drain = drain };

fn drain(w: *Writer, data: []const []const u8, splat: usize) Writer.Error!usize {
    const d: *Sha1 = @alignCast(@fieldParentPtr("writer", w));
    {
        const buf = w.buffered();
        var off: usize = 0;
        while (off + block_length <= buf.len) : (off += block_length) {
            round(&d.s, buf[off..][0..block_length]);
        }
        d.total_len += off;
        if (off != buf.len) return w.consume(off);
        w.end = 0;
    }
    if (data.len == 1 and splat == 0) return 0;
    var total_off: usize = 0;
    for (data) |buf| {
        var off: usize = 0;
        while (off + block_length <= buf.len) : (off += block_length) {
            round(&d.s, buf[off..][0..block_length]);
        }
        total_off += off;
        if (off != buf.len) break;
    }
    d.total_len += total_off;
    return total_off;
}

pub fn hash(data: []const u8) [digest_length]u8 {
    var buf: [block_length]u8 = undefined;
    var s: Sha1 = .init(&buf);
    s.writer.writeAll(data) catch unreachable;
    return s.final();
}

pub fn update(d: *Sha1, b: []const u8) void {
    d.writer.writeAll(b) catch unreachable;
}

pub fn final(d: *Sha1) [digest_length]u8 {
    _ = drain(&d.writer, &.{""}, 1) catch unreachable;
    const buf = d.writer.buffer[0..block_length];
    const pad = d.writer.end;
    assert(pad < block_length);
    d.total_len += pad;
    buf[pad] = 0x80; // Append padding bits.
    const end = pad + 1;
    @memset(buf[end..], 0);

    // > 448 mod 512 so need to add an extra round to wrap around.
    if (block_length - end < 8) {
        round(&d.s, buf);
        @memset(buf, 0);
    }

    // Append message length.
    var len = d.total_len >> 5;
    buf[63] = @as(u8, @intCast(d.total_len & 0x1f)) << 3;
    for (1..8) |i| {
        buf[63 - i] = @as(u8, @intCast(len & 0xff));
        len >>= 8;
    }

    round(&d.s, buf);

    var out: [digest_length]u8 = undefined;
    for (&d.s, 0..) |s, j| mem.writeInt(u32, out[4 * j ..][0..4], s, .big);
    return out;
}

pub fn round(d_s: *[5]u32, b: *const [block_length]u8) void {
    var s: [16]u32 = undefined;
    var v = d_s.*;

    const round0a = comptime [_]RoundParam{
        .abcdei(0, 1, 2, 3, 4, 0),
        .abcdei(4, 0, 1, 2, 3, 1),
        .abcdei(3, 4, 0, 1, 2, 2),
        .abcdei(2, 3, 4, 0, 1, 3),
        .abcdei(1, 2, 3, 4, 0, 4),
        .abcdei(0, 1, 2, 3, 4, 5),
        .abcdei(4, 0, 1, 2, 3, 6),
        .abcdei(3, 4, 0, 1, 2, 7),
        .abcdei(2, 3, 4, 0, 1, 8),
        .abcdei(1, 2, 3, 4, 0, 9),
        .abcdei(0, 1, 2, 3, 4, 10),
        .abcdei(4, 0, 1, 2, 3, 11),
        .abcdei(3, 4, 0, 1, 2, 12),
        .abcdei(2, 3, 4, 0, 1, 13),
        .abcdei(1, 2, 3, 4, 0, 14),
        .abcdei(0, 1, 2, 3, 4, 15),
    };
    inline for (round0a) |r| {
        s[r.i] = mem.readInt(u32, b[r.i * 4 ..][0..4], .big);

        v[r.e] = v[r.e] +% math.rotl(u32, v[r.a], @as(u32, 5)) +% 0x5A827999 +% s[r.i & 0xf] +% ((v[r.b] & v[r.c]) | (~v[r.b] & v[r.d]));
        v[r.b] = math.rotl(u32, v[r.b], @as(u32, 30));
    }

    const round0b = comptime [_]RoundParam{
        .abcdei(4, 0, 1, 2, 3, 16),
        .abcdei(3, 4, 0, 1, 2, 17),
        .abcdei(2, 3, 4, 0, 1, 18),
        .abcdei(1, 2, 3, 4, 0, 19),
    };
    inline for (round0b) |r| {
        const t = s[(r.i - 3) & 0xf] ^ s[(r.i - 8) & 0xf] ^ s[(r.i - 14) & 0xf] ^ s[(r.i - 16) & 0xf];
        s[r.i & 0xf] = math.rotl(u32, t, @as(u32, 1));

        v[r.e] = v[r.e] +% math.rotl(u32, v[r.a], @as(u32, 5)) +% 0x5A827999 +% s[r.i & 0xf] +% ((v[r.b] & v[r.c]) | (~v[r.b] & v[r.d]));
        v[r.b] = math.rotl(u32, v[r.b], @as(u32, 30));
    }

    const round1 = comptime [_]RoundParam{
        .abcdei(0, 1, 2, 3, 4, 20),
        .abcdei(4, 0, 1, 2, 3, 21),
        .abcdei(3, 4, 0, 1, 2, 22),
        .abcdei(2, 3, 4, 0, 1, 23),
        .abcdei(1, 2, 3, 4, 0, 24),
        .abcdei(0, 1, 2, 3, 4, 25),
        .abcdei(4, 0, 1, 2, 3, 26),
        .abcdei(3, 4, 0, 1, 2, 27),
        .abcdei(2, 3, 4, 0, 1, 28),
        .abcdei(1, 2, 3, 4, 0, 29),
        .abcdei(0, 1, 2, 3, 4, 30),
        .abcdei(4, 0, 1, 2, 3, 31),
        .abcdei(3, 4, 0, 1, 2, 32),
        .abcdei(2, 3, 4, 0, 1, 33),
        .abcdei(1, 2, 3, 4, 0, 34),
        .abcdei(0, 1, 2, 3, 4, 35),
        .abcdei(4, 0, 1, 2, 3, 36),
        .abcdei(3, 4, 0, 1, 2, 37),
        .abcdei(2, 3, 4, 0, 1, 38),
        .abcdei(1, 2, 3, 4, 0, 39),
    };
    inline for (round1) |r| {
        const t = s[(r.i - 3) & 0xf] ^ s[(r.i - 8) & 0xf] ^ s[(r.i - 14) & 0xf] ^ s[(r.i - 16) & 0xf];
        s[r.i & 0xf] = math.rotl(u32, t, @as(u32, 1));

        v[r.e] = v[r.e] +% math.rotl(u32, v[r.a], @as(u32, 5)) +% 0x6ED9EBA1 +% s[r.i & 0xf] +% (v[r.b] ^ v[r.c] ^ v[r.d]);
        v[r.b] = math.rotl(u32, v[r.b], @as(u32, 30));
    }

    const round2 = comptime [_]RoundParam{
        .abcdei(0, 1, 2, 3, 4, 40),
        .abcdei(4, 0, 1, 2, 3, 41),
        .abcdei(3, 4, 0, 1, 2, 42),
        .abcdei(2, 3, 4, 0, 1, 43),
        .abcdei(1, 2, 3, 4, 0, 44),
        .abcdei(0, 1, 2, 3, 4, 45),
        .abcdei(4, 0, 1, 2, 3, 46),
        .abcdei(3, 4, 0, 1, 2, 47),
        .abcdei(2, 3, 4, 0, 1, 48),
        .abcdei(1, 2, 3, 4, 0, 49),
        .abcdei(0, 1, 2, 3, 4, 50),
        .abcdei(4, 0, 1, 2, 3, 51),
        .abcdei(3, 4, 0, 1, 2, 52),
        .abcdei(2, 3, 4, 0, 1, 53),
        .abcdei(1, 2, 3, 4, 0, 54),
        .abcdei(0, 1, 2, 3, 4, 55),
        .abcdei(4, 0, 1, 2, 3, 56),
        .abcdei(3, 4, 0, 1, 2, 57),
        .abcdei(2, 3, 4, 0, 1, 58),
        .abcdei(1, 2, 3, 4, 0, 59),
    };
    inline for (round2) |r| {
        const t = s[(r.i - 3) & 0xf] ^ s[(r.i - 8) & 0xf] ^ s[(r.i - 14) & 0xf] ^ s[(r.i - 16) & 0xf];
        s[r.i & 0xf] = math.rotl(u32, t, @as(u32, 1));

        v[r.e] = v[r.e] +% math.rotl(u32, v[r.a], @as(u32, 5)) +% 0x8F1BBCDC +% s[r.i & 0xf] +% ((v[r.b] & v[r.c]) ^ (v[r.b] & v[r.d]) ^ (v[r.c] & v[r.d]));
        v[r.b] = math.rotl(u32, v[r.b], @as(u32, 30));
    }

    const round3 = comptime [_]RoundParam{
        .abcdei(0, 1, 2, 3, 4, 60),
        .abcdei(4, 0, 1, 2, 3, 61),
        .abcdei(3, 4, 0, 1, 2, 62),
        .abcdei(2, 3, 4, 0, 1, 63),
        .abcdei(1, 2, 3, 4, 0, 64),
        .abcdei(0, 1, 2, 3, 4, 65),
        .abcdei(4, 0, 1, 2, 3, 66),
        .abcdei(3, 4, 0, 1, 2, 67),
        .abcdei(2, 3, 4, 0, 1, 68),
        .abcdei(1, 2, 3, 4, 0, 69),
        .abcdei(0, 1, 2, 3, 4, 70),
        .abcdei(4, 0, 1, 2, 3, 71),
        .abcdei(3, 4, 0, 1, 2, 72),
        .abcdei(2, 3, 4, 0, 1, 73),
        .abcdei(1, 2, 3, 4, 0, 74),
        .abcdei(0, 1, 2, 3, 4, 75),
        .abcdei(4, 0, 1, 2, 3, 76),
        .abcdei(3, 4, 0, 1, 2, 77),
        .abcdei(2, 3, 4, 0, 1, 78),
        .abcdei(1, 2, 3, 4, 0, 79),
    };
    inline for (round3) |r| {
        const t = s[(r.i - 3) & 0xf] ^ s[(r.i - 8) & 0xf] ^ s[(r.i - 14) & 0xf] ^ s[(r.i - 16) & 0xf];
        s[r.i & 0xf] = math.rotl(u32, t, @as(u32, 1));

        v[r.e] = v[r.e] +% math.rotl(u32, v[r.a], @as(u32, 5)) +% 0xCA62C1D6 +% s[r.i & 0xf] +% (v[r.b] ^ v[r.c] ^ v[r.d]);
        v[r.b] = math.rotl(u32, v[r.b], @as(u32, 30));
    }

    d_s[0] +%= v[0];
    d_s[1] +%= v[1];
    d_s[2] +%= v[2];
    d_s[3] +%= v[3];
    d_s[4] +%= v[4];
}

const RoundParam = struct {
    a: usize,
    b: usize,
    c: usize,
    d: usize,
    e: usize,
    i: u32,

    fn abcdei(a: usize, b: usize, c: usize, d: usize, e: usize, i: u32) RoundParam {
        return .{
            .a = a,
            .b = b,
            .c = c,
            .d = d,
            .e = e,
            .i = i,
        };
    }
};

const htest = @import("test.zig");

test "sha1 single" {
    try htest.assertEqualHash(Sha1, "da39a3ee5e6b4b0d3255bfef95601890afd80709", "");
    try htest.assertEqualHash(Sha1, "a9993e364706816aba3e25717850c26c9cd0d89d", "abc");
    try htest.assertEqualHash(Sha1, "a49b2446a02c645bf419f995b67091253a04a259", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha1 streaming" {
    var buffer: [block_length]u8 = undefined;
    var h: Sha1 = .init(&buffer);
    var out: [20]u8 = undefined;

    out = h.final();
    try htest.assertEqual("da39a3ee5e6b4b0d3255bfef95601890afd80709", out[0..]);

    h = .init(&buffer);
    h.update("abc");
    out = h.final();
    try htest.assertEqual("a9993e364706816aba3e25717850c26c9cd0d89d", out[0..]);

    h = .init(&buffer);
    h.update("a");
    h.update("b");
    h.update("c");
    out = h.final();
    try htest.assertEqual("a9993e364706816aba3e25717850c26c9cd0d89d", out[0..]);
}

test "sha1 aligned final" {
    var block: [block_length]u8 = @splat(0);
    var out: [Sha1.digest_length]u8 = undefined;
    var buffer: [block_length]u8 = undefined;

    var h: Sha1 = .init(&buffer);
    h.update(&block);
    out = h.final();
}
