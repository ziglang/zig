// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std");
const crypto = std.crypto;
const debug = std.debug;
const math = std.math;
const mem = std.mem;

const Poly1305 = crypto.onetimeauth.Poly1305;
const Blake2b = crypto.hash.blake2.Blake2b;
const X25519 = crypto.dh.X25519;

const Salsa20NonVecImpl = struct {
    const BlockVec = [16]u32;

    fn initContext(key: [8]u32, d: [4]u32) BlockVec {
        const c = "expand 32-byte k";
        const constant_le = comptime [4]u32{
            mem.readIntLittle(u32, c[0..4]),
            mem.readIntLittle(u32, c[4..8]),
            mem.readIntLittle(u32, c[8..12]),
            mem.readIntLittle(u32, c[12..16]),
        };
        return BlockVec{
            constant_le[0], key[0],         key[1],         key[2],
            key[3],         constant_le[1], d[0],           d[1],
            d[2],           d[3],           constant_le[2], key[4],
            key[5],         key[6],         key[7],         constant_le[3],
        };
    }

    const QuarterRound = struct {
        a: usize,
        b: usize,
        c: usize,
        d: u6,
    };

    inline fn Rp(comptime a: usize, comptime b: usize, comptime c: usize, comptime d: u6) QuarterRound {
        return QuarterRound{
            .a = a,
            .b = b,
            .c = c,
            .d = d,
        };
    }

    inline fn salsa20Core(x: *BlockVec, input: BlockVec) void {
        const arx_steps = comptime [_]QuarterRound{
            Rp(4, 0, 12, 7),   Rp(8, 4, 0, 9),    Rp(12, 8, 4, 13),   Rp(0, 12, 8, 18),
            Rp(9, 5, 1, 7),    Rp(13, 9, 5, 9),   Rp(1, 13, 9, 13),   Rp(5, 1, 13, 18),
            Rp(14, 10, 6, 7),  Rp(2, 14, 10, 9),  Rp(6, 2, 14, 13),   Rp(10, 6, 2, 18),
            Rp(3, 15, 11, 7),  Rp(7, 3, 15, 9),   Rp(11, 7, 3, 13),   Rp(15, 11, 7, 18),
            Rp(1, 0, 3, 7),    Rp(2, 1, 0, 9),    Rp(3, 2, 1, 13),    Rp(0, 3, 2, 18),
            Rp(6, 5, 4, 7),    Rp(7, 6, 5, 9),    Rp(4, 7, 6, 13),    Rp(5, 4, 7, 18),
            Rp(11, 10, 9, 7),  Rp(8, 11, 10, 9),  Rp(9, 8, 11, 13),   Rp(10, 9, 8, 18),
            Rp(12, 15, 14, 7), Rp(13, 12, 15, 9), Rp(14, 13, 12, 13), Rp(15, 14, 13, 18),
        };
        x.* = input;
        var j: usize = 0;
        while (j < 20) : (j += 2) {
            inline for (arx_steps) |r| {
                x[r.a] ^= math.rotl(u32, x[r.b] +% x[r.c], r.d);
            }
        }
    }

    fn hashToBytes(out: *[64]u8, x: BlockVec) void {
        for (x) |w, i| {
            mem.writeIntLittle(u32, out[i * 4 ..][0..4], w);
        }
    }

    fn contextFeedback(x: *BlockVec, ctx: BlockVec) void {
        var i: usize = 0;
        while (i < 16) : (i += 1) {
            x[i] +%= ctx[i];
        }
    }

    fn salsa20Internal(out: []u8, in: []const u8, key: [8]u32, d: [4]u32) void {
        var ctx = initContext(key, d);
        var x: BlockVec = undefined;
        var buf: [64]u8 = undefined;
        var i: usize = 0;
        while (i + 64 <= in.len) : (i += 64) {
            salsa20Core(x[0..], ctx);
            contextFeedback(&x, ctx);
            hashToBytes(buf[0..], x);
            var xout = out[i..];
            const xin = in[i..];
            var j: usize = 0;
            while (j < 64) : (j += 1) {
                xout[j] = xin[j];
            }
            j = 0;
            while (j < 64) : (j += 1) {
                xout[j] ^= buf[j];
            }
            ctx[9] += @boolToInt(@addWithOverflow(u32, ctx[8], 1, &ctx[8]));
        }
        if (i < in.len) {
            salsa20Core(x[0..], ctx);
            contextFeedback(&x, ctx);
            hashToBytes(buf[0..], x);

            var xout = out[i..];
            const xin = in[i..];
            var j: usize = 0;
            while (j < in.len % 64) : (j += 1) {
                xout[j] = xin[j] ^ buf[j];
            }
        }
    }

    fn hsalsa20(input: [16]u8, key: [32]u8) [32]u8 {
        var c: [4]u32 = undefined;
        for (c) |_, i| {
            c[i] = mem.readIntLittle(u32, input[4 * i ..][0..4]);
        }
        const ctx = initContext(keyToWords(key), c);
        var x: BlockVec = undefined;
        salsa20Core(x[0..], ctx);
        var out: [32]u8 = undefined;
        mem.writeIntLittle(u32, out[0..4], x[0]);
        mem.writeIntLittle(u32, out[4..8], x[5]);
        mem.writeIntLittle(u32, out[8..12], x[10]);
        mem.writeIntLittle(u32, out[12..16], x[15]);
        mem.writeIntLittle(u32, out[16..20], x[6]);
        mem.writeIntLittle(u32, out[20..24], x[7]);
        mem.writeIntLittle(u32, out[24..28], x[8]);
        mem.writeIntLittle(u32, out[28..32], x[9]);
        return out;
    }
};

