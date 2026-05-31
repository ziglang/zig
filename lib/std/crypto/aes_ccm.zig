//! AES-CCM (Counter with CBC-MAC) authenticated encryption.
//! AES-CCM* extends CCM to support encryption-only mode (tag_len=0).
//!
//! References:
//! - NIST SP 800-38C: https://csrc.nist.gov/publications/detail/sp/800-38c/final
//! - RFC 3610: https://datatracker.ietf.org/doc/html/rfc3610

const std = @import("std");
const assert = std.debug.assert;
const crypto = std.crypto;
const mem = std.mem;
const modes = crypto.core.modes;
const AuthenticationError = crypto.errors.AuthenticationError;
const cbc_mac = @import("cbc_mac.zig");

/// AES-128-CCM* with no authentication (encryption-only, 13-byte nonce).
pub const Aes128Ccm0 = AesCcm(crypto.core.aes.Aes128, 0, 13);
/// AES-128-CCM with 8-byte authentication tag and 13-byte nonce.
pub const Aes128Ccm8 = AesCcm(crypto.core.aes.Aes128, 8, 13);
/// AES-128-CCM with 16-byte authentication tag and 13-byte nonce.
pub const Aes128Ccm16 = AesCcm(crypto.core.aes.Aes128, 16, 13);
/// AES-256-CCM* with no authentication (encryption-only, 13-byte nonce).
pub const Aes256Ccm0 = AesCcm(crypto.core.aes.Aes256, 0, 13);
/// AES-256-CCM with 8-byte authentication tag and 13-byte nonce.
pub const Aes256Ccm8 = AesCcm(crypto.core.aes.Aes256, 8, 13);
/// AES-256-CCM with 16-byte authentication tag and 13-byte nonce.
pub const Aes256Ccm16 = AesCcm(crypto.core.aes.Aes256, 16, 13);

