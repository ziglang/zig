const std = @import("../std.zig");
const mem = std.mem;
const math = std.math;
const debug = std.debug;
const htest = @import("test.zig");

const RoundParam = struct {
    a: usize,
    b: usize,
    c: usize,
    d: usize,
    x: usize,
    y: usize,
};

fn roundParam(a: usize, b: usize, c: usize, d: usize, x: usize, y: usize) RoundParam {
    return RoundParam{
        .a = a,
        .b = b,
        .c = c,
        .d = d,
        .x = x,
        .y = y,
    };
}

/////////////////////
// Blake2s

pub const Blake2s128 = Blake2s(128);
pub const Blake2s160 = Blake2s(160);
pub const Blake2s224 = Blake2s(224);
pub const Blake2s256 = Blake2s(256);

pub fn Blake2s(comptime out_bits: usize) type {
    return struct {
        const Self = @This();
        pub const block_length = 64;
        pub const digest_length = out_bits / 8;
        pub const key_length_min = 0;
        pub const key_length_max = 32;
        pub const key_length = 32; // recommended key length
        pub const Options = struct { key: ?[]const u8 = null, salt: ?[8]u8 = null, context: ?[8]u8 = null, expected_out_bits: usize = out_bits };

        const iv = [8]u32{
            0x6A09E667,
            0xBB67AE85,
            0x3C6EF372,
            0xA54FF53A,
            0x510E527F,
            0x9B05688C,
            0x1F83D9AB,
            0x5BE0CD19,
        };

        const sigma = [10][16]u8{
            [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
            [_]u8{ 14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3 },
            [_]u8{ 11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4 },
            [_]u8{ 7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8 },
            [_]u8{ 9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13 },
            [_]u8{ 2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9 },
            [_]u8{ 12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11 },
            [_]u8{ 13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10 },
            [_]u8{ 6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5 },
            [_]u8{ 10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0 },
        };

        h: [8]u32,
        t: u64,
        // Streaming cache
        buf: [64]u8,
        buf_len: u8,

        pub fn init(options: Options) Self {
            comptime debug.assert(8 <= out_bits and out_bits <= 256);

            var d: Self = undefined;
            mem.copy(u32, d.h[0..], iv[0..]);

            const key_len = if (options.key) |key| key.len else 0;
            // default parameters
            d.h[0] ^= 0x01010000 ^ @truncate(u32, key_len << 8) ^ @intCast(u32, options.expected_out_bits >> 3);
            d.t = 0;
            d.buf_len = 0;

            if (options.salt) |salt| {
                d.h[4] ^= mem.readIntLittle(u32, salt[0..4]);
                d.h[5] ^= mem.readIntLittle(u32, salt[4..8]);
            }
            if (options.context) |context| {
                d.h[6] ^= mem.readIntLittle(u32, context[0..4]);
                d.h[7] ^= mem.readIntLittle(u32, context[4..8]);
            }
            if (key_len > 0) {
                mem.set(u8, d.buf[key_len..], 0);
                d.update(options.key.?);
                d.buf_len = 64;
            }
            return d;
        }

        pub fn hash(b: []const u8, out: *[digest_length]u8, options: Options) void {
            var d = Self.init(options);
            d.update(b);
            d.final(out);
        }

        pub fn update(d: *Self, b: []const u8) void {
            var off: usize = 0;

            // Partial buffer exists from previous update. Copy into buffer then hash.
            if (d.buf_len != 0 and d.buf_len + b.len > 64) {
                off += 64 - d.buf_len;
                mem.copy(u8, d.buf[d.buf_len..], b[0..off]);
                d.t += 64;
                d.round(d.buf[0..], false);
                d.buf_len = 0;
            }

            // Full middle blocks.
            while (off + 64 < b.len) : (off += 64) {
                d.t += 64;
                d.round(b[off..][0..64], false);
            }

            // Copy any remainder for next pass.
            mem.copy(u8, d.buf[d.buf_len..], b[off..]);
            d.buf_len += @intCast(u8, b[off..].len);
        }

        pub fn final(d: *Self, out: *[digest_length]u8) void {
            mem.set(u8, d.buf[d.buf_len..], 0);
            d.t += d.buf_len;
            d.round(d.buf[0..], true);
            for (d.h) |*x| x.* = mem.nativeToLittle(u32, x.*);
            mem.copy(u8, out[0..], @ptrCast(*[digest_length]u8, &d.h));
        }

        fn round(d: *Self, b: *const [64]u8, last: bool) void {
            var m: [16]u32 = undefined;
            var v: [16]u32 = undefined;

            for (m) |*r, i| {
                r.* = mem.readIntLittle(u32, b[4 * i ..][0..4]);
            }

            var k: usize = 0;
            while (k < 8) : (k += 1) {
                v[k] = d.h[k];
                v[k + 8] = iv[k];
            }

            v[12] ^= @truncate(u32, d.t);
            v[13] ^= @intCast(u32, d.t >> 32);
            if (last) v[14] = ~v[14];

            const rounds = comptime [_]RoundParam{
                roundParam(0, 4, 8, 12, 0, 1),
                roundParam(1, 5, 9, 13, 2, 3),
                roundParam(2, 6, 10, 14, 4, 5),
                roundParam(3, 7, 11, 15, 6, 7),
                roundParam(0, 5, 10, 15, 8, 9),
                roundParam(1, 6, 11, 12, 10, 11),
                roundParam(2, 7, 8, 13, 12, 13),
                roundParam(3, 4, 9, 14, 14, 15),
            };

            comptime var j: usize = 0;
            inline while (j < 10) : (j += 1) {
                inline for (rounds) |r| {
                    v[r.a] = v[r.a] +% v[r.b] +% m[sigma[j][r.x]];
                    v[r.d] = math.rotr(u32, v[r.d] ^ v[r.a], @as(usize, 16));
                    v[r.c] = v[r.c] +% v[r.d];
                    v[r.b] = math.rotr(u32, v[r.b] ^ v[r.c], @as(usize, 12));
                    v[r.a] = v[r.a] +% v[r.b] +% m[sigma[j][r.y]];
                    v[r.d] = math.rotr(u32, v[r.d] ^ v[r.a], @as(usize, 8));
                    v[r.c] = v[r.c] +% v[r.d];
                    v[r.b] = math.rotr(u32, v[r.b] ^ v[r.c], @as(usize, 7));
                }
            }

            for (d.h) |*r, i| {
                r.* ^= v[i] ^ v[i + 8];
            }
        }

        pub const Error = error{};
        pub const Writer = std.io.Writer(*Self, Error, write);

        fn write(self: *Self, bytes: []const u8) Error!usize {
            self.update(bytes);
            return bytes.len;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }
    };
}

test "blake2s160 single" {
    const h1 = "354c9c33f735962418bdacb9479873429c34916f";
    try htest.assertEqualHash(Blake2s160, h1, "");

    const h2 = "5ae3b99be29b01834c3b508521ede60438f8de17";
    try htest.assertEqualHash(Blake2s160, h2, "abc");

    const h3 = "5a604fec9713c369e84b0ed68daed7d7504ef240";
    try htest.assertEqualHash(Blake2s160, h3, "The quick brown fox jumps over the lazy dog");

    const h4 = "b60c4dc60e2681e58fbc24e77f07e02c69e72ed0";
    try htest.assertEqualHash(Blake2s160, h4, "a" ** 32 ++ "b" ** 32);
}

test "blake2s160 streaming" {
    var h = Blake2s160.init(.{});
    var out: [20]u8 = undefined;

    const h1 = "354c9c33f735962418bdacb9479873429c34916f";

    h.final(out[0..]);
    try htest.assertEqual(h1, out[0..]);

    const h2 = "5ae3b99be29b01834c3b508521ede60438f8de17";

    h = Blake2s160.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    h = Blake2s160.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    const h3 = "b60c4dc60e2681e58fbc24e77f07e02c69e72ed0";

    h = Blake2s160.init(.{});
    h.update("a" ** 32);
    h.update("b" ** 32);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    h = Blake2s160.init(.{});
    h.update("a" ** 32 ++ "b" ** 32);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    const h4 = "4667fd60791a7fe41f939bca646b4529e296bd68";

    h = Blake2s160.init(.{ .context = [_]u8{0x69} ** 8, .salt = [_]u8{0x42} ** 8 });
    h.update("a" ** 32);
    h.update("b" ** 32);
    h.final(out[0..]);
    try htest.assertEqual(h4, out[0..]);

    h = Blake2s160.init(.{ .context = [_]u8{0x69} ** 8, .salt = [_]u8{0x42} ** 8 });
    h.update("a" ** 32 ++ "b" ** 32);
    h.final(out[0..]);
    try htest.assertEqual(h4, out[0..]);
}

test "comptime blake2s160" {
    //comptime
    {
        @setEvalBranchQuota(10000);
        var block = [_]u8{0} ** Blake2s160.block_length;
        var out: [Blake2s160.digest_length]u8 = undefined;

        const h1 = "2c56ad9d0b2c8b474aafa93ab307db2f0940105f";

        try htest.assertEqualHash(Blake2s160, h1, block[0..]);

        var h = Blake2s160.init(.{});
        h.update(&block);
        h.final(out[0..]);

        try htest.assertEqual(h1, out[0..]);
    }
}

test "blake2s224 single" {
    const h1 = "1fa1291e65248b37b3433475b2a0dd63d54a11ecc4e3e034e7bc1ef4";
    try htest.assertEqualHash(Blake2s224, h1, "");

    const h2 = "0b033fc226df7abde29f67a05d3dc62cf271ef3dfea4d387407fbd55";
    try htest.assertEqualHash(Blake2s224, h2, "abc");

    const h3 = "e4e5cb6c7cae41982b397bf7b7d2d9d1949823ae78435326e8db4912";
    try htest.assertEqualHash(Blake2s224, h3, "The quick brown fox jumps over the lazy dog");

    const h4 = "557381a78facd2b298640f4e32113e58967d61420af1aa939d0cfe01";
    try htest.assertEqualHash(Blake2s224, h4, "a" ** 32 ++ "b" ** 32);
}

test "blake2s224 streaming" {
    var h = Blake2s224.init(.{});
    var out: [28]u8 = undefined;

    const h1 = "1fa1291e65248b37b3433475b2a0dd63d54a11ecc4e3e034e7bc1ef4";

    h.final(out[0..]);
    try htest.assertEqual(h1, out[0..]);

    const h2 = "0b033fc226df7abde29f67a05d3dc62cf271ef3dfea4d387407fbd55";

    h = Blake2s224.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    h = Blake2s224.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    const h3 = "557381a78facd2b298640f4e32113e58967d61420af1aa939d0cfe01";

    h = Blake2s224.init(.{});
    h.update("a" ** 32);
    h.update("b" ** 32);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    h = Blake2s224.init(.{});
    h.update("a" ** 32 ++ "b" ** 32);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    const h4 = "a4d6a9d253441b80e5dfd60a04db169ffab77aec56a2855c402828c3";

    h = Blake2s224.init(.{ .context = [_]u8{0x69} ** 8, .salt = [_]u8{0x42} ** 8 });
    h.update("a" ** 32);
    h.update("b" ** 32);
    h.final(out[0..]);
    try htest.assertEqual(h4, out[0..]);

    h = Blake2s224.init(.{ .context = [_]u8{0x69} ** 8, .salt = [_]u8{0x42} ** 8 });
    h.update("a" ** 32 ++ "b" ** 32);
    h.final(out[0..]);
    try htest.assertEqual(h4, out[0..]);
}

test "comptime blake2s224" {
    comptime {
        @setEvalBranchQuota(10000);
        var block = [_]u8{0} ** Blake2s224.block_length;
        var out: [Blake2s224.digest_length]u8 = undefined;

        const h1 = "86b7611563293f8c73627df7a6d6ba25ca0548c2a6481f7d116ee576";

        try htest.assertEqualHash(Blake2s224, h1, block[0..]);

        var h = Blake2s224.init(.{});
        h.update(&block);
        h.final(out[0..]);

        try htest.assertEqual(h1, out[0..]);
    }
}

test "blake2s256 single" {
    const h1 = "69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9";
    try htest.assertEqualHash(Blake2s256, h1, "");

    const h2 = "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982";
    try htest.assertEqualHash(Blake2s256, h2, "abc");

    const h3 = "606beeec743ccbeff6cbcdf5d5302aa855c256c29b88c8ed331ea1a6bf3c8812";
    try htest.assertEqualHash(Blake2s256, h3, "The quick brown fox jumps over the lazy dog");

    const h4 = "8d8711dade07a6b92b9a3ea1f40bee9b2c53ff3edd2a273dec170b0163568977";
    try htest.assertEqualHash(Blake2s256, h4, "a" ** 32 ++ "b" ** 32);
}

test "blake2s256 streaming" {
    var h = Blake2s256.init(.{});
    var out: [32]u8 = undefined;

    const h1 = "69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9";

    h.final(out[0..]);
    try htest.assertEqual(h1, out[0..]);

    const h2 = "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982";

    h = Blake2s256.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    h = Blake2s256.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    const h3 = "8d8711dade07a6b92b9a3ea1f40bee9b2c53ff3edd2a273dec170b0163568977";

    h = Blake2s256.init(.{});
    h.update("a" ** 32);
    h.update("b" ** 32);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    h = Blake2s256.init(.{});
    h.update("a" ** 32 ++ "b" ** 32);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);
}