const Salsa20Impl = Salsa20NonVecImpl;

fn keyToWords(key: [32]u8) [8]u32 {
    var k: [8]u32 = undefined;
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        k[i] = mem.readIntLittle(u32, key[i * 4 ..][0..4]);
    }
    return k;
}

fn extend(key: [32]u8, nonce: [24]u8) struct { key: [32]u8, nonce: [8]u8 } {
    return .{
        .key = Salsa20Impl.hsalsa20(nonce[0..16].*, key),
        .nonce = nonce[16..24].*,
    };
}

/// The Salsa20 stream cipher.
pub const Salsa20 = struct {
    /// Nonce length in bytes.
    pub const nonce_length = 8;
    /// Key length in bytes.
    pub const key_length = 32;

    /// Add the output of the Salsa20 stream cipher to `in` and stores the result into `out`.
    /// WARNING: This function doesn't provide authenticated encryption.
    /// Using the AEAD or one of the `box` versions is usually preferred.
    pub fn xor(out: []u8, in: []const u8, counter: u64, key: [key_length]u8, nonce: [nonce_length]u8) void {
        debug.assert(in.len == out.len);

        var d: [4]u32 = undefined;
        d[0] = mem.readIntLittle(u32, nonce[0..4]);
        d[1] = mem.readIntLittle(u32, nonce[4..8]);
        d[2] = @truncate(u32, counter);
        d[3] = @truncate(u32, counter >> 32);
        Salsa20Impl.salsa20Internal(out, in, keyToWords(key), d);
    }
};

/// The XSalsa20 stream cipher.
pub const XSalsa20 = struct {
    /// Nonce length in bytes.
    pub const nonce_length = 24;
    /// Key length in bytes.
    pub const key_length = 32;

    /// Add the output of the XSalsa20 stream cipher to `in` and stores the result into `out`.
    /// WARNING: This function doesn't provide authenticated encryption.
    /// Using the AEAD or one of the `box` versions is usually preferred.
    pub fn xor(out: []u8, in: []const u8, counter: u64, key: [key_length]u8, nonce: [nonce_length]u8) void {
        const extended = extend(key, nonce);
        Salsa20.xor(out, in, counter, extended.key, extended.nonce);
    }
};