/// AES-CCM authenticated encryption (NIST SP 800-38C, RFC 3610).
/// CCM* mode extends CCM to support encryption-only mode when tag_len=0.
///
/// `BlockCipher`: Block cipher type (must have 16-byte blocks).
/// `tag_len`: Authentication tag length in bytes (0, 4, 6, 8, 10, 12, 14, or 16).
///            When tag_len=0, CCM* provides encryption-only (no authentication).
/// `nonce_len`: Nonce length in bytes (7 to 13).
fn AesCcm(comptime BlockCipher: type, comptime tag_len: usize, comptime nonce_len: usize) type {
    const block_length = BlockCipher.block.block_length;

    comptime {
        assert(block_length == 16); // CCM requires 16-byte blocks
        if (tag_len != 0 and (tag_len < 4 or tag_len > 16 or tag_len % 2 != 0)) {
            @compileError("CCM tag_length must be 0, 4, 6, 8, 10, 12, 14, or 16 bytes");
        }
        if (nonce_len < 7 or nonce_len > 13) {
            @compileError("CCM nonce_length must be between 7 and 13 bytes");
        }
    }

    const L = 15 - nonce_len; // Counter size in bytes (2 to 8)

    return struct {
        pub const key_length = BlockCipher.key_bits / 8;
        pub const tag_length = tag_len;
        pub const nonce_length = nonce_len;

        /// `c`: Ciphertext output buffer (must be same length as m).
        /// `tag`: Authentication tag output.
        /// `m`: Plaintext message to encrypt.
        /// `ad`: Associated data to authenticate.
        /// `npub`: Public nonce (must be unique for each message with same key).
        /// `key`: Encryption key.
        pub fn encrypt(
            c: []u8,
            tag: *[tag_length]u8,
            m: []const u8,
            ad: []const u8,
            npub: [nonce_length]u8,
            key: [key_length]u8,
        ) void {
            assert(c.len == m.len);

            // Validate message length fits in L bytes
            const max_msg_len: u64 = if (L >= 8) std.math.maxInt(u64) else (@as(u64, 1) << @as(u6, @intCast(L * 8))) - 1;
            assert(m.len <= max_msg_len);

            const cipher_ctx = BlockCipher.initEnc(key);

            // CCM*: Skip authentication if tag_length is 0 (encryption-only mode)
            if (tag_length > 0) {
                // Compute CBC-MAC using the reusable CBC-MAC module
                var mac_result: [block_length]u8 = undefined;
                computeCbcMac(&mac_result, &key, m, ad, npub);

                // Construct counter block for tag encryption (counter = 0)
                var ctr_block: [block_length]u8 = undefined;
                formatCtrBlock(&ctr_block, npub, 0);

                // Encrypt the MAC tag
                var s0: [block_length]u8 = undefined;
                cipher_ctx.encrypt(&s0, &ctr_block);
                for (tag, mac_result[0..tag_length], s0[0..tag_length]) |*t, mac_byte, s_byte| {
                    t.* = mac_byte ^ s_byte;
                }

                crypto.secureZero(u8, &mac_result);
                crypto.secureZero(u8, &s0);
            }

            // Encrypt the plaintext using CTR mode (starting from counter = 1)
            var ctr_block: [block_length]u8 = undefined;
            formatCtrBlock(&ctr_block, npub, 1);
            // CCM counter is in the last L bytes of the block
            modes.ctrSlice(@TypeOf(cipher_ctx), cipher_ctx, c, m, ctr_block, .big, 1 + nonce_len, L);
        }

        /// `m`: Plaintext output buffer (must be same length as c).
        /// `c`: Ciphertext to decrypt.
        /// `tag`: Authentication tag to verify.
        /// `ad`: Associated data (must match encryption).
        /// `npub`: Public nonce (must match encryption).
        /// `key`: Private key.
        ///
        /// Asserts `c.len == m.len`.
        /// Contents of `m` are undefined if an error is returned.
        pub fn decrypt(
            m: []u8,
            c: []const u8,
            tag: [tag_length]u8,
            ad: []const u8,
            npub: [nonce_length]u8,
            key: [key_length]u8,
        ) AuthenticationError!void {
            assert(m.len == c.len);

            const cipher_ctx = BlockCipher.initEnc(key);

            // Decrypt the ciphertext using CTR mode (starting from counter = 1)
            var ctr_block: [block_length]u8 = undefined;
            formatCtrBlock(&ctr_block, npub, 1);
            // CCM counter is in the last L bytes of the block
            modes.ctrSlice(@TypeOf(cipher_ctx), cipher_ctx, m, c, ctr_block, .big, 1 + nonce_len, L);

            // CCM*: Skip authentication if tag_length is 0 (encryption-only mode)
            if (tag_length > 0) {
                // Compute CBC-MAC over decrypted plaintext
                var mac_result: [block_length]u8 = undefined;
                computeCbcMac(&mac_result, &key, m, ad, npub);

                // Decrypt the received tag
                formatCtrBlock(&ctr_block, npub, 0);
                var s0: [block_length]u8 = undefined;
                cipher_ctx.encrypt(&s0, &ctr_block);

                // Reconstruct the expected MAC
                var expected_mac: [tag_length]u8 = undefined;
                for (&expected_mac, mac_result[0..tag_length], s0[0..tag_length]) |*e, mac_byte, s_byte| {
                    e.* = mac_byte ^ s_byte;
                }

                // Constant-time tag comparison
                const valid = crypto.timing_safe.eql([tag_length]u8, expected_mac, tag);
                if (!valid) {
                    crypto.secureZero(u8, &expected_mac);
                    crypto.secureZero(u8, &mac_result);
                    crypto.secureZero(u8, &s0);
                    crypto.secureZero(u8, m);
                    return error.AuthenticationFailed;
                }

                crypto.secureZero(u8, &expected_mac);
                crypto.secureZero(u8, &mac_result);
                crypto.secureZero(u8, &s0);
            }
        }

        /// Format the counter block for CTR mode
        /// Counter block format: [flags | nonce | counter]
        /// flags = L - 1
        fn formatCtrBlock(block: *[block_length]u8, npub: [nonce_length]u8, counter: u64) void {
            @memset(block, 0);
            block[0] = L - 1; // flags
            @memcpy(block[1..][0..nonce_length], &npub);
            // Counter goes in the last L bytes
            const CounterInt = std.meta.Int(.unsigned, L * 8);
            mem.writeInt(CounterInt, block[1 + nonce_length ..][0..L], @as(CounterInt, @intCast(counter)), .big);
        }

        /// Compute CBC-MAC over the message and associated data.
        /// CCM uses plain CBC-MAC, not CMAC (RFC 3610).
        fn computeCbcMac(mac: *[block_length]u8, key: *const [key_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8) void {
            const CbcMac = cbc_mac.CbcMac(BlockCipher);
            var ctx = CbcMac.init(key);

            // Process B_0 block
            var b0: [block_length]u8 = undefined;
            formatB0Block(&b0, m.len, ad.len, npub);
            ctx.update(&b0);

            // Process associated data if present
            // RFC 3610: AD is (encoded_length || ad) padded to block boundary
            if (ad.len > 0) {
                // Encode and add associated data length
                var ad_len_encoding: [10]u8 = undefined;
                const ad_len_size = encodeAdLength(&ad_len_encoding, ad.len);

                // Process AD with padding to block boundary
                ctx.update(ad_len_encoding[0..ad_len_size]);
                ctx.update(ad);

                // Add zero padding to reach block boundary
                const total_ad_size = ad_len_size + ad.len;
                const remainder = total_ad_size % block_length;
                if (remainder > 0) {
                    const padding = [_]u8{0} ** block_length;
                    ctx.update(padding[0 .. block_length - remainder]);
                }
            }

            // Process plaintext message
            ctx.update(m);

            // Finalize MAC
            ctx.final(mac);
        }

        /// Format the B_0 block for CBC-MAC
        /// B_0 format: [flags | nonce | message_length]
        /// flags = 64*Adata + 8*M' + L'
        /// where: Adata = (ad.len > 0), M' = (tag_length - 2)/2 if M>0 else 0, L' = L - 1
        /// CCM*: When tag_length=0, M' is encoded as 0
        fn formatB0Block(block: *[block_length]u8, msg_len: usize, ad_len: usize, npub: [nonce_length]u8) void {
            @memset(block, 0);

            const Adata: u8 = if (ad_len > 0) 1 else 0;
            const M_prime: u8 = if (tag_length > 0) @intCast((tag_length - 2) / 2) else 0;
            const L_prime: u8 = L - 1;

            block[0] = (Adata << 6) | (M_prime << 3) | L_prime;
            @memcpy(block[1..][0..nonce_length], &npub);

            // Encode message length in last L bytes
            const LengthInt = std.meta.Int(.unsigned, L * 8);
            mem.writeInt(LengthInt, block[1 + nonce_length ..][0..L], @as(LengthInt, @intCast(msg_len)), .big);
        }

        /// Encode associated data length according to CCM specification
        /// Returns the number of bytes written
        fn encodeAdLength(buf: *[10]u8, ad_len: usize) usize {
            if (ad_len < 65280) { // 2^16 - 2^8
                // Encode as 2 bytes
                mem.writeInt(u16, buf[0..2], @as(u16, @intCast(ad_len)), .big);
                return 2;
            } else if (ad_len <= std.math.maxInt(u32)) {
                // Encode as 0xff || 0xfe || 4 bytes
                buf[0] = 0xff;
                buf[1] = 0xfe;
                mem.writeInt(u32, buf[2..6], @as(u32, @intCast(ad_len)), .big);
                return 6;
            } else {
                // Encode as 0xff || 0xff || 8 bytes
                buf[0] = 0xff;
                buf[1] = 0xff;
                mem.writeInt(u64, buf[2..10], @as(u64, @intCast(ad_len)), .big);
                return 10;
            }
        }
    };
}

// Tests

const testing = std.testing;
const fmt = std.fmt;
const hexToBytes = fmt.hexToBytes;

test "Aes256Ccm8 - Encrypt decrypt round-trip" {
    const key: [32]u8 = [_]u8{0x42} ** 32;
    const nonce: [13]u8 = [_]u8{0x11} ** 13;
    const m = "Hello, World! This is a test message.";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aes256Ccm8.tag_length]u8 = undefined;

    Aes256Ccm8.encrypt(&c, &tag, m, "", nonce, key);

    try Aes256Ccm8.decrypt(&m2, &c, tag, "", nonce, key);

    try testing.expectEqualSlices(u8, m[0..], m2[0..]);
}