test "blake2s256 keyed" {
    var out: [32]u8 = undefined;

    const h1 = "10f918da4d74fab3302e48a5d67d03804b1ec95372a62a0f33b7c9fa28ba1ae6";
    const key = "secret_key";

    Blake2s256.hash("a" ** 64 ++ "b" ** 64, &out, .{ .key = key });
    try htest.assertEqual(h1, out[0..]);

    var h = Blake2s256.init(.{ .key = key });
    h.update("a" ** 64 ++ "b" ** 64);
    h.final(out[0..]);

    try htest.assertEqual(h1, out[0..]);

    h = Blake2s256.init(.{ .key = key });
    h.update("a" ** 64);
    h.update("b" ** 64);
    h.final(out[0..]);

    try htest.assertEqual(h1, out[0..]);
}

test "comptime blake2s256" {
    comptime {
        @setEvalBranchQuota(10000);
        var block = [_]u8{0} ** Blake2s256.block_length;
        var out: [Blake2s256.digest_length]u8 = undefined;

        const h1 = "ae09db7cd54f42b490ef09b6bc541af688e4959bb8c53f359a6f56e38ab454a3";

        try htest.assertEqualHash(Blake2s256, h1, block[0..]);

        var h = Blake2s256.init(.{});
        h.update(&block);
        h.final(out[0..]);

        try htest.assertEqual(h1, out[0..]);
    }
}

