const std = @import("std");
const assert = std.debug.assert;
const crypto = std.crypto;
const debug = std.debug;
const Ghash = std.crypto.onetimeauth.Ghash;
const math = std.math;
const mem = std.mem;
const modes = crypto.core.modes;
const AuthenticationError = crypto.errors.AuthenticationError;

pub const Aes128Gcm = AesGcm(crypto.core.aes.Aes128);
pub const Aes256Gcm = AesGcm(crypto.core.aes.Aes256);

fn AesGcm(comptime Aes: anytype) type {
    debug.assert(Aes.block.block_length == 16);

    return struct {
        pub const tag_length = 16;
        pub const nonce_length = 12;
        pub const key_length = Aes.key_bits / 8;

        const zeros = [_]u8{0} ** 16;

        pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) void {
            debug.assert(c.len == m.len);
            debug.assert(m.len <= 16 * ((1 << 32) - 2));

            const aes = Aes.initEnc(key);
            var h: [16]u8 = undefined;
            aes.encrypt(&h, &zeros);

            var t: [16]u8 = undefined;
            var j: [16]u8 = undefined;
            j[0..nonce_length].* = npub;
            mem.writeInt(u32, j[nonce_length..][0..4], 1, .big);
            aes.encrypt(&t, &j);

            const block_count = (math.divCeil(usize, ad.len, Ghash.block_length) catch unreachable) + (math.divCeil(usize, c.len, Ghash.block_length) catch unreachable) + 1;
            var mac = Ghash.initForBlockCount(&h, block_count);
            mac.update(ad);
            mac.pad();

            mem.writeInt(u32, j[nonce_length..][0..4], 2, .big);
            modes.ctr(@TypeOf(aes), aes, c, m, j, .big);
            mac.update(c[0..m.len][0..]);
            mac.pad();

            var final_block = h;
            mem.writeInt(u64, final_block[0..8], @as(u64, ad.len) * 8, .big);
            mem.writeInt(u64, final_block[8..16], @as(u64, m.len) * 8, .big);
            mac.update(&final_block);
            mac.final(tag);
            for (t, 0..) |x, i| {
                tag[i] ^= x;
            }
        }

        /// `m`: Message
        /// `c`: Ciphertext
        /// `tag`: Authentication tag
        /// `ad`: Associated data
        /// `npub`: Public nonce
        /// `k`: Private key
        /// Asserts `c.len == m.len`.
        ///
        /// Contents of `m` are undefined if an error is returned.
        pub fn decrypt(m: []u8, c: []const u8, tag: [tag_length]u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) AuthenticationError!void {
            assert(c.len == m.len);

            const aes = Aes.initEnc(key);
            var h: [16]u8 = undefined;
            aes.encrypt(&h, &zeros);

            var t: [16]u8 = undefined;
            var j: [16]u8 = undefined;
            j[0..nonce_length].* = npub;
            mem.writeInt(u32, j[nonce_length..][0..4], 1, .big);
            aes.encrypt(&t, &j);

            const block_count = (math.divCeil(usize, ad.len, Ghash.block_length) catch unreachable) + (math.divCeil(usize, c.len, Ghash.block_length) catch unreachable) + 1;
            var mac = Ghash.initForBlockCount(&h, block_count);
            mac.update(ad);
            mac.pad();

            mac.update(c);
            mac.pad();

            var final_block = h;
            mem.writeInt(u64, final_block[0..8], @as(u64, ad.len) * 8, .big);
            mem.writeInt(u64, final_block[8..16], @as(u64, m.len) * 8, .big);
            mac.update(&final_block);
            var computed_tag: [Ghash.mac_length]u8 = undefined;
            mac.final(&computed_tag);
            for (t, 0..) |x, i| {
                computed_tag[i] ^= x;
            }

            const verify = crypto.utils.timingSafeEql([tag_length]u8, computed_tag, tag);
            if (!verify) {
                crypto.utils.secureZero(u8, &computed_tag);
                @memset(m, undefined);
                return error.AuthenticationFailed;
            }

            mem.writeInt(u32, j[nonce_length..][0..4], 2, .big);
            modes.ctr(@TypeOf(aes), aes, m, c, j, .big);
        }
    };
}

const htest = @import("test.zig");
const testing = std.testing;

test "Aes256Gcm - Empty message and no associated data" {
    const key: [Aes256Gcm.key_length]u8 = [_]u8{0x69} ** Aes256Gcm.key_length;
    const nonce: [Aes256Gcm.nonce_length]u8 = [_]u8{0x42} ** Aes256Gcm.nonce_length;
    const ad = "";
    const m = "";
    var c: [m.len]u8 = undefined;
    var tag: [Aes256Gcm.tag_length]u8 = undefined;

    Aes256Gcm.encrypt(&c, &tag, m, ad, nonce, key);
    try htest.assertEqual("6b6ff610a16fa4cd59f1fb7903154e92", &tag);
}

test "Aes256Gcm - Associated data only" {
    const key: [Aes256Gcm.key_length]u8 = [_]u8{0x69} ** Aes256Gcm.key_length;
    const nonce: [Aes256Gcm.nonce_length]u8 = [_]u8{0x42} ** Aes256Gcm.nonce_length;
    const m = "";
    const ad = "Test with associated data";
    var c: [m.len]u8 = undefined;
    var tag: [Aes256Gcm.tag_length]u8 = undefined;

    Aes256Gcm.encrypt(&c, &tag, m, ad, nonce, key);
    try htest.assertEqual("262ed164c2dfb26e080a9d108dd9dd4c", &tag);
}

test "Aes256Gcm - Message only" {
    const key: [Aes256Gcm.key_length]u8 = [_]u8{0x69} ** Aes256Gcm.key_length;
    const nonce: [Aes256Gcm.nonce_length]u8 = [_]u8{0x42} ** Aes256Gcm.nonce_length;
    const m = "Test with message only";
    const ad = "";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aes256Gcm.tag_length]u8 = undefined;

    Aes256Gcm.encrypt(&c, &tag, m, ad, nonce, key);
    try Aes256Gcm.decrypt(&m2, &c, tag, ad, nonce, key);
    try testing.expectEqualSlices(u8, m[0..], m2[0..]);

    try htest.assertEqual("5ca1642d90009fea33d01f78cf6eefaf01d539472f7c", &c);
    try htest.assertEqual("07cd7fc9103e2f9e9bf2dfaa319caff4", &tag);
}

test "Aes256Gcm - Message and associated data" {
    const key: [Aes256Gcm.key_length]u8 = [_]u8{0x69} ** Aes256Gcm.key_length;
    const nonce: [Aes256Gcm.nonce_length]u8 = [_]u8{0x42} ** Aes256Gcm.nonce_length;
    const m = "Test with message";
    const ad = "Test with associated data";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aes256Gcm.tag_length]u8 = undefined;

    Aes256Gcm.encrypt(&c, &tag, m, ad, nonce, key);
    try Aes256Gcm.decrypt(&m2, &c, tag, ad, nonce, key);
    try testing.expectEqualSlices(u8, m[0..], m2[0..]);

    try htest.assertEqual("5ca1642d90009fea33d01f78cf6eefaf01", &c);
    try htest.assertEqual("64accec679d444e2373bd9f6796c0d2c", &tag);
}