test "Aes256Ccm8 - Associated data" {
    const key: [32]u8 = [_]u8{0x42} ** 32;
    const nonce: [13]u8 = [_]u8{0x11} ** 13;
    const m = "secret message";
    const ad = "additional authenticated data";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aes256Ccm8.tag_length]u8 = undefined;

    Aes256Ccm8.encrypt(&c, &tag, m, ad, nonce, key);

    try Aes256Ccm8.decrypt(&m2, &c, tag, ad, nonce, key);
    try testing.expectEqualSlices(u8, m[0..], m2[0..]);

    var m3: [m.len]u8 = undefined;
    const wrong_adata = "wrong data";
    const result = Aes256Ccm8.decrypt(&m3, &c, tag, wrong_adata, nonce, key);
    try testing.expectError(error.AuthenticationFailed, result);
}

test "Aes256Ccm8 - Wrong key" {
    const key: [32]u8 = [_]u8{0x42} ** 32;
    const wrong_key: [32]u8 = [_]u8{0x43} ** 32;
    const nonce: [13]u8 = [_]u8{0x11} ** 13;
    const m = "secret";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aes256Ccm8.tag_length]u8 = undefined;

    Aes256Ccm8.encrypt(&c, &tag, m, "", nonce, key);

    const result = Aes256Ccm8.decrypt(&m2, &c, tag, "", nonce, wrong_key);
    try testing.expectError(error.AuthenticationFailed, result);
}

test "Aes256Ccm8 - Corrupted ciphertext" {
    const key: [32]u8 = [_]u8{0x42} ** 32;
    const nonce: [13]u8 = [_]u8{0x11} ** 13;
    const m = "secret message";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aes256Ccm8.tag_length]u8 = undefined;

    Aes256Ccm8.encrypt(&c, &tag, m, "", nonce, key);

    c[5] ^= 0xFF;

    const result = Aes256Ccm8.decrypt(&m2, &c, tag, "", nonce, key);
    try testing.expectError(error.AuthenticationFailed, result);
}

test "Aes256Ccm8 - Empty plaintext" {
    const key: [32]u8 = [_]u8{0x42} ** 32;
    const nonce: [13]u8 = [_]u8{0x11} ** 13;
    const m = "";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aes256Ccm8.tag_length]u8 = undefined;

    Aes256Ccm8.encrypt(&c, &tag, m, "", nonce, key);

    try Aes256Ccm8.decrypt(&m2, &c, tag, "", nonce, key);

    try testing.expectEqual(@as(usize, 0), m2.len);
}

