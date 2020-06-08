const mem = @import("../mem.zig");
const math = @import("../math.zig");
const endian = @import("../endian.zig");
const debug = @import("../debug.zig");
const builtin = @import("builtin");
const htest = @import("test.zig");

const RoundParam = struct {
    a: usize,
    b: usize,
    c: usize,
    d: usize,
    x: usize,
    y: usize,
};

fn Rp(a: usize, b: usize, c: usize, d: usize, x: usize, y: usize) RoundParam {
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

pub const Blake2s224 = Blake2s(224);
pub const Blake2s256 = Blake2s(256);

fn Blake2s(comptime out_len: usize) type {
    return struct {
        const Self = @This();
        pub const block_length = 64;
        pub const digest_length = out_len / 8;

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

        pub fn init() Self {
            debug.assert(8 <= out_len and out_len <= 512);

            var s: Self = undefined;
            s.reset();
            return s;
        }

        pub fn reset(d: *Self) void {
            mem.copy(u32, d.h[0..], iv[0..]);

            // No key plus default parameters
            d.h[0] ^= 0x01010000 ^ @intCast(u32, out_len >> 3);
            d.t = 0;
            d.buf_len = 0;
        }

        pub fn hash(b: []const u8, out: []u8) void {
            var d = Self.init();
            d.update(b);
            d.final(out);
        }

        pub fn update(d: *Self, b: []const u8) void {
            var off: usize = 0;

            // Partial buffer exists from previous update. Copy into buffer then hash.
            if (d.buf_len != 0 and d.buf_len + b.len >= 64) {
                off += 64 - d.buf_len;
                mem.copy(u8, d.buf[d.buf_len..], b[0..off]);
                d.t += 64;
                d.round(d.buf[0..], false);
                d.buf_len = 0;
            }

            // Full middle blocks.
            while (off + 64 <= b.len) : (off += 64) {
                d.t += 64;
                d.round(b[off .. off + 64], false);
            }

            // Copy any remainder for next pass.
            mem.copy(u8, d.buf[d.buf_len..], b[off..]);
            d.buf_len += @intCast(u8, b[off..].len);
        }

        pub fn final(d: *Self, out: []u8) void {
            debug.assert(out.len >= out_len / 8);

            mem.set(u8, d.buf[d.buf_len..], 0);
            d.t += d.buf_len;
            d.round(d.buf[0..], true);

            const rr = d.h[0 .. out_len / 32];

            for (rr) |s, j| {
                mem.writeIntLittle(u32, out[4 * j ..][0..4], s);
            }
        }

        fn round(d: *Self, b: []const u8, last: bool) void {
            debug.assert(b.len == 64);

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
                Rp(0, 4, 8, 12, 0, 1),
                Rp(1, 5, 9, 13, 2, 3),
                Rp(2, 6, 10, 14, 4, 5),
                Rp(3, 7, 11, 15, 6, 7),
                Rp(0, 5, 10, 15, 8, 9),
                Rp(1, 6, 11, 12, 10, 11),
                Rp(2, 7, 8, 13, 12, 13),
                Rp(3, 4, 9, 14, 14, 15),
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
    };
}

test "blake2s224 single" {
    const h1 = "1fa1291e65248b37b3433475b2a0dd63d54a11ecc4e3e034e7bc1ef4";
    htest.assertEqualHash(Blake2s224, h1, "");

    const h2 = "0b033fc226df7abde29f67a05d3dc62cf271ef3dfea4d387407fbd55";
    htest.assertEqualHash(Blake2s224, h2, "abc");

    const h3 = "e4e5cb6c7cae41982b397bf7b7d2d9d1949823ae78435326e8db4912";
    htest.assertEqualHash(Blake2s224, h3, "The quick brown fox jumps over the lazy dog");
}

test "blake2s224 streaming" {
    var h = Blake2s224.init();
    var out: [28]u8 = undefined;

    const h1 = "1fa1291e65248b37b3433475b2a0dd63d54a11ecc4e3e034e7bc1ef4";

    h.final(out[0..]);
    htest.assertEqual(h1, out[0..]);

    const h2 = "0b033fc226df7abde29f67a05d3dc62cf271ef3dfea4d387407fbd55";

    h.reset();
    h.update("abc");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);

    h.reset();
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);
}

test "blake2s256 single" {
    const h1 = "69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9";
    htest.assertEqualHash(Blake2s256, h1, "");

    const h2 = "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982";
    htest.assertEqualHash(Blake2s256, h2, "abc");

    const h3 = "606beeec743ccbeff6cbcdf5d5302aa855c256c29b88c8ed331ea1a6bf3c8812";
    htest.assertEqualHash(Blake2s256, h3, "The quick brown fox jumps over the lazy dog");
}

test "blake2s256 streaming" {
    var h = Blake2s256.init();
    var out: [32]u8 = undefined;

    const h1 = "69217a3079908094e11121d042354a7c1f55b6482ca1a51e1b250dfd1ed0eef9";

    h.final(out[0..]);
    htest.assertEqual(h1, out[0..]);

    const h2 = "508c5e8c327c14e2e1a72ba34eeb452f37458b209ed63a294d999b4c86675982";

    h.reset();
    h.update("abc");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);

    h.reset();
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);
}

test "blake2s256 aligned final" {
    var block = [_]u8{0} ** Blake2s256.block_length;
    var out: [Blake2s256.digest_length]u8 = undefined;

    var h = Blake2s256.init();
    h.update(&block);
    h.final(out[0..]);
}

/////////////////////
// Blake2b

