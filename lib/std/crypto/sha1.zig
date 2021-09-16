const std = @import("../std.zig");
const mem = std.mem;
const math = std.math;

const RoundParam = struct {
    a: usize,
    b: usize,
    c: usize,
    d: usize,
    e: usize,
    i: u32,
};

fn roundParam(a: usize, b: usize, c: usize, d: usize, e: usize, i: u32) RoundParam {
    return RoundParam{
        .a = a,
        .b = b,
        .c = c,
        .d = d,
        .e = e,
        .i = i,
    };
}

/// The SHA-1 function is now considered cryptographically broken.
/// Namely, it is feasible to find multiple inputs producing the same hash.
/// For a fast-performing, cryptographically secure hash function, see SHA512/256, BLAKE2 or BLAKE3.
pub const Sha1 = struct {
    const Self = @This();
    pub const block_length = 64;
    pub const digest_length = 20;
    pub const Options = struct {};

    s: [5]u32,
    // Streaming Cache
    buf: [64]u8 = undefined,
    buf_len: u8 = 0,
    total_len: u64 = 0,

    pub fn init(options: Options) Self {
        _ = options;
        return Self{
            .s = [_]u32{
                0x67452301,
                0xEFCDAB89,
                0x98BADCFE,
                0x10325476,
                0xC3D2E1F0,
            },
        };
    }

    pub fn hash(in: []const u8, out: *[digest_length]u8, options: Options) void {
        var self = Sha1.init(options);
        self.update(in);
        self.final(out);
    }

    pub fn update(self: *Self, in: []const u8) void {
        var off: usize = 0;

        // Partial buffer exists from previous update. Copy into buffer then hash.
        if (self.buf_len != 0 and self.buf_len + in.len >= 64) {
            off += 64 - self.buf_len;
            mem.copy(u8, self.buf[self.buf_len..], in[0..off]);

            self.round(self.buf[0..]);
            self.buf_len = 0;
        }

        // Full middle blocks.
        while (off + 64 <= in.len) : (off += 64) {
            self.round(in[off..][0..64]);
        }

        // Copy any remainder for next pass.
        mem.copy(u8, self.buf[self.buf_len..], in[off..]);
        self.buf_len += @intCast(u8, in[off..].len);

        self.total_len += in.len;
    }

    pub fn final(self: *Self, out: *[digest_length]u8) void {
        // The buffer here will never be completely full.
        mem.set(u8, self.buf[self.buf_len..], 0);

        // Append padding bits.
        self.buf[self.buf_len] = 0x80;
        self.buf_len += 1;

        // > 448 mod 512 so need to add an extra round to wrap around.
        if (64 - self.buf_len < 8) {
            self.round(self.buf[0..]);
            mem.set(u8, self.buf[0..], 0);
        }

        // Append message length.
        var i: usize = 1;
        var len = self.total_len >> 5;
        self.buf[63] = @intCast(u8, self.total_len & 0x1f) << 3;
        while (i < 8) : (i += 1) {
            self.buf[63 - i] = @intCast(u8, len & 0xff);
            len >>= 8;
        }

        self.round(self.buf[0..]);

        for (self.s) |s, j| {
            mem.writeIntBig(u32, out[4 * j ..][0..4], s);
        }
    }

    fn round(self: *Self, in: *const [64]u8) void {
        var s: [16]u32 = undefined;

        var v: [5]u32 = [_]u32{
            self.s[0],
            self.s[1],
            self.s[2],
            self.s[3],
            self.s[4],
        };

        const round0a = comptime [_]RoundParam{
            roundParam(0, 1, 2, 3, 4, 0),
            roundParam(4, 0, 1, 2, 3, 1),
            roundParam(3, 4, 0, 1, 2, 2),
            roundParam(2, 3, 4, 0, 1, 3),
            roundParam(1, 2, 3, 4, 0, 4),
            roundParam(0, 1, 2, 3, 4, 5),
            roundParam(4, 0, 1, 2, 3, 6),
            roundParam(3, 4, 0, 1, 2, 7),
            roundParam(2, 3, 4, 0, 1, 8),
            roundParam(1, 2, 3, 4, 0, 9),
            roundParam(0, 1, 2, 3, 4, 10),
            roundParam(4, 0, 1, 2, 3, 11),
            roundParam(3, 4, 0, 1, 2, 12),
            roundParam(2, 3, 4, 0, 1, 13),
            roundParam(1, 2, 3, 4, 0, 14),
            roundParam(0, 1, 2, 3, 4, 15),
        };
        inline for (round0a) |r| {
            s[r.i] = (@as(u32, in[r.i * 4 + 0]) << 24) | (@as(u32, in[r.i * 4 + 1]) << 16) | (@as(u32, in[r.i * 4 + 2]) << 8) | (@as(u32, in[r.i * 4 + 3]) << 0);

            v[r.e] = v[r.e] +% math.rotl(u32, v[r.a], @as(u32, 5)) +% 0x5A827999 +% s[r.i & 0xf] +% ((v[r.b] & v[r.c]) | (~v[r.b] & v[r.d]));
            v[r.b] = math.rotl(u32, v[r.b], @as(u32, 30));
        }

        const round0b = comptime [_]RoundParam{
            roundParam(4, 0, 1, 2, 3, 16),
            roundParam(3, 4, 0, 1, 2, 17),
            roundParam(2, 3, 4, 0, 1, 18),
            roundParam(1, 2, 3, 4, 0, 19),
        };
        inline for (round0b) |r| {
            const t = s[(r.i - 3) & 0xf] ^ s[(r.i - 8) & 0xf] ^ s[(r.i - 14) & 0xf] ^ s[(r.i - 16) & 0xf];
            s[r.i & 0xf] = math.rotl(u32, t, @as(u32, 1));

            v[r.e] = v[r.e] +% math.rotl(u32, v[r.a], @as(u32, 5)) +% 0x5A827999 +% s[r.i & 0xf] +% ((v[r.b] & v[r.c]) | (~v[r.b] & v[r.d]));
            v[r.b] = math.rotl(u32, v[r.b], @as(u32, 30));
        }

        const round1 = comptime [_]RoundParam{
            roundParam(0, 1, 2, 3, 4, 20),
            roundParam(4, 0, 1, 2, 3, 21),
            roundParam(3, 4, 0, 1, 2, 22),
            roundParam(2, 3, 4, 0, 1, 23),
            roundParam(1, 2, 3, 4, 0, 24),
            roundParam(0, 1, 2, 3, 4, 25),
            roundParam(4, 0, 1, 2, 3, 26),
            roundParam(3, 4, 0, 1, 2, 27),
            roundParam(2, 3, 4, 0, 1, 28),
            roundParam(1, 2, 3, 4, 0, 29),
            roundParam(0, 1, 2, 3, 4, 30),
            roundParam(4, 0, 1, 2, 3, 31),
            roundParam(3, 4, 0, 1, 2, 32),
            roundParam(2, 3, 4, 0, 1, 33),
            roundParam(1, 2, 3, 4, 0, 34),
            roundParam(0, 1, 2, 3, 4, 35),
            roundParam(4, 0, 1, 2, 3, 36),
            roundParam(3, 4, 0, 1, 2, 37),
            roundParam(2, 3, 4, 0, 1, 38),
            roundParam(1, 2, 3, 4, 0, 39),
        };
        inline for (round1) |r| {
            const t = s[(r.i - 3) & 0xf] ^ s[(r.i - 8) & 0xf] ^ s[(r.i - 14) & 0xf] ^ s[(r.i - 16) & 0xf];
            s[r.i & 0xf] = math.rotl(u32, t, @as(u32, 1));

            v[r.e] = v[r.e] +% math.rotl(u32, v[r.a], @as(u32, 5)) +% 0x6ED9EBA1 +% s[r.i & 0xf] +% (v[r.b] ^ v[r.c] ^ v[r.d]);
            v[r.b] = math.rotl(u32, v[r.b], @as(u32, 30));
        }

        const round2 = comptime [_]RoundParam{
            roundParam(0, 1, 2, 3, 4, 40),
            roundParam(4, 0, 1, 2, 3, 41),
            roundParam(3, 4, 0, 1, 2, 42),
            roundParam(2, 3, 4, 0, 1, 43),
            roundParam(1, 2, 3, 4, 0, 44),
            roundParam(0, 1, 2, 3, 4, 45),
            roundParam(4, 0, 1, 2, 3, 46),
            roundParam(3, 4, 0, 1, 2, 47),
            roundParam(2, 3, 4, 0, 1, 48),
            roundParam(1, 2, 3, 4, 0, 49),
            roundParam(0, 1, 2, 3, 4, 50),
            roundParam(4, 0, 1, 2, 3, 51),
            roundParam(3, 4, 0, 1, 2, 52),
            roundParam(2, 3, 4, 0, 1, 53),
            roundParam(1, 2, 3, 4, 0, 54),
            roundParam(0, 1, 2, 3, 4, 55),
            roundParam(4, 0, 1, 2, 3, 56),
            roundParam(3, 4, 0, 1, 2, 57),
            roundParam(2, 3, 4, 0, 1, 58),
            roundParam(1, 2, 3, 4, 0, 59),
        };
        inline for (round2) |r| {
            const t = s[(r.i - 3) & 0xf] ^ s[(r.i - 8) & 0xf] ^ s[(r.i - 14) & 0xf] ^ s[(r.i - 16) & 0xf];
            s[r.i & 0xf] = math.rotl(u32, t, @as(u32, 1));

            v[r.e] = v[r.e] +% math.rotl(u32, v[r.a], @as(u32, 5)) +% 0x8F1BBCDC +% s[r.i & 0xf] +% ((v[r.b] & v[r.c]) ^ (v[r.b] & v[r.d]) ^ (v[r.c] & v[r.d]));
            v[r.b] = math.rotl(u32, v[r.b], @as(u32, 30));
        }

        const round3 = comptime [_]RoundParam{
            roundParam(0, 1, 2, 3, 4, 60),
            roundParam(4, 0, 1, 2, 3, 61),
            roundParam(3, 4, 0, 1, 2, 62),
            roundParam(2, 3, 4, 0, 1, 63),
            roundParam(1, 2, 3, 4, 0, 64),
            roundParam(0, 1, 2, 3, 4, 65),
            roundParam(4, 0, 1, 2, 3, 66),
            roundParam(3, 4, 0, 1, 2, 67),
            roundParam(2, 3, 4, 0, 1, 68),
            roundParam(1, 2, 3, 4, 0, 69),
            roundParam(0, 1, 2, 3, 4, 70),
            roundParam(4, 0, 1, 2, 3, 71),
            roundParam(3, 4, 0, 1, 2, 72),
            roundParam(2, 3, 4, 0, 1, 73),
            roundParam(1, 2, 3, 4, 0, 74),
            roundParam(0, 1, 2, 3, 4, 75),
            roundParam(4, 0, 1, 2, 3, 76),
            roundParam(3, 4, 0, 1, 2, 77),
            roundParam(2, 3, 4, 0, 1, 78),
            roundParam(1, 2, 3, 4, 0, 79),
        };
        inline for (round3) |r| {
            const t = s[(r.i - 3) & 0xf] ^ s[(r.i - 8) & 0xf] ^ s[(r.i - 14) & 0xf] ^ s[(r.i - 16) & 0xf];
            s[r.i & 0xf] = math.rotl(u32, t, @as(u32, 1));

            v[r.e] = v[r.e] +% math.rotl(u32, v[r.a], @as(u32, 5)) +% 0xCA62C1D6 +% s[r.i & 0xf] +% (v[r.b] ^ v[r.c] ^ v[r.d]);
            v[r.b] = math.rotl(u32, v[r.b], @as(u32, 30));
        }

        self.s[0] +%= v[0];
        self.s[1] +%= v[1];
        self.s[2] +%= v[2];
        self.s[3] +%= v[3];
        self.s[4] +%= v[4];
    }
};

const htest = @import("test.zig");

test "sha1 single" {
    try htest.assertEqualHash(Sha1, "da39a3ee5e6b4b0d3255bfef95601890afd80709", "");
    try htest.assertEqualHash(Sha1, "a9993e364706816aba3e25717850c26c9cd0d89d", "abc");
    try htest.assertEqualHash(Sha1, "a49b2446a02c645bf419f995b67091253a04a259", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha1 streaming" {
    var h = Sha1.init(.{});
    var out: [20]u8 = undefined;

    h.final(&out);
    try htest.assertEqual("da39a3ee5e6b4b0d3255bfef95601890afd80709", out[0..]);

    h = Sha1.init(.{});
    h.update("abc");
    h.final(&out);
    try htest.assertEqual("a9993e364706816aba3e25717850c26c9cd0d89d", out[0..]);

    h = Sha1.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(&out);
    try htest.assertEqual("a9993e364706816aba3e25717850c26c9cd0d89d", out[0..]);
}

test "sha1 aligned final" {
    var block = [_]u8{0} ** Sha1.block_length;
    var out: [Sha1.digest_length]u8 = undefined;

    var h = Sha1.init(.{});
    h.update(&block);
    h.final(out[0..]);
}