test "Aes128Ccm8 - Basic functionality" {
    const key: [16]u8 = [_]u8{0x42} ** 16;
    const nonce: [13]u8 = [_]u8{0x11} ** 13;
    const m = "Test AES-128-CCM";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aes128Ccm8.tag_length]u8 = undefined;

    Aes128Ccm8.encrypt(&c, &tag, m, "", nonce, key);

    try Aes128Ccm8.decrypt(&m2, &c, tag, "", nonce, key);

    try testing.expectEqualSlices(u8, m[0..], m2[0..]);
}

test "Aes256Ccm16 - 16-byte tag" {
    const key: [32]u8 = [_]u8{0x42} ** 32;
    const nonce: [13]u8 = [_]u8{0x11} ** 13;
    const m = "Test 16-byte tag";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aes256Ccm16.tag_length]u8 = undefined;

    Aes256Ccm16.encrypt(&c, &tag, m, "", nonce, key);

    try testing.expectEqual(@as(usize, 16), tag.len);

    try Aes256Ccm16.decrypt(&m2, &c, tag, "", nonce, key);

    try testing.expectEqualSlices(u8, m[0..], m2[0..]);
}

test "Aes256Ccm8 - Edge case short nonce" {
    const Aes256Ccm8_7 = AesCcm(crypto.core.aes.Aes256, 8, 7);
    var key: [32]u8 = undefined;
    _ = try hexToBytes(&key, "eda32f751456e33195f1f499cf2dc7c97ea127b6d488f211ccc5126fbb24afa6");
    var nonce: [7]u8 = undefined;
    _ = try hexToBytes(&nonce, "a544218dadd3c1");
    var m: [1]u8 = undefined;
    _ = try hexToBytes(&m, "00");

    var c: [m.len]u8 = undefined;
    var tag: [Aes256Ccm8_7.tag_length]u8 = undefined;

    Aes256Ccm8_7.encrypt(&c, &tag, &m, "", nonce, key);

    var m2: [c.len]u8 = undefined;

    try Aes256Ccm8_7.decrypt(&m2, &c, tag, "", nonce, key);
    try testing.expectEqualSlices(u8, &m, &m2);
}

test "Aes256Ccm8 - Edge case long nonce" {
    var key: [32]u8 = undefined;
    _ = try hexToBytes(&key, "e1b8a927a95efe94656677b692662000278b441c79e879dd5c0ddc758bdc9ee8");
    var nonce: [13]u8 = undefined;
    _ = try hexToBytes(&nonce, "a544218dadd3c10583db49cf39");
    var m: [1]u8 = undefined;
    _ = try hexToBytes(&m, "00");

    var c: [m.len]u8 = undefined;
    var tag: [Aes256Ccm8.tag_length]u8 = undefined;

    Aes256Ccm8.encrypt(&c, &tag, &m, "", nonce, key);

    var m2: [c.len]u8 = undefined;

    try Aes256Ccm8.decrypt(&m2, &c, tag, "", nonce, key);
    try testing.expectEqualSlices(u8, &m, &m2);
}

test "Aes256Ccm8 - With AAD and wrong AAD detection" {
    var key: [32]u8 = undefined;
    _ = try hexToBytes(&key, "8c5cf3457ff22228c39c051c4e05ed4093657eb303f859a9d4b0f8be0127d88a");
    var nonce: [13]u8 = undefined;
    _ = try hexToBytes(&nonce, "a544218dadd3c10583db49cf39");
    var m: [1]u8 = undefined;
    _ = try hexToBytes(&m, "00");
    var ad: [32]u8 = undefined;
    _ = try hexToBytes(&ad, "3c0e2815d37d844f7ac240ba9d6e3a0b2a86f706e885959e09a1005e024f6907");

    var c: [m.len]u8 = undefined;
    var tag: [Aes256Ccm8.tag_length]u8 = undefined;

    Aes256Ccm8.encrypt(&c, &tag, &m, &ad, nonce, key);

    var m2: [c.len]u8 = undefined;

    try Aes256Ccm8.decrypt(&m2, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &m, &m2);

    var wrong_ad: [32]u8 = undefined;
    _ = try hexToBytes(&wrong_ad, "0000000000000000000000000000000000000000000000000000000000000000");
    var m3: [c.len]u8 = undefined;
    const result = Aes256Ccm8.decrypt(&m3, &c, tag, &wrong_ad, nonce, key);
    try testing.expectError(error.AuthenticationFailed, result);
}

