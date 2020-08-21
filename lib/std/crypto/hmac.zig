// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
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

pub const blake2 = struct {
    pub const HmacBlake2s256 = Hmac(crypto.hash.blake2.Blake2s256);
};

pub fn Hmac(comptime Hash: type) type {
    return struct {
        const Self = @This();
        pub const mac_length = Hash.digest_length;
        pub const minimum_key_length = 0;

        o_key_pad: [Hash.block_length]u8,
        i_key_pad: [Hash.block_length]u8,
        scratch: [Hash.block_length]u8,
        hash: Hash,

        // HMAC(k, m) = H(o_key_pad | H(i_key_pad | msg)) where | is concatenation
        pub fn create(out: []u8, msg: []const u8, key: []const u8) void {
            var ctx = Self.init(key);
            ctx.update(msg);
            ctx.final(out[0..]);
        }

        pub fn init(key: []const u8) Self {
            var ctx: Self = undefined;

            // Normalize key length to block size of hash
            if (key.len > Hash.block_length) {
                Hash.hash(key, ctx.scratch[0..mac_length], .{});
                mem.set(u8, ctx.scratch[mac_length..Hash.block_length], 0);
            } else if (key.len < Hash.block_length) {
                mem.copy(u8, ctx.scratch[0..key.len], key);
                mem.set(u8, ctx.scratch[key.len..Hash.block_length], 0);
            } else {
                mem.copy(u8, ctx.scratch[0..], key);
            }

            for (ctx.o_key_pad) |*b, i| {
                b.* = ctx.scratch[i] ^ 0x5c;
            }

            for (ctx.i_key_pad) |*b, i| {
                b.* = ctx.scratch[i] ^ 0x36;
            }

            ctx.hash = Hash.init(.{});
            ctx.hash.update(ctx.i_key_pad[0..]);
            return ctx;
        }

        pub fn update(ctx: *Self, msg: []const u8) void {
            ctx.hash.update(msg);
        }

        pub fn final(ctx: *Self, out: []u8) void {
            debug.assert(Hash.block_length >= out.len and out.len >= mac_length);

            ctx.hash.final(ctx.scratch[0..mac_length]);
            var ohash = Hash.init(.{});
            ohash.update(ctx.o_key_pad[0..]);
            ohash.update(ctx.scratch[0..mac_length]);
            ohash.final(out[0..mac_length]);
        }
    };
}

const htest = @import("test.zig");

test "hmac md5" {
    var out: [HmacMd5.mac_length]u8 = undefined;
    HmacMd5.create(out[0..], "", "");
    htest.assertEqual("74e6f7298a9c2d168935f58c001bad88", out[0..]);

    HmacMd5.create(out[0..], "The quick brown fox jumps over the lazy dog", "key");
    htest.assertEqual("80070713463e7749b90c2dc24911e275", out[0..]);
}

test "hmac sha1" {
    var out: [HmacSha1.mac_length]u8 = undefined;
    HmacSha1.create(out[0..], "", "");
    htest.assertEqual("fbdb1d1b18aa6c08324b7d64b71fb76370690e1d", out[0..]);

    HmacSha1.create(out[0..], "The quick brown fox jumps over the lazy dog", "key");
    htest.assertEqual("de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9", out[0..]);
}

test "hmac sha256" {
    var out: [sha2.HmacSha256.mac_length]u8 = undefined;
    sha2.HmacSha256.create(out[0..], "", "");
    htest.assertEqual("b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad", out[0..]);

    sha2.HmacSha256.create(out[0..], "The quick brown fox jumps over the lazy dog", "key");
    htest.assertEqual("f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8", out[0..]);
}
