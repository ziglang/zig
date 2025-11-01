const std = @import("std");
const assert = std.debug.assert;
const crypto = std.crypto;
const debug = std.debug;
const mem = std.mem;
const math = std.math;
const modes = crypto.core.modes;
const Cmac = @import("cmac.zig").Cmac;
const AuthenticationError = crypto.errors.AuthenticationError;

pub const Aes128Siv = AesSiv(crypto.core.aes.Aes128);
pub const Aes256Siv = AesSiv(crypto.core.aes.Aes256);

/// AES-SIV: Deterministic authenticated encryption - the same message always produces the same ciphertext.
///
/// What it does: Encrypts data and protects it from tampering. Unlike most encryption modes,
/// AES-SIV is deterministic: encrypting the same message with the same key always produces
/// the same ciphertext (unless you provide an optional nonce).
///
/// When to use AES-SIV:
/// - When you need deterministic encryption (e.g., for deduplication in encrypted storage)
/// - When you can't store or generate nonces
/// - For key wrapping (protecting cryptographic keys)
/// - When you need to search encrypted data without decrypting it
///
/// When NOT to use AES-SIV:
/// - When identical plaintexts must produce different ciphertexts (use AES-GCM or AES-GCM-SIV)
/// - For network protocols where replay attacks are a concern
///
/// Unique features:
/// - Optional nonce: You can add a nonce to make encryption non-deterministic, but this is optional
/// - Multiple associated data: Supports a vector of associated data strings instead of just one.
///   The algorithm cryptographically ensures each component is properly separated, preventing
///   canonicalization attacks where different splits of data could be accepted as valid.
///
/// Security properties:
/// - Deterministic: Same input always gives same output (this can leak information about patterns)
/// - Nonce misuse resistant: Doesn't catastrophically fail if you reuse a nonce
/// - Key commitment: Ciphertext can only be decrypted with the exact key that encrypted it
///
/// AES-SIV has better security properties than AES-GCM-SIV, but is must slower.
///
/// How it works: Combines two keys - one for authentication (S2V) and one for encryption (CTR mode).
/// The total key size is double the AES key size (256 bits for AES-128-SIV, 512 bits for AES-256-SIV).
///
/// Defined in RFC 5297.
fn AesSiv(comptime Aes: anytype) type {
    debug.assert(Aes.block.block_length == 16);

    return struct {
        pub const tag_length = 16;
        pub const key_length = Aes.key_bits / 8 * 2; // SIV uses 2x key size

        const CmacImpl = Cmac(Aes);

        /// S2V (String to Vector) - RFC 5297 Section 2.4
        /// Derives a synthetic IV from the key and input strings using CMAC.
        /// This function implements a cryptographic pseudo-random function that maps
        /// a variable-length vector of strings to a fixed 128-bit output.
        fn s2v(iv: *[16]u8, key: [Aes.key_bits / 8]u8, strings: []const []const u8) void {
            assert(strings.len > 0);
            assert(strings.len <= 127); // S2V limitation

            var d: [16]u8 = undefined;

            // Special case: single empty string
            if (strings.len == 1 and strings[0].len == 0) {
                CmacImpl.create(&d, &[_]u8{}, &key);
                iv.* = d;
                return;
            }

            // Initialize with CMAC of zero block
            const zero_block: [16]u8 = @splat(0);
            CmacImpl.create(&d, &zero_block, &key);

            // Process all strings except the last one
            var i: usize = 0;
            while (i < strings.len - 1) : (i += 1) {
                d = dbl(d);
                var tmp: [16]u8 = undefined;
                CmacImpl.create(&tmp, strings[i], &key);
                for (&d, tmp) |*b, t| {
                    b.* ^= t;
                }
            }

            // Process the final string
            const sn = strings[strings.len - 1];
            if (sn.len >= 16) {
                // XOR d with the first 16 bytes of Sn
                var xored_msg_buf: [4096]u8 = undefined;
                const xored_len = @min(sn.len, xored_msg_buf.len);
                @memcpy(xored_msg_buf[0..xored_len], sn[0..xored_len]);

                for (d, 0..) |b, j| {
                    xored_msg_buf[j] ^= b;
                }

                CmacImpl.create(iv, xored_msg_buf[0..xored_len], &key);
            } else {
                // Pad and XOR
                d = dbl(d);
                var padded: [16]u8 = @splat(0);
                @memcpy(padded[0..sn.len], sn);
                padded[sn.len] = 0x80;
                for (&d, padded) |*b, p| {
                    b.* ^= p;
                }
                CmacImpl.create(iv, &d, &key);
            }
        }

        /// Double operation as defined in RFC 5297.
        /// Performs multiplication by x (i.e., left shift by 1) in GF(2^128).
        /// This is the same operation used in CMAC subkey generation.
        /// If the MSB is set, XORs with the polynomial 0x87 after shifting.
        fn dbl(d: [16]u8) [16]u8 {
            // Read as big-endian 128-bit integer
            const val = mem.readInt(u128, &d, .big);

            // Left shift by 1, and XOR with 0x87 if MSB was set
            const doubled = (val << 1) ^ (0x87 & -%(@as(u128, val >> 127)));

            // Write back as big-endian
            var result: [16]u8 = undefined;
            mem.writeInt(u128, &result, doubled, .big);
            return result;
        }

        /// Encrypt plaintext using AES-SIV
        /// `c`: Output buffer for ciphertext (same size as plaintext)
        /// `tag`: Output buffer for authentication tag (synthetic IV)
        /// `m`: Plaintext to encrypt
        /// `ad`: Optional associated data
        /// `nonce`: Optional nonce (if provided, will be added as last AD component)
        /// `key`: Combined key (2x AES key size)
        pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: ?[]const u8, nonce: ?[]const u8, key: [key_length]u8) void {
            debug.assert(c.len == m.len);

            // Split key into K1 (for S2V) and K2 (for CTR)
            const k1 = key[0 .. Aes.key_bits / 8];
            const k2 = key[Aes.key_bits / 8 ..];

            // Prepare strings for S2V: AD components followed by plaintext
            var strings_buf: [128][]const u8 = undefined;
            var strings_len: usize = 0;

            if (ad) |a| {
                strings_buf[strings_len] = a;
                strings_len += 1;
            }
            if (nonce) |n| {
                strings_buf[strings_len] = n;
                strings_len += 1;
            }
            strings_buf[strings_len] = m;
            strings_len += 1;

            // Compute synthetic IV using S2V
            s2v(tag, k1.*, strings_buf[0..strings_len]);

            // Clear the 31st and 63rd bits for use as CTR IV
            var ctr_iv = tag.*;
            ctr_iv[8] &= 0x7f;
            ctr_iv[12] &= 0x7f;

            // Encrypt plaintext using CTR mode
            const aes_ctx = Aes.initEnc(k2.*);
            modes.ctr(@TypeOf(aes_ctx), aes_ctx, c, m, ctr_iv, .big);
        }

        /// Decrypt ciphertext using AES-SIV
        /// `m`: Output buffer for decrypted plaintext
        /// `c`: Ciphertext to decrypt
        /// `tag`: Authentication tag (synthetic IV)
        /// `ad`: Optional associated data (must match encryption)
        /// `nonce`: Optional nonce (must match encryption)
        /// `key`: Combined key (2x AES key size)
        pub fn decrypt(m: []u8, c: []const u8, tag: [tag_length]u8, ad: ?[]const u8, nonce: ?[]const u8, key: [key_length]u8) AuthenticationError!void {
            assert(c.len == m.len);

            // Split key into K1 (for S2V) and K2 (for CTR)
            const k1 = key[0 .. Aes.key_bits / 8];
            const k2 = key[Aes.key_bits / 8 ..];

            // Clear the 31st and 63rd bits for use as CTR IV
            var ctr_iv = tag;
            ctr_iv[8] &= 0x7f;
            ctr_iv[12] &= 0x7f;

            // Decrypt ciphertext using CTR mode
            const aes_ctx = Aes.initEnc(k2.*);
            modes.ctr(@TypeOf(aes_ctx), aes_ctx, m, c, ctr_iv, .big);

            // Prepare strings for S2V: AD components followed by plaintext
            var strings_buf: [128][]const u8 = undefined;
            var strings_len: usize = 0;

            if (ad) |a| {
                strings_buf[strings_len] = a;
                strings_len += 1;
            }
            if (nonce) |n| {
                strings_buf[strings_len] = n;
                strings_len += 1;
            }
            strings_buf[strings_len] = m;
            strings_len += 1;

            // Verify synthetic IV using S2V
            var computed_tag: [tag_length]u8 = undefined;
            s2v(&computed_tag, k1.*, strings_buf[0..strings_len]);

            // Verify tag
            const verify = crypto.timing_safe.eql([tag_length]u8, computed_tag, tag);
            if (!verify) {
                crypto.secureZero(u8, &computed_tag);
                @memset(m, undefined);
                return error.AuthenticationFailed;
            }
        }

        /// Encrypts plaintext with multiple associated data components.
        /// This is the most general form of AES-SIV encryption that accepts
        /// an arbitrary vector of associated data strings as specified in RFC 5297.
        pub fn encryptWithAdVector(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const []const u8, key: [key_length]u8) void {
            debug.assert(c.len == m.len);

            // Split key into K1 (for S2V) and K2 (for CTR)
            const k1 = key[0 .. Aes.key_bits / 8];
            const k2 = key[Aes.key_bits / 8 ..];

            // Prepare strings for S2V: AD components followed by plaintext
            var strings_buf: [128][]const u8 = undefined;
            var strings_len: usize = 0;

            for (ad) |a| {
                strings_buf[strings_len] = a;
                strings_len += 1;
            }
            strings_buf[strings_len] = m;
            strings_len += 1;

            // Compute synthetic IV using S2V
            s2v(tag, k1.*, strings_buf[0..strings_len]);

            // Clear the 31st and 63rd bits for use as CTR IV
            var ctr_iv = tag.*;
            ctr_iv[8] &= 0x7f;
            ctr_iv[12] &= 0x7f;

            // Encrypt plaintext using CTR mode
            const aes_ctx = Aes.initEnc(k2.*);
            modes.ctr(@TypeOf(aes_ctx), aes_ctx, c, m, ctr_iv, .big);
        }

        /// Decrypts ciphertext with multiple associated data components.
        /// This is the most general form of AES-SIV decryption that accepts
        /// an arbitrary vector of associated data strings as specified in RFC 5297.
        pub fn decryptWithAdVector(m: []u8, c: []const u8, tag: [tag_length]u8, ad: []const []const u8, key: [key_length]u8) AuthenticationError!void {
            assert(c.len == m.len);

            // Split key into K1 (for S2V) and K2 (for CTR)
            const k1 = key[0 .. Aes.key_bits / 8];
            const k2 = key[Aes.key_bits / 8 ..];

            // Clear the 31st and 63rd bits for use as CTR IV
            var ctr_iv = tag;
            ctr_iv[8] &= 0x7f;
            ctr_iv[12] &= 0x7f;

            // Decrypt ciphertext using CTR mode
            const aes_ctx = Aes.initEnc(k2.*);
            modes.ctr(@TypeOf(aes_ctx), aes_ctx, m, c, ctr_iv, .big);

            // Prepare strings for S2V: AD components followed by plaintext
            var strings_buf: [128][]const u8 = undefined;
            var strings_len: usize = 0;

            for (ad) |a| {
                strings_buf[strings_len] = a;
                strings_len += 1;
            }
            strings_buf[strings_len] = m;
            strings_len += 1;

            // Verify synthetic IV using S2V
            var computed_tag: [tag_length]u8 = undefined;
            s2v(&computed_tag, k1.*, strings_buf[0..strings_len]);

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

test "AES-SIV double operation" {
    const AesSivTest = AesSiv(crypto.core.aes.Aes128);

    // Test vector from RFC 5297
    const input = [_]u8{ 0x0e, 0x04, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e };
    const expected = [_]u8{ 0x1c, 0x08, 0x02, 0x04, 0x06, 0x08, 0x0a, 0x0c, 0x0e, 0x10, 0x12, 0x14, 0x16, 0x18, 0x1a, 0x1c };

    const result = AesSivTest.dbl(input);
    try testing.expectEqualSlices(u8, &expected, &result);
}

test "AES-SIV double operation with MSB set" {
    const AesSivTest = AesSiv(crypto.core.aes.Aes128);

    const input = [_]u8{ 0xe0, 0x40, 0x10, 0x20, 0x30, 0x40, 0x50, 0x60, 0x70, 0x80, 0x90, 0xa0, 0xb0, 0xc0, 0xd0, 0xe0 };
    const expected = [_]u8{ 0xc0, 0x80, 0x20, 0x40, 0x60, 0x80, 0xa0, 0xc0, 0xe1, 0x01, 0x21, 0x41, 0x61, 0x81, 0xa1, 0x47 };

    const result = AesSivTest.dbl(input);
    try testing.expectEqualSlices(u8, &expected, &result);
}

test "Aes128Siv - RFC 5297 Test Vector A.1" {
    // Test vector from RFC 5297 Appendix A.1
    const key = [_]u8{
        0xff, 0xfe, 0xfd, 0xfc, 0xfb, 0xfa, 0xf9, 0xf8, 0xf7, 0xf6, 0xf5, 0xf4, 0xf3, 0xf2, 0xf1, 0xf0,
        0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9, 0xfa, 0xfb, 0xfc, 0xfd, 0xfe, 0xff,
    };
    const ad = [_]u8{
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f,
        0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27,
    };
    const plaintext = [_]u8{
        0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xcc, 0xdd, 0xee,
    };

    var ciphertext: [plaintext.len]u8 = undefined;
    var tag: [16]u8 = undefined;

    // Test using vector API for RFC compliance
    const ad_components = [_][]const u8{&ad};
    Aes128Siv.encryptWithAdVector(&ciphertext, &tag, &plaintext, &ad_components, key);

    // Expected values from RFC 5297
    try htest.assertEqual("85632d07c6e8f37f950acd320a2ecc93", &tag);
    try htest.assertEqual("40c02b9690c4dc04daef7f6afe5c", &ciphertext);

    // Test decryption
    var decrypted: [plaintext.len]u8 = undefined;
    try Aes128Siv.decryptWithAdVector(&decrypted, &ciphertext, tag, &ad_components, key);
    try testing.expectEqualSlices(u8, &plaintext, &decrypted);
}

test "Aes128Siv - empty plaintext" {
    const key: [32]u8 = @splat(0x42);
    const plaintext = "";
    const ad = "additional data";

    var ciphertext: [plaintext.len]u8 = undefined;
    var tag: [16]u8 = undefined;

    Aes128Siv.encrypt(&ciphertext, &tag, plaintext, ad, null, key);

    var decrypted: [plaintext.len]u8 = undefined;
    try Aes128Siv.decrypt(&decrypted, &ciphertext, tag, ad, null, key);
}

test "Aes128Siv - with nonce" {
    const key: [32]u8 = @splat(0x69);
    const nonce: [16]u8 = @splat(0x42);
    const plaintext = "Hello, AES-SIV!";
    const ad = "metadata";

    var ciphertext: [plaintext.len]u8 = undefined;
    var tag: [16]u8 = undefined;

    Aes128Siv.encrypt(&ciphertext, &tag, plaintext, ad, &nonce, key);

    var decrypted: [plaintext.len]u8 = undefined;
    try Aes128Siv.decrypt(&decrypted, &ciphertext, tag, ad, &nonce, key);
    try testing.expectEqualSlices(u8, plaintext, &decrypted);
}

test "Aes256Siv - basic functionality" {
    const key: [64]u8 = @splat(0x96);
    const plaintext = "Test message for AES-256-SIV";
    const ad1 = "header";
    const ad2 = "more data";

    var ciphertext: [plaintext.len]u8 = undefined;
    var tag: [16]u8 = undefined;

    // Test with multiple AD components using the vector API
    const ad_components = [_][]const u8{ ad1, ad2 };
    Aes256Siv.encryptWithAdVector(&ciphertext, &tag, plaintext, &ad_components, key);

    var decrypted: [plaintext.len]u8 = undefined;
    try Aes256Siv.decryptWithAdVector(&decrypted, &ciphertext, tag, &ad_components, key);
    try testing.expectEqualSlices(u8, plaintext, &decrypted);
}

test "Aes128Siv - demonstrating optional parameters" {
    const key: [32]u8 = @splat(0x77);

    // Test 1: No AD, no nonce (pure deterministic)
    {
        const plaintext = "Deterministic encryption";
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        Aes128Siv.encrypt(&ciphertext, &tag, plaintext, null, null, key);

        var decrypted: [plaintext.len]u8 = undefined;
        try Aes128Siv.decrypt(&decrypted, &ciphertext, tag, null, null, key);
        try testing.expectEqualSlices(u8, plaintext, &decrypted);
    }

    // Test 2: With AD, no nonce
    {
        const plaintext = "With associated data";
        const ad = "some context";
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        Aes128Siv.encrypt(&ciphertext, &tag, plaintext, ad, null, key);

        var decrypted: [plaintext.len]u8 = undefined;
        try Aes128Siv.decrypt(&decrypted, &ciphertext, tag, ad, null, key);
        try testing.expectEqualSlices(u8, plaintext, &decrypted);
    }

    // Test 3: No AD, with nonce
    {
        const plaintext = "Nonce-based encryption";
        const nonce: [12]u8 = @splat(0x01);
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        Aes128Siv.encrypt(&ciphertext, &tag, plaintext, null, &nonce, key);

        var decrypted: [plaintext.len]u8 = undefined;
        try Aes128Siv.decrypt(&decrypted, &ciphertext, tag, null, &nonce, key);
        try testing.expectEqualSlices(u8, plaintext, &decrypted);
    }

    // Test 4: With both AD and nonce
    {
        const plaintext = "Full featured";
        const ad = "context";
        const nonce: [16]u8 = @splat(0x02);
        var ciphertext: [plaintext.len]u8 = undefined;
        var tag: [16]u8 = undefined;

        Aes128Siv.encrypt(&ciphertext, &tag, plaintext, ad, &nonce, key);

        var decrypted: [plaintext.len]u8 = undefined;
        try Aes128Siv.decrypt(&decrypted, &ciphertext, tag, ad, &nonce, key);
        try testing.expectEqualSlices(u8, plaintext, &decrypted);
    }
}

test "Aes128Siv - authentication failure" {
    const key: [32]u8 = @splat(0x13);
    const plaintext = "Secret message";
    const ad = "";

    var ciphertext: [plaintext.len]u8 = undefined;
    var tag: [16]u8 = undefined;

    Aes128Siv.encrypt(&ciphertext, &tag, plaintext, ad, null, key);

    // Corrupt the tag
    tag[0] ^= 0x01;

    var decrypted: [plaintext.len]u8 = undefined;
    try testing.expectError(error.AuthenticationFailed, Aes128Siv.decrypt(&decrypted, &ciphertext, tag, ad, null, key));
}