test "Aes256Ccm8 - Multi-block payload" {
    const Aes256Ccm8_12 = AesCcm(crypto.core.aes.Aes256, 8, 12);

    // Test with 32-byte payload (2 AES blocks)
    var key: [32]u8 = undefined;
    _ = try hexToBytes(&key, "af063639e66c284083c5cf72b70d8bc277f5978e80d9322d99f2fdc718cda569");
    var nonce: [12]u8 = undefined;
    _ = try hexToBytes(&nonce, "a544218dadd3c10583db49cf");
    var m: [32]u8 = undefined;
    _ = try hexToBytes(&m, "00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff");

    // Encrypt
    var c: [32]u8 = undefined;
    var tag: [Aes256Ccm8_12.tag_length]u8 = undefined;

    Aes256Ccm8_12.encrypt(&c, &tag, &m, "", nonce, key);

    // Decrypt and verify
    var m2: [32]u8 = undefined;

    try Aes256Ccm8_12.decrypt(&m2, &c, tag, "", nonce, key);
    try testing.expectEqualSlices(u8, &m, &m2);
}

test "Aes256Ccm8 - Multi-block with AAD" {
    const Aes256Ccm8_12 = AesCcm(crypto.core.aes.Aes256, 8, 12);

    // Test with multi-block payload (3 AES blocks) and AAD
    var key: [32]u8 = undefined;
    _ = try hexToBytes(&key, "f7079dfa3b5c7b056347d7e437bcded683abd6e2c9e069d333284082cbb5d453");
    var nonce: [12]u8 = undefined;
    _ = try hexToBytes(&nonce, "5b8e40746f6b98e00f1d13ff");

    // 48-byte payload (3 AES blocks)
    var m: [48]u8 = undefined;
    _ = try hexToBytes(&m, "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f");

    // 16-byte AAD
    var ad: [16]u8 = undefined;
    _ = try hexToBytes(&ad, "000102030405060708090a0b0c0d0e0f");

    // Encrypt
    var c: [48]u8 = undefined;
    var tag: [Aes256Ccm8_12.tag_length]u8 = undefined;

    Aes256Ccm8_12.encrypt(&c, &tag, &m, &ad, nonce, key);

    // Decrypt and verify
    var m2: [48]u8 = undefined;

    try Aes256Ccm8_12.decrypt(&m2, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &m, &m2);
}

test "Aes256Ccm8 - Minimum nonce length" {
    const Aes256Ccm8_7 = AesCcm(crypto.core.aes.Aes256, 8, 7);

    // Test with 7-byte nonce (minimum allowed by CCM spec)
    var key: [32]u8 = undefined;
    _ = try hexToBytes(&key, "404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f");
    var nonce: [7]u8 = undefined;
    _ = try hexToBytes(&nonce, "10111213141516");
    const m = "Test message with minimum nonce length";

    // Encrypt
    var c: [m.len]u8 = undefined;
    var tag: [Aes256Ccm8_7.tag_length]u8 = undefined;

    Aes256Ccm8_7.encrypt(&c, &tag, m, "", nonce, key);

    // Decrypt and verify
    var m2: [m.len]u8 = undefined;

    try Aes256Ccm8_7.decrypt(&m2, &c, tag, "", nonce, key);
    try testing.expectEqualSlices(u8, m[0..], m2[0..]);
}

test "Aes256Ccm8 - Maximum nonce length" {
    // Test with 13-byte nonce (maximum allowed by CCM spec)
    var key: [32]u8 = undefined;
    _ = try hexToBytes(&key, "606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f");
    var nonce: [13]u8 = undefined;
    _ = try hexToBytes(&nonce, "101112131415161718191a1b1c");
    const m = "Test message with maximum nonce length";

    // Encrypt
    var c: [m.len]u8 = undefined;
    var tag: [Aes256Ccm8.tag_length]u8 = undefined;

    Aes256Ccm8.encrypt(&c, &tag, m, "", nonce, key);

    // Decrypt and verify
    var m2: [m.len]u8 = undefined;

    try Aes256Ccm8.decrypt(&m2, &c, tag, "", nonce, key);
    try testing.expectEqualSlices(u8, m[0..], m2[0..]);
}

// RFC 3610 test vectors

test "Aes128Ccm8 - RFC 3610 Packet Vector #1" {
    const Aes128Ccm8_13 = AesCcm(crypto.core.aes.Aes128, 8, 13);

    // RFC 3610 Appendix A, Packet Vector #1
    var key: [16]u8 = undefined;
    _ = try hexToBytes(&key, "C0C1C2C3C4C5C6C7C8C9CACBCCCDCECF");
    var nonce: [13]u8 = undefined;
    _ = try hexToBytes(&nonce, "00000003020100A0A1A2A3A4A5");
    var ad: [8]u8 = undefined;
    _ = try hexToBytes(&ad, "0001020304050607");
    var plaintext: [23]u8 = undefined;
    _ = try hexToBytes(&plaintext, "08090A0B0C0D0E0F101112131415161718191A1B1C1D1E");

    // Expected ciphertext and tag from RFC
    var expected_ciphertext: [23]u8 = undefined;
    _ = try hexToBytes(&expected_ciphertext, "588C979A61C663D2F066D0C2C0F989806D5F6B61DAC384");
    var expected_tag: [8]u8 = undefined;
    _ = try hexToBytes(&expected_tag, "17E8D12CFDF926E0");

    // Encrypt
    var c: [plaintext.len]u8 = undefined;
    var tag: [Aes128Ccm8_13.tag_length]u8 = undefined;

    Aes128Ccm8_13.encrypt(&c, &tag, &plaintext, &ad, nonce, key);

    // Verify ciphertext matches RFC expected output
    try testing.expectEqualSlices(u8, &expected_ciphertext, &c);

    // Verify tag matches RFC expected output
    try testing.expectEqualSlices(u8, &expected_tag, &tag);

    // Decrypt and verify round-trip
    var m: [plaintext.len]u8 = undefined;
    try Aes128Ccm8_13.decrypt(&m, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &plaintext, &m);
}

