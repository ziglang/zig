const std = @import("../std.zig");
const crypto = std.crypto;
const debug = std.debug;
const mem = std.mem;

pub const HmacMd5 = Hmac(crypto.hash.Md5);
pub const HmacSha1 = Hmac(crypto.hash.Sha1);

pub const sha2 = struct {
    pub const HmacSha224 = Hmac(crypto.hash.sha2.Sha224);
    pub const HmacSha256 = Hmac(crypto.hash.sha2.Sha256);
    pub const HmacSha384 = Hmac(crypto.hash.sha2.Sha384);
    pub const HmacSha512 = Hmac(crypto.hash.sha2.Sha512);
};

pub fn Hmac(comptime Hash: type) type {
    return struct {
        const Self = @This();
        pub const mac_length = Hash.digest_length;
        pub const key_length_min = 0;
        pub const key_length = mac_length; // recommended key length

        o_key_pad: [Hash.block_length]u8,
        hash: Hash,

        // HMAC(k, m) = H(o_key_pad || H(i_key_pad || msg)) where || is concatenation
        pub fn create(out: *[mac_length]u8, msg: []const u8, key: []const u8) void {
            var ctx = Self.init(key);
            ctx.update(msg);
            ctx.final(out);
        }

        pub fn init(key: []const u8) Self {
            var ctx: Self = undefined;
            var scratch: [Hash.block_length]u8 = undefined;
            var i_key_pad: [Hash.block_length]u8 = undefined;

            // Normalize key length to block size of hash
            if (key.len > Hash.block_length) {
                Hash.hash(key, scratch[0..mac_length], .{});
                @memset(scratch[mac_length..Hash.block_length], 0);
            } else if (key.len < Hash.block_length) {
                @memcpy(scratch[0..key.len], key);
                @memset(scratch[key.len..Hash.block_length], 0);
            } else {
                @memcpy(&scratch, key);
            }

            for (&ctx.o_key_pad, 0..) |*b, i| {
                b.* = scratch[i] ^ 0x5c;
            }

            for (&i_key_pad, 0..) |*b, i| {
                b.* = scratch[i] ^ 0x36;
            }

            ctx.hash = Hash.init(.{});
            ctx.hash.update(&i_key_pad);
            return ctx;
        }

        pub fn update(ctx: *Self, msg: []const u8) void {
            ctx.hash.update(msg);
        }

        pub fn final(ctx: *Self, out: *[mac_length]u8) void {
            var scratch: [mac_length]u8 = undefined;
            ctx.hash.final(&scratch);
            var ohash = Hash.init(.{});
            ohash.update(&ctx.o_key_pad);
            ohash.update(&scratch);
            ohash.final(out);
        }
    };
}

const htest = @import("test.zig");

test "hmac md5" {
    var out: [HmacMd5.mac_length]u8 = undefined;
    HmacMd5.create(out[0..], "", "");
    try htest.assertEqual("74e6f7298a9c2d168935f58c001bad88", out[0..]);

    HmacMd5.create(out[0..], "The quick brown fox jumps over the lazy dog", "key");
    try htest.assertEqual("80070713463e7749b90c2dc24911e275", out[0..]);
}

test "hmac sha1" {
    var out: [HmacSha1.mac_length]u8 = undefined;
    HmacSha1.create(out[0..], "", "");
    try htest.assertEqual("fbdb1d1b18aa6c08324b7d64b71fb76370690e1d", out[0..]);

    HmacSha1.create(out[0..], "The quick brown fox jumps over the lazy dog", "key");
    try htest.assertEqual("de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9", out[0..]);
}

test "hmac sha256" {
    var out: [sha2.HmacSha256.mac_length]u8 = undefined;
    sha2.HmacSha256.create(out[0..], "", "");
    try htest.assertEqual("b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad", out[0..]);

    sha2.HmacSha256.create(out[0..], "The quick brown fox jumps over the lazy dog", "key");
    try htest.assertEqual("f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8", out[0..]);
}