/////////////////////
// Blake2b

pub const Blake2b128 = Blake2b(128);
pub const Blake2b160 = Blake2b(160);
pub const Blake2b256 = Blake2b(256);
pub const Blake2b384 = Blake2b(384);
pub const Blake2b512 = Blake2b(512);

pub fn Blake2b(comptime out_bits: usize) type {
    return struct {
        const Self = @This();
        pub const block_length = 128;
        pub const digest_length = out_bits / 8;
        pub const key_length_min = 0;
        pub const key_length_max = 64;
        pub const key_length = 32; // recommended key length
        pub const Options = struct { key: ?[]const u8 = null, salt: ?[16]u8 = null, context: ?[16]u8 = null, expected_out_bits: usize = out_bits };

        const iv = [8]u64{
            0x6a09e667f3bcc908,
            0xbb67ae8584caa73b,
            0x3c6ef372fe94f82b,
            0xa54ff53a5f1d36f1,
            0x510e527fade682d1,
            0x9b05688c2b3e6c1f,
            0x1f83d9abfb41bd6b,
            0x5be0cd19137e2179,
        };

        const sigma = [12][16]u8{
            [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
            [_]u8{ 14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3 },
            [_]u8{ 11, 8, 12, 0, 5, 2, 15, 13, 10, 14, 3, 6, 7, 1, 9, 4 },
            [_]u8{ 7, 9, 3, 1, 13, 12, 11, 14, 2, 6, 5, 10, 4, 0, 15, 8 },
            [_]u8{ 9, 0, 5, 7, 2, 4, 10, 15, 14, 1, 11, 12, 6, 8, 3, 13 },
            [_]u8{ 2, 12, 6, 10, 0, 11, 8, 3, 4, 13, 7, 5, 15, 14, 1, 9 },
            [_]u8{ 12, 5, 1, 15, 14, 13, 4, 10, 0, 7, 6, 3, 9, 2, 8, 11 },
            [_]u8{ 13, 11, 7, 14, 12, 1, 3, 9, 5, 0, 15, 4, 8, 6, 2, 10 },
            [_]u8{ 6, 15, 14, 9, 11, 3, 0, 8, 12, 2, 13, 7, 1, 4, 10, 5 },
            [_]u8{ 10, 2, 8, 4, 7, 6, 1, 5, 15, 11, 9, 14, 3, 12, 13, 0 },
            [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 },
            [_]u8{ 14, 10, 4, 8, 9, 15, 13, 6, 1, 12, 0, 2, 11, 7, 5, 3 },
        };

        h: [8]u64,
        t: u128,
        // Streaming cache
        buf: [128]u8,
        buf_len: u8,

        pub fn init(options: Options) Self {
            comptime debug.assert(8 <= out_bits and out_bits <= 512);

            var d: Self = undefined;
            mem.copy(u64, d.h[0..], iv[0..]);

            const key_len = if (options.key) |key| key.len else 0;
            // default parameters
            d.h[0] ^= 0x01010000 ^ (key_len << 8) ^ (options.expected_out_bits >> 3);
            d.t = 0;
            d.buf_len = 0;

            if (options.salt) |salt| {
                d.h[4] ^= mem.readIntLittle(u64, salt[0..8]);
                d.h[5] ^= mem.readIntLittle(u64, salt[8..16]);
            }
            if (options.context) |context| {
                d.h[6] ^= mem.readIntLittle(u64, context[0..8]);
                d.h[7] ^= mem.readIntLittle(u64, context[8..16]);
            }
            if (key_len > 0) {
                mem.set(u8, d.buf[key_len..], 0);
                d.update(options.key.?);
                d.buf_len = 128;
            }
            return d;
        }

        pub fn hash(b: []const u8, out: *[digest_length]u8, options: Options) void {
            var d = Self.init(options);
            d.update(b);
            d.final(out);
        }

        pub fn update(d: *Self, b: []const u8) void {
            var off: usize = 0;

            // Partial buffer exists from previous update. Copy into buffer then hash.
            if (d.buf_len != 0 and d.buf_len + b.len > 128) {
                off += 128 - d.buf_len;
                mem.copy(u8, d.buf[d.buf_len..], b[0..off]);
                d.t += 128;
                d.round(d.buf[0..], false);
                d.buf_len = 0;
            }

            // Full middle blocks.
            while (off + 128 < b.len) : (off += 128) {
                d.t += 128;
                d.round(b[off..][0..128], false);
            }

            // Copy any remainder for next pass.
            mem.copy(u8, d.buf[d.buf_len..], b[off..]);
            d.buf_len += @intCast(u8, b[off..].len);
        }

        pub fn final(d: *Self, out: *[digest_length]u8) void {
            mem.set(u8, d.buf[d.buf_len..], 0);
            d.t += d.buf_len;
            d.round(d.buf[0..], true);
            for (d.h) |*x| x.* = mem.nativeToLittle(u64, x.*);
            mem.copy(u8, out[0..], @ptrCast(*[digest_length]u8, &d.h));
        }

        fn round(d: *Self, b: *const [128]u8, last: bool) void {
            var m: [16]u64 = undefined;
            var v: [16]u64 = undefined;

            for (m) |*r, i| {
                r.* = mem.readIntLittle(u64, b[8 * i ..][0..8]);
            }

            var k: usize = 0;
            while (k < 8) : (k += 1) {
                v[k] = d.h[k];
                v[k + 8] = iv[k];
            }

            v[12] ^= @truncate(u64, d.t);
            v[13] ^= @intCast(u64, d.t >> 64);
            if (last) v[14] = ~v[14];

            const rounds = comptime [_]RoundParam{
                roundParam(0, 4, 8, 12, 0, 1),
                roundParam(1, 5, 9, 13, 2, 3),
                roundParam(2, 6, 10, 14, 4, 5),
                roundParam(3, 7, 11, 15, 6, 7),
                roundParam(0, 5, 10, 15, 8, 9),
                roundParam(1, 6, 11, 12, 10, 11),
                roundParam(2, 7, 8, 13, 12, 13),
                roundParam(3, 4, 9, 14, 14, 15),
            };

            comptime var j: usize = 0;
            inline while (j < 12) : (j += 1) {
                inline for (rounds) |r| {
                    v[r.a] = v[r.a] +% v[r.b] +% m[sigma[j][r.x]];
                    v[r.d] = math.rotr(u64, v[r.d] ^ v[r.a], @as(usize, 32));
                    v[r.c] = v[r.c] +% v[r.d];
                    v[r.b] = math.rotr(u64, v[r.b] ^ v[r.c], @as(usize, 24));
                    v[r.a] = v[r.a] +% v[r.b] +% m[sigma[j][r.y]];
                    v[r.d] = math.rotr(u64, v[r.d] ^ v[r.a], @as(usize, 16));
                    v[r.c] = v[r.c] +% v[r.d];
                    v[r.b] = math.rotr(u64, v[r.b] ^ v[r.c], @as(usize, 63));
                }
            }

            for (d.h) |*r, i| {
                r.* ^= v[i] ^ v[i + 8];
            }
        }
    };
}

test "blake2b160 single" {
    const h1 = "3345524abf6bbe1809449224b5972c41790b6cf2";
    try htest.assertEqualHash(Blake2b160, h1, "");

    const h2 = "384264f676f39536840523f284921cdc68b6846b";
    try htest.assertEqualHash(Blake2b160, h2, "abc");

    const h3 = "3c523ed102ab45a37d54f5610d5a983162fde84f";
    try htest.assertEqualHash(Blake2b160, h3, "The quick brown fox jumps over the lazy dog");

    const h4 = "43758f5de1740f651f1ae39de92260fe8bd5a11f";
    try htest.assertEqualHash(Blake2b160, h4, "a" ** 64 ++ "b" ** 64);
}

test "blake2b160 streaming" {
    var h = Blake2b160.init(.{});
    var out: [20]u8 = undefined;

    const h1 = "3345524abf6bbe1809449224b5972c41790b6cf2";

    h.final(out[0..]);
    try htest.assertEqual(h1, out[0..]);

    const h2 = "384264f676f39536840523f284921cdc68b6846b";

    h = Blake2b160.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    h = Blake2b160.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    const h3 = "43758f5de1740f651f1ae39de92260fe8bd5a11f";

    h = Blake2b160.init(.{});
    h.update("a" ** 64 ++ "b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    h = Blake2b160.init(.{});
    h.update("a" ** 64);
    h.update("b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    h = Blake2b160.init(.{});
    h.update("a" ** 64);
    h.update("b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    const h4 = "72328f8a8200663752fc302d372b5dd9b49dd8dc";

    h = Blake2b160.init(.{ .context = [_]u8{0x69} ** 16, .salt = [_]u8{0x42} ** 16 });
    h.update("a" ** 64);
    h.update("b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h4, out[0..]);

    h = Blake2b160.init(.{ .context = [_]u8{0x69} ** 16, .salt = [_]u8{0x42} ** 16 });
    h.update("a" ** 64);
    h.update("b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h4, out[0..]);
}

test "comptime blake2b160" {
    comptime {
        @setEvalBranchQuota(10000);
        var block = [_]u8{0} ** Blake2b160.block_length;
        var out: [Blake2b160.digest_length]u8 = undefined;

        const h1 = "8d26f158f564e3293b42f5e3d34263cb173aa9c9";

        try htest.assertEqualHash(Blake2b160, h1, block[0..]);

        var h = Blake2b160.init(.{});
        h.update(&block);
        h.final(out[0..]);

        try htest.assertEqual(h1, out[0..]);
    }
}

test "blake2b384 single" {
    const h1 = "b32811423377f52d7862286ee1a72ee540524380fda1724a6f25d7978c6fd3244a6caf0498812673c5e05ef583825100";
    try htest.assertEqualHash(Blake2b384, h1, "");

    const h2 = "6f56a82c8e7ef526dfe182eb5212f7db9df1317e57815dbda46083fc30f54ee6c66ba83be64b302d7cba6ce15bb556f4";
    try htest.assertEqualHash(Blake2b384, h2, "abc");

    const h3 = "b7c81b228b6bd912930e8f0b5387989691c1cee1e65aade4da3b86a3c9f678fc8018f6ed9e2906720c8d2a3aeda9c03d";
    try htest.assertEqualHash(Blake2b384, h3, "The quick brown fox jumps over the lazy dog");

    const h4 = "b7283f0172fecbbd7eca32ce10d8a6c06b453cb3cf675b33eb4246f0da2bb94a6c0bdd6eec0b5fd71ec4fd51be80bf4c";
    try htest.assertEqualHash(Blake2b384, h4, "a" ** 64 ++ "b" ** 64);
}

test "blake2b384 streaming" {
    var h = Blake2b384.init(.{});
    var out: [48]u8 = undefined;

    const h1 = "b32811423377f52d7862286ee1a72ee540524380fda1724a6f25d7978c6fd3244a6caf0498812673c5e05ef583825100";

    h.final(out[0..]);
    try htest.assertEqual(h1, out[0..]);

    const h2 = "6f56a82c8e7ef526dfe182eb5212f7db9df1317e57815dbda46083fc30f54ee6c66ba83be64b302d7cba6ce15bb556f4";

    h = Blake2b384.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    h = Blake2b384.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    const h3 = "b7283f0172fecbbd7eca32ce10d8a6c06b453cb3cf675b33eb4246f0da2bb94a6c0bdd6eec0b5fd71ec4fd51be80bf4c";

    h = Blake2b384.init(.{});
    h.update("a" ** 64 ++ "b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    h = Blake2b384.init(.{});
    h.update("a" ** 64);
    h.update("b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    h = Blake2b384.init(.{});
    h.update("a" ** 64);
    h.update("b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    const h4 = "934c48fcb197031c71f583d92f98703510805e72142e0b46f5752d1e971bc86c355d556035613ff7a4154b4de09dac5c";

    h = Blake2b384.init(.{ .context = [_]u8{0x69} ** 16, .salt = [_]u8{0x42} ** 16 });
    h.update("a" ** 64);
    h.update("b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h4, out[0..]);

    h = Blake2b384.init(.{ .context = [_]u8{0x69} ** 16, .salt = [_]u8{0x42} ** 16 });
    h.update("a" ** 64);
    h.update("b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h4, out[0..]);
}

test "comptime blake2b384" {
    comptime {
        @setEvalBranchQuota(10000);
        var block = [_]u8{0} ** Blake2b384.block_length;
        var out: [Blake2b384.digest_length]u8 = undefined;

        const h1 = "e8aa1931ea0422e4446fecdd25c16cf35c240b10cb4659dd5c776eddcaa4d922397a589404b46eb2e53d78132d05fd7d";

        try htest.assertEqualHash(Blake2b384, h1, block[0..]);

        var h = Blake2b384.init(.{});
        h.update(&block);
        h.final(out[0..]);

        try htest.assertEqual(h1, out[0..]);
    }
}

test "blake2b512 single" {
    const h1 = "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce";
    try htest.assertEqualHash(Blake2b512, h1, "");

    const h2 = "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923";
    try htest.assertEqualHash(Blake2b512, h2, "abc");

    const h3 = "a8add4bdddfd93e4877d2746e62817b116364a1fa7bc148d95090bc7333b3673f82401cf7aa2e4cb1ecd90296e3f14cb5413f8ed77be73045b13914cdcd6a918";
    try htest.assertEqualHash(Blake2b512, h3, "The quick brown fox jumps over the lazy dog");

    const h4 = "049980af04d6a2cf16b4b49793c3ed7e40732073788806f2c989ebe9547bda0541d63abe298ec8955d08af48ae731f2e8a0bd6d201655a5473b4aa79d211b920";
    try htest.assertEqualHash(Blake2b512, h4, "a" ** 64 ++ "b" ** 64);
}

test "blake2b512 streaming" {
    var h = Blake2b512.init(.{});
    var out: [64]u8 = undefined;

    const h1 = "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce";

    h.final(out[0..]);
    try htest.assertEqual(h1, out[0..]);

    const h2 = "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923";

    h = Blake2b512.init(.{});
    h.update("abc");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    h = Blake2b512.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    try htest.assertEqual(h2, out[0..]);

    const h3 = "049980af04d6a2cf16b4b49793c3ed7e40732073788806f2c989ebe9547bda0541d63abe298ec8955d08af48ae731f2e8a0bd6d201655a5473b4aa79d211b920";

    h = Blake2b512.init(.{});
    h.update("a" ** 64 ++ "b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);

    h = Blake2b512.init(.{});
    h.update("a" ** 64);
    h.update("b" ** 64);
    h.final(out[0..]);
    try htest.assertEqual(h3, out[0..]);
}

test "blake2b512 keyed" {
    var out: [64]u8 = undefined;

    const h1 = "8a978060ccaf582f388f37454363071ac9a67e3a704585fd879fb8a419a447e389c7c6de790faa20a7a7dccf197de736bc5b40b98a930b36df5bee7555750c4d";
    const key = "secret_key";

    Blake2b512.hash("a" ** 64 ++ "b" ** 64, &out, .{ .key = key });
    try htest.assertEqual(h1, out[0..]);

    var h = Blake2b512.init(.{ .key = key });
    h.update("a" ** 64 ++ "b" ** 64);
    h.final(out[0..]);

    try htest.assertEqual(h1, out[0..]);

    h = Blake2b512.init(.{ .key = key });
    h.update("a" ** 64);
    h.update("b" ** 64);
    h.final(out[0..]);

    try htest.assertEqual(h1, out[0..]);
}

test "comptime blake2b512" {
    comptime {
        @setEvalBranchQuota(10000);
        var block = [_]u8{0} ** Blake2b512.block_length;
        var out: [Blake2b512.digest_length]u8 = undefined;

        const h1 = "865939e120e6805438478841afb739ae4250cf372653078a065cdcfffca4caf798e6d462b65d658fc165782640eded70963449ae1500fb0f24981d7727e22c41";

        try htest.assertEqualHash(Blake2b512, h1, block[0..]);

        var h = Blake2b512.init(.{});
        h.update(&block);
        h.final(out[0..]);

        try htest.assertEqual(h1, out[0..]);
    }
}