test "Aes128Ccm8 - RFC 3610 Packet Vector #2" {
    const Aes128Ccm8_13 = AesCcm(crypto.core.aes.Aes128, 8, 13);

    // RFC 3610 Appendix A, Packet Vector #2 (8-byte tag, M=8)
    var key: [16]u8 = undefined;
    _ = try hexToBytes(&key, "C0C1C2C3C4C5C6C7C8C9CACBCCCDCECF");
    var nonce: [13]u8 = undefined;
    _ = try hexToBytes(&nonce, "00000004030201A0A1A2A3A4A5");
    var ad: [8]u8 = undefined;
    _ = try hexToBytes(&ad, "0001020304050607");
    var plaintext: [24]u8 = undefined;
    _ = try hexToBytes(&plaintext, "08090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F");

    // Expected ciphertext and tag from RFC (from total packet: header + ciphertext + tag)
    var expected_ciphertext: [24]u8 = undefined;
    _ = try hexToBytes(&expected_ciphertext, "72C91A36E135F8CF291CA894085C87E3CC15C439C9E43A3B");
    var expected_tag: [8]u8 = undefined;
    _ = try hexToBytes(&expected_tag, "A091D56E10400916");

    // Encrypt
    var c: [plaintext.len]u8 = undefined;
    var tag: [Aes128Ccm8_13.tag_length]u8 = undefined;

    Aes128Ccm8_13.encrypt(&c, &tag, &plaintext, &ad, nonce, key);

    // Verify ciphertext matches RFC expected output
    try testing.expectEqualSlices(u8, &expected_ciphertext, &c);

    // Verify tag matches RFC expected output
    try testing.expectEqualSlices(u8, &expected_tag, &tag);

    // Decrypt and verify round-trip
    var m: [plaintext.len]u8 = undefined;
    try Aes128Ccm8_13.decrypt(&m, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &plaintext, &m);
}

test "Aes128Ccm8 - RFC 3610 Packet Vector #3" {
    const Aes128Ccm8_13 = AesCcm(crypto.core.aes.Aes128, 8, 13);

    // RFC 3610 Appendix A, Packet Vector #3 (8-byte tag, 25-byte payload)
    var key: [16]u8 = undefined;
    _ = try hexToBytes(&key, "C0C1C2C3C4C5C6C7C8C9CACBCCCDCECF");
    var nonce: [13]u8 = undefined;
    _ = try hexToBytes(&nonce, "00000005040302A0A1A2A3A4A5");
    var ad: [8]u8 = undefined;
    _ = try hexToBytes(&ad, "0001020304050607");
    var plaintext: [25]u8 = undefined;
    _ = try hexToBytes(&plaintext, "08090A0B0C0D0E0F101112131415161718191A1B1C1D1E1F20");

    // Expected ciphertext and tag from RFC
    var expected_ciphertext: [25]u8 = undefined;
    _ = try hexToBytes(&expected_ciphertext, "51B1E5F44A197D1DA46B0F8E2D282AE871E838BB64DA859657");
    var expected_tag: [8]u8 = undefined;
    _ = try hexToBytes(&expected_tag, "4ADAA76FBD9FB0C5");

    // Encrypt
    var c: [plaintext.len]u8 = undefined;
    var tag: [Aes128Ccm8_13.tag_length]u8 = undefined;

    Aes128Ccm8_13.encrypt(&c, &tag, &plaintext, &ad, nonce, key);

    // Verify ciphertext matches RFC expected output
    try testing.expectEqualSlices(u8, &expected_ciphertext, &c);

    // Verify tag matches RFC expected output
    try testing.expectEqualSlices(u8, &expected_tag, &tag);

    // Decrypt and verify round-trip
    var m: [plaintext.len]u8 = undefined;
    try Aes128Ccm8_13.decrypt(&m, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &plaintext, &m);
}

// NIST SP 800-38C test vectors

