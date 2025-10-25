const std = @import("std");
const assert = std.debug.assert;
const crypto = std.crypto;
const debug = std.debug;
const Ghash = std.crypto.onetimeauth.Ghash;
const math = std.math;
const mem = std.mem;
const modes = crypto.core.modes;
const AuthenticationError = crypto.errors.AuthenticationError;

pub const Aes128Gcm = AesGcm(crypto.core.aes.Aes128, 12);
pub const Aes256Gcm = AesGcm(crypto.core.aes.Aes256, 12);

fn AesGcm(comptime Aes: anytype, comptime n: usize) type {
    debug.assert(Aes.block.block_length == 16);
    debug.assert(n > 0 and n <= 16);

    return struct {
        pub const tag_length = 16;
        pub const nonce_length = n;
        pub const key_length = Aes.key_bits / 8;

        const zeros = [_]u8{0} ** 16;

        /// `c`: The ciphertext buffer to write the encrypted data to.
        /// `tag`: The authentication tag buffer to write the computed tag to.
        /// `m`: The plaintext message to encrypt.
        /// `ad`: The associated data to authenticate.
        /// `npub`: The nonce to use for encryption.
        /// `key`: The encryption key.
        pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) void {
            debug.assert(c.len == m.len);
            debug.assert(m.len <= 16 * ((1 << 32) - 2));

            const aes = Aes.initEnc(key);
            var h: [16]u8 = undefined;
            aes.encrypt(&h, &zeros);

            var t: [16]u8 = undefined;
            var j: [16]u8 = undefined;
            if (nonce_length == 12) {
                j[0..nonce_length].* = npub;
                mem.writeInt(u32, j[nonce_length..][0..4], 1, .big);
            } else {
                var hash = Ghash.init(&h);
                hash.update(&npub);
                hash.pad();
                var block = zeros;
                mem.writeInt(u64, block[8..][0..8], nonce_length * 8, .big);
                hash.update(&block);
                hash.final(&j);
            }
            aes.encrypt(&t, &j);

            const block_count = (math.divCeil(usize, ad.len, Ghash.block_length) catch unreachable) + (math.divCeil(usize, c.len, Ghash.block_length) catch unreachable) + 1;
            var mac = Ghash.initForBlockCount(&h, block_count);
            mac.update(ad);
            mac.pad();

            if (nonce_length == 12) {
                mem.writeInt(u32, j[nonce_length..][0..4], 2, .big);
            } else {
                mem.writeInt(u128, &j, mem.readInt(u128, &j, .big) +% 1, .big);
            }
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
            if (nonce_length == 12) {
                j[0..nonce_length].* = npub;
                mem.writeInt(u32, j[nonce_length..][0..4], 1, .big);
            } else {
                var hash = Ghash.init(&h);
                hash.update(&npub);
                hash.pad();
                var block = zeros;
                mem.writeInt(u64, block[8..][0..8], nonce_length * 8, .big);
                hash.update(&block);
                hash.final(&j);
            }
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

            const verify = crypto.timing_safe.eql([tag_length]u8, computed_tag, tag);
            if (!verify) {
                crypto.secureZero(u8, &computed_tag);
                @memset(m, undefined);
                return error.AuthenticationFailed;
            }

            if (nonce_length == 12) {
                mem.writeInt(u32, j[nonce_length..][0..4], 2, .big);
            } else {
                mem.writeInt(u128, &j, mem.readInt(u128, &j, .big) +% 1, .big);
            }
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

test "Aes256Gcm - 16 byte nonce - Empty message and no associated data" {
    const BlockCipher = AesGcm(crypto.core.aes.Aes256, 16);
    const key: [BlockCipher.key_length]u8 = [_]u8{0x69} ** BlockCipher.key_length;
    const nonce: [BlockCipher.nonce_length]u8 = [_]u8{0x42} ** BlockCipher.nonce_length;
    const ad = "";
    const m = "";
    var c: [m.len]u8 = undefined;
    var tag: [BlockCipher.tag_length]u8 = undefined;

    BlockCipher.encrypt(&c, &tag, m, ad, nonce, key);
    try htest.assertEqual("0cba9113141050fd38faa8bd1b74ba1f", &tag);
}

test "Aes256Gcm - 16 byte nonce - Associated data only" {
    const BlockCipher = AesGcm(crypto.core.aes.Aes256, 16);
    const key: [BlockCipher.key_length]u8 = [_]u8{0x69} ** BlockCipher.key_length;
    const nonce: [BlockCipher.nonce_length]u8 = [_]u8{0x42} ** BlockCipher.nonce_length;
    const ad = "Test with associated data";
    const m = "";
    var c: [m.len]u8 = undefined;
    var tag: [BlockCipher.tag_length]u8 = undefined;

    BlockCipher.encrypt(&c, &tag, m, ad, nonce, key);
    try htest.assertEqual("41fbb66777a0465e6901ced495b829c1", &tag);
}

test "Aes256Gcm - 16 byte nonce - Message only" {
    const BlockCipher = AesGcm(crypto.core.aes.Aes256, 16);
    const key: [BlockCipher.key_length]u8 = [_]u8{0x69} ** BlockCipher.key_length;
    const nonce: [BlockCipher.nonce_length]u8 = [_]u8{0x42} ** BlockCipher.nonce_length;
    const m = "Test with message only";
    const ad = "";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [BlockCipher.tag_length]u8 = undefined;

    BlockCipher.encrypt(&c, &tag, m, ad, nonce, key);
    try BlockCipher.decrypt(&m2, &c, tag, ad, nonce, key);
    try testing.expectEqualSlices(u8, m[0..], m2[0..]);

    try htest.assertEqual("68ace2c30b073499f8f00509c1509e1ca2758f5901f8", &c);
    try htest.assertEqual("3ac733739b7c1670ad313259508bfc5c", &tag);
}

test "Aes256Gcm - 16 byte nonce - Message and associated data" {
    const BlockCipher = AesGcm(crypto.core.aes.Aes256, 16);
    const key: [BlockCipher.key_length]u8 = [_]u8{0x69} ** BlockCipher.key_length;
    const nonce: [BlockCipher.nonce_length]u8 = [_]u8{0x42} ** BlockCipher.nonce_length;
    const m = "Test with message";
    const ad = "Test with associated data";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [BlockCipher.tag_length]u8 = undefined;

    BlockCipher.encrypt(&c, &tag, m, ad, nonce, key);
    try BlockCipher.decrypt(&m2, &c, tag, ad, nonce, key);
    try testing.expectEqualSlices(u8, m[0..], m2[0..]);

    try htest.assertEqual("68ace2c30b073499f8f00509c1509e1ca2", &c);
    try htest.assertEqual("29ff8976e03000f97326d0813f8fb0f5", &tag);
}
