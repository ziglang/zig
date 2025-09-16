const std = @import("std");
const assert = std.debug.assert;
const crypto = std.crypto;
const debug = std.debug;
const mem = std.mem;
const math = std.math;
const modes = @import("modes.zig");
const Polyval = @import("ghash_polyval.zig").Polyval;
const AuthenticationError = crypto.errors.AuthenticationError;

pub const Aes128GcmSiv = AesGcmSiv(crypto.core.aes.Aes128);
pub const Aes256GcmSiv = AesGcmSiv(crypto.core.aes.Aes256);

/// AES-GCM-SIV: Authenticated encryption that remains secure even if you accidentally reuse a nonce.
///
/// What it does: Encrypts data and protects it from tampering. You can also attach
/// unencrypted metadata (like headers) that will be authenticated but not encrypted.
///
/// When to use AES-GCM-SIV:
/// - When you can't guarantee unique nonces (though you should still try to use unique nonces)
///
/// When to use regular AES-GCM instead:
/// - When you can guarantee unique nonces (e.g., using a counter)
/// - When you need slightly better performance
///
/// Security: If you accidentally reuse a nonce with the same key, AES-GCM-SIV only
/// reveals whether two messages are identical. Regular AES-GCM would be catastrophically
/// broken in this scenario, potentially revealing the authentication key.
///
/// Performance: Slightly slower than AES-GCM due to the additional key derivation step.
///
/// Defined in RFC 8452.
fn AesGcmSiv(comptime Aes: anytype) type {
    debug.assert(Aes.block.block_length == 16);

    return struct {
        pub const tag_length = 16;
        pub const nonce_length = 12;
        pub const key_length = Aes.key_bits / 8;

        const zeros: [16]u8 = @splat(0);

        /// Derives the authentication and message encryption keys from the master key and nonce.
        /// This implements the key derivation as specified in RFC 8452 Section 4.
        /// Generates a 128-bit authentication key for POLYVAL and a message encryption key
        /// (128 or 256 bits depending on the AES variant).
        fn deriveKeys(message_key: *[key_length]u8, auth_key: *[16]u8, key: [key_length]u8, nonce: [nonce_length]u8) void {
            const aes = Aes.initEnc(key);

            // Derive authentication and message keys per RFC 8452 Section 4
            // Each encryption produces 16 bytes, but we only use first 8 bytes of each block
            var key_block: [16]u8 = undefined;
            var cipher_out: [16]u8 = undefined;

            // Generate authentication key (128 bits = 2 * 8 bytes)
            // Block 0: counter = 0 with nonce
            mem.writeInt(u32, key_block[0..4], 0, .little);
            key_block[4..16].* = nonce;
            aes.encrypt(&cipher_out, &key_block);
            @memcpy(auth_key[0..8], cipher_out[0..8]);

            // Block 1: counter = 1 with nonce
            mem.writeInt(u32, key_block[0..4], 1, .little);
            aes.encrypt(&cipher_out, &key_block);
            @memcpy(auth_key[8..16], cipher_out[0..8]);

            // Generate message encryption key
            if (key_length == 16) {
                // AES-128-GCM-SIV: 128-bit message key = 2 * 8 bytes
                // Block 2: counter = 2 with nonce
                mem.writeInt(u32, key_block[0..4], 2, .little);
                aes.encrypt(&cipher_out, &key_block);
                @memcpy(message_key[0..8], cipher_out[0..8]);

                // Block 3: counter = 3 with nonce
                mem.writeInt(u32, key_block[0..4], 3, .little);
                aes.encrypt(&cipher_out, &key_block);
                @memcpy(message_key[8..16], cipher_out[0..8]);
            } else {
                // AES-256-GCM-SIV: 256-bit message key = 4 * 8 bytes
                // Block 2: counter = 2 with nonce
                mem.writeInt(u32, key_block[0..4], 2, .little);
                aes.encrypt(&cipher_out, &key_block);
                @memcpy(message_key[0..8], cipher_out[0..8]);

                // Block 3: counter = 3 with nonce
                mem.writeInt(u32, key_block[0..4], 3, .little);
                aes.encrypt(&cipher_out, &key_block);
                @memcpy(message_key[8..16], cipher_out[0..8]);

                // Block 4: counter = 4 with nonce
                mem.writeInt(u32, key_block[0..4], 4, .little);
                aes.encrypt(&cipher_out, &key_block);
                @memcpy(message_key[16..24], cipher_out[0..8]);

                // Block 5: counter = 5 with nonce
                mem.writeInt(u32, key_block[0..4], 5, .little);
                aes.encrypt(&cipher_out, &key_block);
                @memcpy(message_key[24..32], cipher_out[0..8]);
            }
        }

        /// Encrypts and authenticates a message using AES-GCM-SIV.
        ///
        /// `c`: The ciphertext buffer to write the encrypted data to.
        /// `tag`: The authentication tag buffer to write the computed tag to.
        /// `m`: The plaintext message to encrypt.
        /// `ad`: The associated data to authenticate.
        /// `npub`: The nonce to use for encryption.
        /// `key`: The encryption key.
        pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) void {
            debug.assert(c.len == m.len);
            debug.assert(m.len <= (1 << 36));
            debug.assert(ad.len <= (1 << 36));

            var auth_key: [16]u8 = undefined;
            var message_key: [key_length]u8 = undefined;
            deriveKeys(&message_key, &auth_key, key, npub);

            // Calculate POLYVAL over additional data and plaintext
            const block_count = (math.divCeil(usize, ad.len, Polyval.block_length) catch unreachable) +
                (math.divCeil(usize, m.len, Polyval.block_length) catch unreachable) + 1;
            var mac = Polyval.initForBlockCount(&auth_key, block_count);

            // Process additional data
            mac.update(ad);
            mac.pad();

            // Process plaintext
            mac.update(m);
            mac.pad();

            // Length block
            var length_block: [16]u8 = undefined;
            mem.writeInt(u64, length_block[0..8], @as(u64, ad.len) * 8, .little);
            mem.writeInt(u64, length_block[8..16], @as(u64, m.len) * 8, .little);
            mac.update(&length_block);

            // Get POLYVAL result
            var s: [16]u8 = undefined;
            mac.final(&s);

            // XOR with nonce to get pre-tag
            for (npub, 0..) |b, i| {
                s[i] ^= b;
            }

            // Clear most significant bit of last byte
            s[15] &= 0x7f;

            // Encrypt to get tag
            const tag_aes = Aes.initEnc(message_key);
            tag_aes.encrypt(tag, &s);

            // Use tag as initial counter for CTR mode
            var counter: [16]u8 = tag.*;
            counter[15] |= 0x80; // Set most significant bit

            // Encrypt message using CTR mode with 32-bit little-endian counter
            const aes_ctx = Aes.initEnc(message_key);
            modes.ctrSlice(@TypeOf(aes_ctx), aes_ctx, c, m, counter, .little, 0, 4);
        }

        /// Decrypts and authenticates a message using AES-GCM-SIV.
        ///
        /// `m`: Message buffer to write the decrypted data to.
        /// `c`: The ciphertext to decrypt.
        /// `tag`: The authentication tag.
        /// `ad`: The associated data.
        /// `npub`: The nonce.
        /// `key`: The decryption key.
        /// Asserts `c.len == m.len`.
        pub fn decrypt(m: []u8, c: []const u8, tag: [tag_length]u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) AuthenticationError!void {
            assert(c.len == m.len);
            assert(c.len <= (1 << 36));
            assert(ad.len <= (1 << 36));

            var auth_key: [16]u8 = undefined;
            var message_key: [key_length]u8 = undefined;
            deriveKeys(&message_key, &auth_key, key, npub);

            // Decrypt message using CTR mode with 32-bit little-endian counter
            var counter: [16]u8 = tag;
            counter[15] |= 0x80; // Set most significant bit

            const aes_ctx = Aes.initEnc(message_key);
            modes.ctrSlice(@TypeOf(aes_ctx), aes_ctx, m, c, counter, .little, 0, 4);

            // Verify tag by recalculating POLYVAL
            const block_count = (math.divCeil(usize, ad.len, Polyval.block_length) catch unreachable) +
                (math.divCeil(usize, m.len, Polyval.block_length) catch unreachable) + 1;
            var mac = Polyval.initForBlockCount(&auth_key, block_count);

            // Process additional data
            mac.update(ad);
            mac.pad();

            // Process decrypted plaintext
            mac.update(m);
            mac.pad();

            // Length block
            var length_block: [16]u8 = undefined;
            mem.writeInt(u64, length_block[0..8], @as(u64, ad.len) * 8, .little);
            mem.writeInt(u64, length_block[8..16], @as(u64, m.len) * 8, .little);
            mac.update(&length_block);

            // Get POLYVAL result
            var s: [16]u8 = undefined;
            mac.final(&s);

            // XOR with nonce to get pre-tag
            for (npub, 0..) |b, i| {
                s[i] ^= b;
            }

            // Clear most significant bit of last byte
            s[15] &= 0x7f;

            // Encrypt to get expected tag
            const tag_aes = Aes.initEnc(message_key);
            var computed_tag: [tag_length]u8 = undefined;
            tag_aes.encrypt(&computed_tag, &s);

            // Verify tag
            const verify = crypto.timing_safe.eql([tag_length]u8, computed_tag, tag);
            if (!verify) {
                crypto.secureZero(u8, &computed_tag);
                @memset(m, undefined);
                return error.AuthenticationFailed;
            }
        }
    };
}