/// The XSalsa20 stream cipher, combined with the Poly1305 MAC
pub const XSalsa20Poly1305 = struct {
    /// Authentication tag length in bytes.
    pub const tag_length = Poly1305.mac_length;
    /// Nonce length in bytes.
    pub const nonce_length = XSalsa20.nonce_length;
    /// Key length in bytes.
    pub const key_length = XSalsa20.key_length;

    /// c: ciphertext: output buffer should be of size m.len
    /// tag: authentication tag: output MAC
    /// m: message
    /// ad: Associated Data
    /// npub: public nonce
    /// k: private key
    pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, k: [key_length]u8) void {
        debug.assert(c.len == m.len);
        const extended = extend(k, npub);
        var block0 = [_]u8{0} ** 64;
        const mlen0 = math.min(32, m.len);
        mem.copy(u8, block0[32..][0..mlen0], m[0..mlen0]);
        Salsa20.xor(block0[0..], block0[0..], 0, extended.key, extended.nonce);
        mem.copy(u8, c[0..mlen0], block0[32..][0..mlen0]);
        Salsa20.xor(c[mlen0..], m[mlen0..], 1, extended.key, extended.nonce);
        var mac = Poly1305.init(block0[0..32]);
        mac.update(ad);
        mac.update(c);
        mac.final(tag);
    }

    /// m: message: output buffer should be of size c.len
    /// c: ciphertext
    /// tag: authentication tag
    /// ad: Associated Data
    /// npub: public nonce
    /// k: private key
    pub fn decrypt(m: []u8, c: []const u8, tag: [tag_length]u8, ad: []const u8, npub: [nonce_length]u8, k: [key_length]u8) !void {
        debug.assert(c.len == m.len);
        const extended = extend(k, npub);
        var block0 = [_]u8{0} ** 64;
        const mlen0 = math.min(32, c.len);
        mem.copy(u8, block0[32..][0..mlen0], c[0..mlen0]);
        Salsa20.xor(block0[0..], block0[0..], 0, extended.key, extended.nonce);
        var mac = Poly1305.init(block0[0..32]);
        mac.update(ad);
        mac.update(c);
        var computedTag: [tag_length]u8 = undefined;
        mac.final(&computedTag);
        var acc: u8 = 0;
        for (computedTag) |_, i| {
            acc |= (computedTag[i] ^ tag[i]);
        }
        if (acc != 0) {
            mem.secureZero(u8, &computedTag);
            return error.AuthenticationFailed;
        }
        mem.copy(u8, m[0..mlen0], block0[32..][0..mlen0]);
        Salsa20.xor(m[mlen0..], c[mlen0..], 1, extended.key, extended.nonce);
    }
};

/// NaCl-compatible secretbox API.
///
/// A secretbox contains both an encrypted message and an authentication tag to verify that it hasn't been tampered with.
/// A secret key shared by all the recipients must be already known in order to use this API.
///
/// Nonces are 192-bit large and can safely be chosen with a random number generator.
pub const secretBox = struct {
    /// Key length in bytes.
    pub const key_length = XSalsa20Poly1305.key_length;
    /// Nonce length in bytes.
    pub const nonce_length = XSalsa20Poly1305.nonce_length;
    /// Authentication tag length in bytes.
    pub const tag_length = XSalsa20Poly1305.tag_length;

    /// Encrypt and authenticate `m` using a nonce `npub` and a key `k`.
    /// `c` must be exactly `tag_length` longer than `m`, as it will store both the ciphertext and the authentication tag.
    pub fn seal(c: []u8, m: []const u8, npub: [nonce_length]u8, k: [key_length]u8) void {
        debug.assert(c.len == tag_length + m.len);
        XSalsa20Poly1305.encrypt(c[tag_length..], c[0..tag_length], m, "", npub, k);
    }

    /// Verify and decrypt `c` using a nonce `npub` and a key `k`.
    /// `m` must be exactly `tag_length` smaller than `c`, as `c` includes an authentication tag in addition to the encrypted message.
    pub fn open(m: []u8, c: []const u8, npub: [nonce_length]u8, k: [key_length]u8) !void {
        if (c.len < tag_length) {
            return error.AuthenticationFailed;
        }
        debug.assert(m.len == c.len - tag_length);
        return XSalsa20Poly1305.decrypt(m, c[tag_length..], c[0..tag_length].*, "", npub, k);
    }
};

