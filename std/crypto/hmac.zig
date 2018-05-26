const std = @import("../index.zig");
const crypto = std.crypto;
const debug = std.debug;
const mem = std.mem;

pub const HmacMd5 = Hmac(crypto.Md5);
pub const HmacSha1 = Hmac(crypto.Sha1);
pub const HmacSha256 = Hmac(crypto.Sha256);

pub fn Hmac(comptime H: type) type {
    return struct {
        const digest_size = H.digest_size;

        pub fn hash(output: []u8, key: []const u8, message: []const u8) void {
            debug.assert(output.len >= H.digest_size);
            debug.assert(H.digest_size <= H.block_size); // HMAC makes this assumption
            var scratch: [H.block_size]u8 = undefined;

            // Normalize key length to block size of hash
            if (key.len > H.block_size) {
                H.hash(key, scratch[0..H.digest_size]);
                mem.set(u8, scratch[H.digest_size..H.block_size], 0);
            } else if (key.len < H.block_size) {
                mem.copy(u8, scratch[0..key.len], key);
                mem.set(u8, scratch[key.len..H.block_size], 0);
            } else {
                mem.copy(u8, scratch[0..], key);
            }

            var o_key_pad: [H.block_size]u8 = undefined;
            for (o_key_pad) |*b, i| {
                b.* = scratch[i] ^ 0x5c;
            }

            var i_key_pad: [H.block_size]u8 = undefined;
            for (i_key_pad) |*b, i| {
                b.* = scratch[i] ^ 0x36;
            }

            // HMAC(k, m) = H(o_key_pad | H(i_key_pad | message)) where | is concatenation
            var hmac = H.init();
            hmac.update(i_key_pad[0..]);
            hmac.update(message);
            hmac.final(scratch[0..H.digest_size]);

            hmac.reset();
            hmac.update(o_key_pad[0..]);
            hmac.update(scratch[0..H.digest_size]);
            hmac.final(output[0..H.digest_size]);
        }
    };
}

const htest = @import("test.zig");

test "hmac md5" {
    var out: [crypto.Md5.digest_size]u8 = undefined;
    HmacMd5.hash(out[0..], "", "");
    htest.assertEqual("74e6f7298a9c2d168935f58c001bad88", out[0..]);

    HmacMd5.hash(out[0..], "key", "The quick brown fox jumps over the lazy dog");
    htest.assertEqual("80070713463e7749b90c2dc24911e275", out[0..]);
}

test "hmac sha1" {
    var out: [crypto.Sha1.digest_size]u8 = undefined;
    HmacSha1.hash(out[0..], "", "");
    htest.assertEqual("fbdb1d1b18aa6c08324b7d64b71fb76370690e1d", out[0..]);

    HmacSha1.hash(out[0..], "key", "The quick brown fox jumps over the lazy dog");
    htest.assertEqual("de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9", out[0..]);
}

test "hmac sha256" {
    var out: [crypto.Sha256.digest_size]u8 = undefined;
    HmacSha256.hash(out[0..], "", "");
    htest.assertEqual("b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad", out[0..]);

    HmacSha256.hash(out[0..], "key", "The quick brown fox jumps over the lazy dog");
    htest.assertEqual("f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8", out[0..]);
}