pub const Blake2b384 = Blake2b(384);
pub const Blake2b512 = Blake2b(512);

fn Blake2b(comptime out_len: usize) type {
    return struct {
        const Self = @This();
        pub const block_length = 128;
        pub const digest_length = out_len / 8;

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

        pub fn init() Self {
            debug.assert(8 <= out_len and out_len <= 512);

            var s: Self = undefined;
            s.reset();
            return s;
        }

        pub fn reset(d: *Self) void {
            mem.copy(u64, d.h[0..], iv[0..]);

            // No key plus default parameters
            d.h[0] ^= 0x01010000 ^ (out_len >> 3);
            d.t = 0;
            d.buf_len = 0;
        }

        pub fn hash(b: []const u8, out: []u8) void {
            var d = Self.init();
            d.update(b);
            d.final(out);
        }

        pub fn update(d: *Self, b: []const u8) void {
            var off: usize = 0;

            // Partial buffer exists from previous update. Copy into buffer then hash.
            if (d.buf_len != 0 and d.buf_len + b.len >= 128) {
                off += 128 - d.buf_len;
                mem.copy(u8, d.buf[d.buf_len..], b[0..off]);
                d.t += 128;
                d.round(d.buf[0..], false);
                d.buf_len = 0;
            }

            // Full middle blocks.
            while (off + 128 <= b.len) : (off += 128) {
                d.t += 128;
                d.round(b[off .. off + 128], false);
            }

            // Copy any remainder for next pass.
            mem.copy(u8, d.buf[d.buf_len..], b[off..]);
            d.buf_len += @intCast(u8, b[off..].len);
        }

        pub fn final(d: *Self, out: []u8) void {
            mem.set(u8, d.buf[d.buf_len..], 0);
            d.t += d.buf_len;
            d.round(d.buf[0..], true);

            const rr = d.h[0 .. out_len / 64];

            for (rr) |s, j| {
                mem.writeIntLittle(u64, out[8 * j ..][0..8], s);
            }
        }

        fn round(d: *Self, b: []const u8, last: bool) void {
            debug.assert(b.len == 128);

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
                Rp(0, 4, 8, 12, 0, 1),
                Rp(1, 5, 9, 13, 2, 3),
                Rp(2, 6, 10, 14, 4, 5),
                Rp(3, 7, 11, 15, 6, 7),
                Rp(0, 5, 10, 15, 8, 9),
                Rp(1, 6, 11, 12, 10, 11),
                Rp(2, 7, 8, 13, 12, 13),
                Rp(3, 4, 9, 14, 14, 15),
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

test "blake2b384 single" {
    const h1 = "b32811423377f52d7862286ee1a72ee540524380fda1724a6f25d7978c6fd3244a6caf0498812673c5e05ef583825100";
    htest.assertEqualHash(Blake2b384, h1, "");

    const h2 = "6f56a82c8e7ef526dfe182eb5212f7db9df1317e57815dbda46083fc30f54ee6c66ba83be64b302d7cba6ce15bb556f4";
    htest.assertEqualHash(Blake2b384, h2, "abc");

    const h3 = "b7c81b228b6bd912930e8f0b5387989691c1cee1e65aade4da3b86a3c9f678fc8018f6ed9e2906720c8d2a3aeda9c03d";
    htest.assertEqualHash(Blake2b384, h3, "The quick brown fox jumps over the lazy dog");
}

test "blake2b384 streaming" {
    var h = Blake2b384.init();
    var out: [48]u8 = undefined;

    const h1 = "b32811423377f52d7862286ee1a72ee540524380fda1724a6f25d7978c6fd3244a6caf0498812673c5e05ef583825100";

    h.final(out[0..]);
    htest.assertEqual(h1, out[0..]);

    const h2 = "6f56a82c8e7ef526dfe182eb5212f7db9df1317e57815dbda46083fc30f54ee6c66ba83be64b302d7cba6ce15bb556f4";

    h.reset();
    h.update("abc");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);

    h.reset();
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);
}

test "blake2b512 single" {
    const h1 = "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce";
    htest.assertEqualHash(Blake2b512, h1, "");

    const h2 = "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923";
    htest.assertEqualHash(Blake2b512, h2, "abc");

    const h3 = "a8add4bdddfd93e4877d2746e62817b116364a1fa7bc148d95090bc7333b3673f82401cf7aa2e4cb1ecd90296e3f14cb5413f8ed77be73045b13914cdcd6a918";
    htest.assertEqualHash(Blake2b512, h3, "The quick brown fox jumps over the lazy dog");
}

test "blake2b512 streaming" {
    var h = Blake2b512.init();
    var out: [64]u8 = undefined;

    const h1 = "786a02f742015903c6c6fd852552d272912f4740e15847618a86e217f71f5419d25e1031afee585313896444934eb04b903a685b1448b755d56f701afe9be2ce";

    h.final(out[0..]);
    htest.assertEqual(h1, out[0..]);

    const h2 = "ba80a53f981c4d0d6a2797b69f12f6e94c212f14685ac4b74b12bb6fdbffa2d17d87c5392aab792dc252d5de4533cc9518d38aa8dbf1925ab92386edd4009923";

    h.reset();
    h.update("abc");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);

    h.reset();
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);
}

test "blake2b512 aligned final" {
    var block = [_]u8{0} ** Blake2b512.block_length;
    var out: [Blake2b512.digest_length]u8 = undefined;

    var h = Blake2b512.init();
    h.update(&block);
    h.final(out[0..]);
}