/// NaCl-compatible box API.
///
/// A secretbox contains both an encrypted message and an authentication tag to verify that it hasn't been tampered with.
/// This construction uses public-key cryptography. A shared secret doesn't have to be known in advance by both parties.
/// Instead, a message is encrypted using a sender's secret key and a recipient's public key,
/// and is decrypted using the recipient's secret key and the sender's public key.
///
/// Nonces are 192-bit large and can safely be chosen with a random number generator.
pub const box = struct {
    /// Public key length in bytes.
    pub const public_length = X25519.public_length;
    /// Secret key length in bytes.
    pub const secret_length = X25519.secret_length;
    /// Shared key length in bytes.
    pub const shared_length = XSalsa20Poly1305.key_length;
    /// Seed (for key pair creation) length in bytes.
    pub const seed_length = X25519.seed_length;
    /// Nonce length in bytes.
    pub const nonce_length = XSalsa20Poly1305.nonce_length;
    /// Authentication tag length in bytes.
    pub const tag_length = XSalsa20Poly1305.tag_length;

    /// A key pair.
    pub const KeyPair = X25519.KeyPair;

    /// Compute a secret suitable for `secretbox` given a recipent's public key and a sender's secret key.
    pub fn createSharedSecret(public_key: [public_length]u8, secret_key: [secret_length]u8) ![shared_length]u8 {
        var p: [32]u8 = undefined;
        try X25519.scalarmult(&p, secret_key, public_key);
        const zero = [_]u8{0} ** 16;
        return Salsa20Impl.hsalsa20(zero, p);
    }

    /// Encrypt and authenticate a message using a recipient's public key `public_key` and a sender's `secret_key`.
    pub fn seal(c: []u8, m: []const u8, npub: [nonce_length]u8, public_key: [public_length]u8, secret_key: [secret_length]u8) !void {
        const shared_key = try createSharedSecret(public_key, secret_key);
        return secretBox.seal(c, m, npub, shared_key);
    }

    /// Verify and decrypt a message using a recipient's secret key `public_key` and a sender's `public_key`.
    pub fn open(m: []u8, c: []const u8, npub: [nonce_length]u8, public_key: [public_length]u8, secret_key: [secret_length]u8) !void {
        const shared_key = try createSharedSecret(public_key, secret_key);
        return secretBox.open(m, c, npub, shared_key);
    }
};