test "Aes128Ccm4 - NIST SP 800-38C Example 1" {
    const Aes128Ccm4_7 = AesCcm(crypto.core.aes.Aes128, 4, 7);

    // Example 1 (C.1): Klen=128, Tlen=32, Nlen=56, Alen=64, Plen=32
    var key: [16]u8 = undefined;
    _ = try hexToBytes(&key, "404142434445464748494a4b4c4d4e4f");
    var nonce: [7]u8 = undefined;
    _ = try hexToBytes(&nonce, "10111213141516");
    var ad: [8]u8 = undefined;
    _ = try hexToBytes(&ad, "0001020304050607");
    var plaintext: [4]u8 = undefined;
    _ = try hexToBytes(&plaintext, "20212223");

    // Expected ciphertext and tag from NIST
    var expected_ciphertext: [4]u8 = undefined;
    _ = try hexToBytes(&expected_ciphertext, "7162015b");
    var expected_tag: [4]u8 = undefined;
    _ = try hexToBytes(&expected_tag, "4dac255d");

    // Encrypt
    var c: [plaintext.len]u8 = undefined;
    var tag: [Aes128Ccm4_7.tag_length]u8 = undefined;

    Aes128Ccm4_7.encrypt(&c, &tag, &plaintext, &ad, nonce, key);

    // Verify ciphertext matches NIST expected output
    try testing.expectEqualSlices(u8, &expected_ciphertext, &c);

    // Verify tag matches NIST expected output
    try testing.expectEqualSlices(u8, &expected_tag, &tag);

    // Decrypt and verify round-trip
    var m: [plaintext.len]u8 = undefined;
    try Aes128Ccm4_7.decrypt(&m, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &plaintext, &m);
}

test "Aes128Ccm6 - NIST SP 800-38C Example 2" {
    const Aes128Ccm6_8 = AesCcm(crypto.core.aes.Aes128, 6, 8);

    // Example 2 (C.2): Klen=128, Tlen=48, Nlen=64, Alen=128, Plen=128
    var key: [16]u8 = undefined;
    _ = try hexToBytes(&key, "404142434445464748494a4b4c4d4e4f");
    var nonce: [8]u8 = undefined;
    _ = try hexToBytes(&nonce, "1011121314151617");
    var ad: [16]u8 = undefined;
    _ = try hexToBytes(&ad, "000102030405060708090a0b0c0d0e0f");
    var plaintext: [16]u8 = undefined;
    _ = try hexToBytes(&plaintext, "202122232425262728292a2b2c2d2e2f");

    // Expected ciphertext and tag from NIST
    var expected_ciphertext: [16]u8 = undefined;
    _ = try hexToBytes(&expected_ciphertext, "d2a1f0e051ea5f62081a7792073d593d");
    var expected_tag: [6]u8 = undefined;
    _ = try hexToBytes(&expected_tag, "1fc64fbfaccd");

    // Encrypt
    var c: [plaintext.len]u8 = undefined;
    var tag: [Aes128Ccm6_8.tag_length]u8 = undefined;

    Aes128Ccm6_8.encrypt(&c, &tag, &plaintext, &ad, nonce, key);

    // Verify ciphertext matches NIST expected output
    try testing.expectEqualSlices(u8, &expected_ciphertext, &c);

    // Verify tag matches NIST expected output
    try testing.expectEqualSlices(u8, &expected_tag, &tag);

    // Decrypt and verify round-trip
    var m: [plaintext.len]u8 = undefined;
    try Aes128Ccm6_8.decrypt(&m, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &plaintext, &m);
}

test "Aes128Ccm8 - NIST SP 800-38C Example 3" {
    const Aes128Ccm8_12 = AesCcm(crypto.core.aes.Aes128, 8, 12);

    // Example 3 (C.3): Klen=128, Tlen=64, Nlen=96, Alen=160, Plen=192
    var key: [16]u8 = undefined;
    _ = try hexToBytes(&key, "404142434445464748494a4b4c4d4e4f");
    var nonce: [12]u8 = undefined;
    _ = try hexToBytes(&nonce, "101112131415161718191a1b");
    var ad: [20]u8 = undefined;
    _ = try hexToBytes(&ad, "000102030405060708090a0b0c0d0e0f10111213");
    var plaintext: [24]u8 = undefined;
    _ = try hexToBytes(&plaintext, "202122232425262728292a2b2c2d2e2f3031323334353637");

    // Expected ciphertext and tag from NIST
    var expected_ciphertext: [24]u8 = undefined;
    _ = try hexToBytes(&expected_ciphertext, "e3b201a9f5b71a7a9b1ceaeccd97e70b6176aad9a4428aa5");
    var expected_tag: [8]u8 = undefined;
    _ = try hexToBytes(&expected_tag, "484392fbc1b09951");

    // Encrypt
    var c: [plaintext.len]u8 = undefined;
    var tag: [Aes128Ccm8_12.tag_length]u8 = undefined;

    Aes128Ccm8_12.encrypt(&c, &tag, &plaintext, &ad, nonce, key);

    // Verify ciphertext matches NIST expected output
    try testing.expectEqualSlices(u8, &expected_ciphertext, &c);

    // Verify tag matches NIST expected output
    try testing.expectEqualSlices(u8, &expected_tag, &tag);

    // Decrypt and verify round-trip
    var m: [plaintext.len]u8 = undefined;
    try Aes128Ccm8_12.decrypt(&m, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &plaintext, &m);
}