const htest = @import("test.zig");
const testing = std.testing;

test "Aes128GcmSiv - RFC 8452 Test Vector 1" {
    // Test vector from RFC 8452 Appendix C.1
    const key = [_]u8{
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    const nonce = [_]u8{
        0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    };
    const ad = "";
    const m = "";
    var c: [m.len]u8 = undefined;
    var tag: [Aes128GcmSiv.tag_length]u8 = undefined;

    Aes128GcmSiv.encrypt(&c, &tag, m, ad, nonce, key);
    try htest.assertEqual("dc20e2d83f25705bb49e439eca56de25", &tag);
}

test "Aes128GcmSiv - RFC 8452 Test Vector 2" {
    // Test vector from RFC 8452 Appendix C.1
    const key = [_]u8{
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    const nonce = [_]u8{
        0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    };
    const plaintext = [_]u8{
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    const ad = "";
    var c: [plaintext.len]u8 = undefined;
    var tag: [Aes128GcmSiv.tag_length]u8 = undefined;

    Aes128GcmSiv.encrypt(&c, &tag, &plaintext, ad, nonce, key);
    try htest.assertEqual("b5d839330ac7b786", &c);
    try htest.assertEqual("578782fff6013b815b287c22493a364c", &tag);

    var m2: [plaintext.len]u8 = undefined;
    try Aes128GcmSiv.decrypt(&m2, &c, tag, ad, nonce, key);
    try testing.expectEqualSlices(u8, &plaintext, &m2);
}

test "Aes128GcmSiv - RFC 8452 Test Vector 3" {
    // Test vector from RFC 8452 Appendix C.1
    const key = [_]u8{
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    const nonce = [_]u8{
        0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    };
    const plaintext = [_]u8{
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    };
    const ad = "";
    var c: [plaintext.len]u8 = undefined;
    var tag: [Aes128GcmSiv.tag_length]u8 = undefined;

    Aes128GcmSiv.encrypt(&c, &tag, &plaintext, ad, nonce, key);
    try htest.assertEqual("7323ea61d05932260047d942", &c);
    try htest.assertEqual("a4978db357391a0bc4fdec8b0d106639", &tag);

    var m2: [plaintext.len]u8 = undefined;
    try Aes128GcmSiv.decrypt(&m2, &c, tag, ad, nonce, key);
    try testing.expectEqualSlices(u8, &plaintext, &m2);
}

test "Aes256GcmSiv - RFC 8452 Test Vector" {
    // Test vector from RFC 8452 Appendix C.2
    const key = [_]u8{
        0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    };
    const nonce = [_]u8{
        0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00,
    };
    const ad = "";
    const m = "";
    var c: [m.len]u8 = undefined;
    var tag: [Aes256GcmSiv.tag_length]u8 = undefined;

    Aes256GcmSiv.encrypt(&c, &tag, m, ad, nonce, key);
    try htest.assertEqual("07f5f4169bbf55a8400cd47ea6fd400f", &tag);
}

test "Aes128GcmSiv - Decrypt with wrong tag" {
    const key: [Aes128GcmSiv.key_length]u8 = @splat(0x69);
    const nonce: [Aes128GcmSiv.nonce_length]u8 = @splat(0x42);
    const m = "Test message";
    const ad = "";
    var c: [m.len]u8 = undefined;
    var tag: [Aes128GcmSiv.tag_length]u8 = undefined;

    Aes128GcmSiv.encrypt(&c, &tag, m, ad, nonce, key);

    // Corrupt the tag
    tag[0] ^= 0x01;

    var m2: [m.len]u8 = undefined;
    try testing.expectError(error.AuthenticationFailed, Aes128GcmSiv.decrypt(&m2, &c, tag, ad, nonce, key));
}