/// libsodium-compatible sealed boxes
///
/// Sealed boxes are designed to anonymously send messages to a recipient given their public key.
/// Only the recipient can decrypt these messages, using their private key.
/// While the recipient can verify the integrity of the message, it cannot verify the identity of the sender.
///
/// A message is encrypted using an ephemeral key pair, whose secret part is destroyed right after the encryption process.
pub const sealedBox = struct {
    pub const public_length = box.public_length;
    pub const secret_length = box.secret_length;
    pub const seed_length = box.seed_length;
    pub const seal_length = box.public_length + box.tag_length;

    /// A key pair.
    pub const KeyPair = box.KeyPair;

    fn createNonce(pk1: [public_length]u8, pk2: [public_length]u8) [box.nonce_length]u8 {
        var hasher = Blake2b(box.nonce_length * 8).init(.{});
        hasher.update(&pk1);
        hasher.update(&pk2);
        var nonce: [box.nonce_length]u8 = undefined;
        hasher.final(&nonce);
        return nonce;
    }

    /// Encrypt a message `m` for a recipient whose public key is `public_key`.
    /// `c` must be `seal_length` bytes larger than `m`, so that the required metadata can be added.
    pub fn seal(c: []u8, m: []const u8, public_key: [public_length]u8) !void {
        debug.assert(c.len == m.len + seal_length);
        var ekp = try KeyPair.create(null);
        const nonce = createNonce(ekp.public_key, public_key);
        mem.copy(u8, c[0..public_length], ekp.public_key[0..]);
        try box.seal(c[box.public_length..], m, nonce, public_key, ekp.secret_key);
        mem.secureZero(u8, ekp.secret_key[0..]);
    }

    /// Decrypt a message using a key pair.
    /// `m` must be exactly `seal_length` bytes smaller than `c`, as `c` also includes metadata.
    pub fn open(m: []u8, c: []const u8, keypair: KeyPair) !void {
        if (c.len < seal_length) {
            return error.AuthenticationFailed;
        }
        const epk = c[0..public_length];
        const nonce = createNonce(epk.*, keypair.public_key);
        return box.open(m, c[public_length..], nonce, epk.*, keypair.secret_key);
    }
};

test "xsalsa20poly1305" {
    var msg: [100]u8 = undefined;
    var msg2: [msg.len]u8 = undefined;
    var c: [msg.len]u8 = undefined;
    var key: [XSalsa20Poly1305.key_length]u8 = undefined;
    var nonce: [XSalsa20Poly1305.nonce_length]u8 = undefined;
    var tag: [XSalsa20Poly1305.tag_length]u8 = undefined;
    try crypto.randomBytes(&msg);
    try crypto.randomBytes(&key);
    try crypto.randomBytes(&nonce);

    XSalsa20Poly1305.encrypt(c[0..], &tag, msg[0..], "ad", nonce, key);
    try XSalsa20Poly1305.decrypt(msg2[0..], c[0..], tag, "ad", nonce, key);
}

test "xsalsa20poly1305 secretbox" {
    var msg: [100]u8 = undefined;
    var msg2: [msg.len]u8 = undefined;
    var key: [XSalsa20Poly1305.key_length]u8 = undefined;
    var nonce: [box.nonce_length]u8 = undefined;
    var boxed: [msg.len + box.tag_length]u8 = undefined;
    try crypto.randomBytes(&msg);
    try crypto.randomBytes(&key);
    try crypto.randomBytes(&nonce);

    secretBox.seal(boxed[0..], msg[0..], nonce, key);
    try secretBox.open(msg2[0..], boxed[0..], nonce, key);
}

test "xsalsa20poly1305 box" {
    var msg: [100]u8 = undefined;
    var msg2: [msg.len]u8 = undefined;
    var nonce: [box.nonce_length]u8 = undefined;
    var boxed: [msg.len + box.tag_length]u8 = undefined;
    try crypto.randomBytes(&msg);
    try crypto.randomBytes(&nonce);

    var kp1 = try box.KeyPair.create(null);
    var kp2 = try box.KeyPair.create(null);
    try box.seal(boxed[0..], msg[0..], nonce, kp1.public_key, kp2.secret_key);
    try box.open(msg2[0..], boxed[0..], nonce, kp2.public_key, kp1.secret_key);
}

test "xsalsa20poly1305 sealedbox" {
    var msg: [100]u8 = undefined;
    var msg2: [msg.len]u8 = undefined;
    var boxed: [msg.len + sealedBox.seal_length]u8 = undefined;
    try crypto.randomBytes(&msg);

    var kp = try box.KeyPair.create(null);
    try sealedBox.seal(boxed[0..], msg[0..], kp.public_key);
    try sealedBox.open(msg2[0..], boxed[0..], kp);
}