test "Aes128Ccm14 - NIST SP 800-38C Example 4" {
    const Aes128Ccm14_13 = AesCcm(crypto.core.aes.Aes128, 14, 13);

    // Example 4 (C.4): Klen=128, Tlen=112, Nlen=104, Alen=524288, Plen=256
    // Note: Associated data is 65536 bytes (256-byte pattern repeated 256 times)
    var key: [16]u8 = undefined;
    _ = try hexToBytes(&key, "404142434445464748494a4b4c4d4e4f");
    var nonce: [13]u8 = undefined;
    _ = try hexToBytes(&nonce, "101112131415161718191a1b1c");
    var plaintext: [32]u8 = undefined;
    _ = try hexToBytes(&plaintext, "202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f");

    // Generate 65536-byte associated data (256-byte pattern repeated 256 times)
    var pattern: [256]u8 = undefined;
    _ = try hexToBytes(&pattern, "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9fa0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebfc0c1c2c3c4c5c6c7c8c9cacbcccdcecfd0d1d2d3d4d5d6d7d8d9dadbdcdddedfe0e1e2e3e4e5e6e7e8e9eaebecedeeeff0f1f2f3f4f5f6f7f8f9fafbfcfdfeff");

    var ad: [65536]u8 = undefined;
    for (0..256) |i| {
        @memcpy(ad[i * 256 .. (i + 1) * 256], &pattern);
    }

    // Expected ciphertext and tag from NIST
    var expected_ciphertext: [32]u8 = undefined;
    _ = try hexToBytes(&expected_ciphertext, "69915dad1e84c6376a68c2967e4dab615ae0fd1faec44cc484828529463ccf72");
    var expected_tag: [14]u8 = undefined;
    _ = try hexToBytes(&expected_tag, "b4ac6bec93e8598e7f0dadbcea5b");

    // Encrypt
    var c: [plaintext.len]u8 = undefined;
    var tag: [Aes128Ccm14_13.tag_length]u8 = undefined;

    Aes128Ccm14_13.encrypt(&c, &tag, &plaintext, &ad, nonce, key);

    // Verify ciphertext matches NIST expected output
    try testing.expectEqualSlices(u8, &expected_ciphertext, &c);

    // Verify tag matches NIST expected output
    try testing.expectEqualSlices(u8, &expected_tag, &tag);

    // Decrypt and verify round-trip
    var m: [plaintext.len]u8 = undefined;
    try Aes128Ccm14_13.decrypt(&m, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &plaintext, &m);
}

// CCM* test vectors (encryption-only mode with M=0)

test "Aes128Ccm0 - IEEE 802.15.4 Data Frame (Encryption-only)" {
    // IEEE 802.15.4 test vector from section 2.7
    // Security level 0x04 (ENC, encryption without authentication)
    var key: [16]u8 = undefined;
    _ = try hexToBytes(&key, "C0C1C2C3C4C5C6C7C8C9CACBCCCDCECF");
    var nonce: [13]u8 = undefined;
    _ = try hexToBytes(&nonce, "ACDE48000000000100000005" ++ "04");
    var plaintext: [4]u8 = undefined;
    _ = try hexToBytes(&plaintext, "61626364");
    var ad: [26]u8 = undefined;
    _ = try hexToBytes(&ad, "69DC84214302000000004DEAC010000000048DEAC04050000");

    // Expected ciphertext from IEEE spec
    var expected_ciphertext: [4]u8 = undefined;
    _ = try hexToBytes(&expected_ciphertext, "D43E022B");

    // Encrypt
    var c: [plaintext.len]u8 = undefined;
    var tag: [Aes128Ccm0.tag_length]u8 = undefined;

    Aes128Ccm0.encrypt(&c, &tag, &plaintext, &ad, nonce, key);

    // Verify ciphertext matches IEEE expected output
    try testing.expectEqualSlices(u8, &expected_ciphertext, &c);

    // Decrypt and verify round-trip
    var m: [plaintext.len]u8 = undefined;
    try Aes128Ccm0.decrypt(&m, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &plaintext, &m);
}

test "Aes128Ccm0 - Zero-length plaintext with encryption-only" {
    const key: [16]u8 = [_]u8{0x42} ** 16;
    const nonce: [13]u8 = [_]u8{0x11} ** 13;
    const m = "";
    const ad = "some associated data";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aes128Ccm0.tag_length]u8 = undefined;

    Aes128Ccm0.encrypt(&c, &tag, m, ad, nonce, key);

    try Aes128Ccm0.decrypt(&m2, &c, tag, ad, nonce, key);

    try testing.expectEqual(@as(usize, 0), m2.len);
}

test "Aes256Ccm0 - Basic encryption-only round-trip" {
    const key: [32]u8 = [_]u8{0x42} ** 32;
    const nonce: [13]u8 = [_]u8{0x11} ** 13;
    const m = "Hello, CCM* encryption-only mode!";
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aes256Ccm0.tag_length]u8 = undefined;

    Aes256Ccm0.encrypt(&c, &tag, m, "", nonce, key);

    try Aes256Ccm0.decrypt(&m2, &c, tag, "", nonce, key);

    try testing.expectEqualSlices(u8, m[0..], m2[0..]);
}
