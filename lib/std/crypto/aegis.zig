// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const AesBlock = std.crypto.core.aes.Block;
const AuthenticationError = std.crypto.errors.AuthenticationError;

const State128L = struct {
    blocks: [8]AesBlock,

    fn init(key: [16]u8, nonce: [16]u8) State128L {
        const c1 = AesBlock.fromBytes(&[16]u8{ 0xdb, 0x3d, 0x18, 0x55, 0x6d, 0xc2, 0x2f, 0xf1, 0x20, 0x11, 0x31, 0x42, 0x73, 0xb5, 0x28, 0xdd });
        const c2 = AesBlock.fromBytes(&[16]u8{ 0x0, 0x1, 0x01, 0x02, 0x03, 0x05, 0x08, 0x0d, 0x15, 0x22, 0x37, 0x59, 0x90, 0xe9, 0x79, 0x62 });
        const key_block = AesBlock.fromBytes(&key);
        const nonce_block = AesBlock.fromBytes(&nonce);
        const blocks = [8]AesBlock{
            key_block.xorBlocks(nonce_block),
            c1,
            c2,
            c1,
            key_block.xorBlocks(nonce_block),
            key_block.xorBlocks(c2),
            key_block.xorBlocks(c1),
            key_block.xorBlocks(c2),
        };
        var state = State128L{ .blocks = blocks };
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            state.update(nonce_block, key_block);
        }
        return state;
    }

    fn update(state: *State128L, d1: AesBlock, d2: AesBlock) callconv(.Inline) void {
        const blocks = &state.blocks;
        const tmp = blocks[7];
        comptime var i: usize = 7;
        inline while (i > 0) : (i -= 1) {
            blocks[i] = blocks[i - 1].encrypt(blocks[i]);
        }
        blocks[0] = tmp.encrypt(blocks[0]);
        blocks[0] = blocks[0].xorBlocks(d1);
        blocks[4] = blocks[4].xorBlocks(d2);
    }

    fn enc(state: *State128L, dst: *[32]u8, src: *const [32]u8) void {
        const blocks = &state.blocks;
        const msg0 = AesBlock.fromBytes(src[0..16]);
        const msg1 = AesBlock.fromBytes(src[16..32]);
        var tmp0 = msg0.xorBlocks(blocks[6]).xorBlocks(blocks[1]);
        var tmp1 = msg1.xorBlocks(blocks[2]).xorBlocks(blocks[5]);
        tmp0 = tmp0.xorBlocks(blocks[2].andBlocks(blocks[3]));
        tmp1 = tmp1.xorBlocks(blocks[6].andBlocks(blocks[7]));
        dst[0..16].* = tmp0.toBytes();
        dst[16..32].* = tmp1.toBytes();
        state.update(msg0, msg1);
    }

    fn dec(state: *State128L, dst: *[32]u8, src: *const [32]u8) void {
        const blocks = &state.blocks;
        var msg0 = AesBlock.fromBytes(src[0..16]).xorBlocks(blocks[6]).xorBlocks(blocks[1]);
        var msg1 = AesBlock.fromBytes(src[16..32]).xorBlocks(blocks[2]).xorBlocks(blocks[5]);
        msg0 = msg0.xorBlocks(blocks[2].andBlocks(blocks[3]));
        msg1 = msg1.xorBlocks(blocks[6].andBlocks(blocks[7]));
        dst[0..16].* = msg0.toBytes();
        dst[16..32].* = msg1.toBytes();
        state.update(msg0, msg1);
    }

    fn mac(state: *State128L, adlen: usize, mlen: usize) [16]u8 {
        const blocks = &state.blocks;
        var sizes: [16]u8 = undefined;
        mem.writeIntLittle(u64, sizes[0..8], adlen * 8);
        mem.writeIntLittle(u64, sizes[8..16], mlen * 8);
        const tmp = AesBlock.fromBytes(&sizes).xorBlocks(blocks[2]);
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            state.update(tmp, tmp);
        }
        return blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]).xorBlocks(blocks[4])
            .xorBlocks(blocks[5]).xorBlocks(blocks[6]).toBytes();
    }
};

/// AEGIS is a very fast authenticated encryption system built on top of the core AES function.
///
/// The 128L variant of AEGIS has a 128 bit key, a 128 bit nonce, and processes 256 bit message blocks.
/// It was designed to fully exploit the parallelism and built-in AES support of recent Intel and ARM CPUs.
///
/// https://competitions.cr.yp.to/round3/aegisv11.pdf
pub const Aegis128L = struct {
    pub const tag_length = 16;
    pub const nonce_length = 16;
    pub const key_length = 16;

    /// c: ciphertext: output buffer should be of size m.len
    /// tag: authentication tag: output MAC
    /// m: message
    /// ad: Associated Data
    /// npub: public nonce
    /// k: private key
    pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) void {
        assert(c.len == m.len);
        var state = State128L.init(key, npub);
        var src: [32]u8 align(16) = undefined;
        var dst: [32]u8 align(16) = undefined;
        var i: usize = 0;
        while (i + 32 <= ad.len) : (i += 32) {
            state.enc(&dst, ad[i..][0..32]);
        }
        if (ad.len % 32 != 0) {
            mem.set(u8, src[0..], 0);
            mem.copy(u8, src[0 .. ad.len % 32], ad[i .. i + ad.len % 32]);
            state.enc(&dst, &src);
        }
        i = 0;
        while (i + 32 <= m.len) : (i += 32) {
            state.enc(c[i..][0..32], m[i..][0..32]);
        }
        if (m.len % 32 != 0) {
            mem.set(u8, src[0..], 0);
            mem.copy(u8, src[0 .. m.len % 32], m[i .. i + m.len % 32]);
            state.enc(&dst, &src);
            mem.copy(u8, c[i .. i + m.len % 32], dst[0 .. m.len % 32]);
        }
        tag.* = state.mac(ad.len, m.len);
    }

    /// m: message: output buffer should be of size c.len
    /// c: ciphertext
    /// tag: authentication tag
    /// ad: Associated Data
    /// npub: public nonce
    /// k: private key
    pub fn decrypt(m: []u8, c: []const u8, tag: [tag_length]u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) AuthenticationError!void {
        assert(c.len == m.len);
        var state = State128L.init(key, npub);
        var src: [32]u8 align(16) = undefined;
        var dst: [32]u8 align(16) = undefined;
        var i: usize = 0;
        while (i + 32 <= ad.len) : (i += 32) {
            state.enc(&dst, ad[i..][0..32]);
        }
        if (ad.len % 32 != 0) {
            mem.set(u8, src[0..], 0);
            mem.copy(u8, src[0 .. ad.len % 32], ad[i .. i + ad.len % 32]);
            state.enc(&dst, &src);
        }
        i = 0;
        while (i + 32 <= m.len) : (i += 32) {
            state.dec(m[i..][0..32], c[i..][0..32]);
        }
        if (m.len % 32 != 0) {
            mem.set(u8, src[0..], 0);
            mem.copy(u8, src[0 .. m.len % 32], c[i .. i + m.len % 32]);
            state.dec(&dst, &src);
            mem.copy(u8, m[i .. i + m.len % 32], dst[0 .. m.len % 32]);
            mem.set(u8, dst[0 .. m.len % 32], 0);
            const blocks = &state.blocks;
            blocks[0] = blocks[0].xorBlocks(AesBlock.fromBytes(dst[0..16]));
            blocks[4] = blocks[4].xorBlocks(AesBlock.fromBytes(dst[16..32]));
        }
        const computed_tag = state.mac(ad.len, m.len);
        var acc: u8 = 0;
        for (computed_tag) |_, j| {
            acc |= (computed_tag[j] ^ tag[j]);
        }
        if (acc != 0) {
            mem.set(u8, m, 0xaa);
            return error.AuthenticationFailed;
        }
    }
};

const State256 = struct {
    blocks: [6]AesBlock,

    fn init(key: [32]u8, nonce: [32]u8) State256 {
        const c1 = AesBlock.fromBytes(&[16]u8{ 0xdb, 0x3d, 0x18, 0x55, 0x6d, 0xc2, 0x2f, 0xf1, 0x20, 0x11, 0x31, 0x42, 0x73, 0xb5, 0x28, 0xdd });
        const c2 = AesBlock.fromBytes(&[16]u8{ 0x0, 0x1, 0x01, 0x02, 0x03, 0x05, 0x08, 0x0d, 0x15, 0x22, 0x37, 0x59, 0x90, 0xe9, 0x79, 0x62 });
        const key_block1 = AesBlock.fromBytes(key[0..16]);
        const key_block2 = AesBlock.fromBytes(key[16..32]);
        const nonce_block1 = AesBlock.fromBytes(nonce[0..16]);
        const nonce_block2 = AesBlock.fromBytes(nonce[16..32]);
        const kxn1 = key_block1.xorBlocks(nonce_block1);
        const kxn2 = key_block2.xorBlocks(nonce_block2);
        const blocks = [6]AesBlock{
            kxn1,
            kxn2,
            c1,
            c2,
            key_block1.xorBlocks(c2),
            key_block2.xorBlocks(c1),
        };
        var state = State256{ .blocks = blocks };
        var i: usize = 0;
        while (i < 4) : (i += 1) {
            state.update(key_block1);
            state.update(key_block2);
            state.update(kxn1);
            state.update(kxn2);
        }
        return state;
    }

    fn update(state: *State256, d: AesBlock) callconv(.Inline) void {
        const blocks = &state.blocks;
        const tmp = blocks[5].encrypt(blocks[0]);
        comptime var i: usize = 5;
        inline while (i > 0) : (i -= 1) {
            blocks[i] = blocks[i - 1].encrypt(blocks[i]);
        }
        blocks[0] = tmp.xorBlocks(d);
    }

    fn enc(state: *State256, dst: *[16]u8, src: *const [16]u8) void {
        const blocks = &state.blocks;
        const msg = AesBlock.fromBytes(src);
        var tmp = msg.xorBlocks(blocks[5]).xorBlocks(blocks[4]).xorBlocks(blocks[1]);
        tmp = tmp.xorBlocks(blocks[2].andBlocks(blocks[3]));
        dst.* = tmp.toBytes();
        state.update(msg);
    }

    fn dec(state: *State256, dst: *[16]u8, src: *const [16]u8) void {
        const blocks = &state.blocks;
        var msg = AesBlock.fromBytes(src).xorBlocks(blocks[5]).xorBlocks(blocks[4]).xorBlocks(blocks[1]);
        msg = msg.xorBlocks(blocks[2].andBlocks(blocks[3]));
        dst.* = msg.toBytes();
        state.update(msg);
    }

    fn mac(state: *State256, adlen: usize, mlen: usize) [16]u8 {
        const blocks = &state.blocks;
        var sizes: [16]u8 = undefined;
        mem.writeIntLittle(u64, sizes[0..8], adlen * 8);
        mem.writeIntLittle(u64, sizes[8..16], mlen * 8);
        const tmp = AesBlock.fromBytes(&sizes).xorBlocks(blocks[3]);
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            state.update(tmp);
        }
        return blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]).xorBlocks(blocks[4])
            .xorBlocks(blocks[5]).toBytes();
    }
};

/// AEGIS is a very fast authenticated encryption system built on top of the core AES function.
///
/// The 256 bit variant of AEGIS has a 256 bit key, a 256 bit nonce, and processes 128 bit message blocks.
///
/// https://competitions.cr.yp.to/round3/aegisv11.pdf
pub const Aegis256 = struct {
    pub const tag_length = 16;
    pub const nonce_length = 32;
    pub const key_length = 32;

    /// c: ciphertext: output buffer should be of size m.len
    /// tag: authentication tag: output MAC
    /// m: message
    /// ad: Associated Data
    /// npub: public nonce
    /// k: private key
    pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) void {
        assert(c.len == m.len);
        var state = State256.init(key, npub);
        var src: [16]u8 align(16) = undefined;
        var dst: [16]u8 align(16) = undefined;
        var i: usize = 0;
        while (i + 16 <= ad.len) : (i += 16) {
            state.enc(&dst, ad[i..][0..16]);
        }
        if (ad.len % 16 != 0) {
            mem.set(u8, src[0..], 0);
            mem.copy(u8, src[0 .. ad.len % 16], ad[i .. i + ad.len % 16]);
            state.enc(&dst, &src);
        }
        i = 0;
        while (i + 16 <= m.len) : (i += 16) {
            state.enc(c[i..][0..16], m[i..][0..16]);
        }
        if (m.len % 16 != 0) {
            mem.set(u8, src[0..], 0);
            mem.copy(u8, src[0 .. m.len % 16], m[i .. i + m.len % 16]);
            state.enc(&dst, &src);
            mem.copy(u8, c[i .. i + m.len % 16], dst[0 .. m.len % 16]);
        }
        tag.* = state.mac(ad.len, m.len);
    }

    /// m: message: output buffer should be of size c.len
    /// c: ciphertext
    /// tag: authentication tag
    /// ad: Associated Data
    /// npub: public nonce
    /// k: private key
    pub fn decrypt(m: []u8, c: []const u8, tag: [tag_length]u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) AuthenticationError!void {
        assert(c.len == m.len);
        var state = State256.init(key, npub);
        var src: [16]u8 align(16) = undefined;
        var dst: [16]u8 align(16) = undefined;
        var i: usize = 0;
        while (i + 16 <= ad.len) : (i += 16) {
            state.enc(&dst, ad[i..][0..16]);
        }
        if (ad.len % 16 != 0) {
            mem.set(u8, src[0..], 0);
            mem.copy(u8, src[0 .. ad.len % 16], ad[i .. i + ad.len % 16]);
            state.enc(&dst, &src);
        }
        i = 0;
        while (i + 16 <= m.len) : (i += 16) {
            state.dec(m[i..][0..16], c[i..][0..16]);
        }
        if (m.len % 16 != 0) {
            mem.set(u8, src[0..], 0);
            mem.copy(u8, src[0 .. m.len % 16], c[i .. i + m.len % 16]);
            state.dec(&dst, &src);
            mem.copy(u8, m[i .. i + m.len % 16], dst[0 .. m.len % 16]);
            mem.set(u8, dst[0 .. m.len % 16], 0);
            const blocks = &state.blocks;
            blocks[0] = blocks[0].xorBlocks(AesBlock.fromBytes(&dst));
        }
        const computed_tag = state.mac(ad.len, m.len);
        var acc: u8 = 0;
        for (computed_tag) |_, j| {
            acc |= (computed_tag[j] ^ tag[j]);
        }
        if (acc != 0) {
            mem.set(u8, m, 0xaa);
            return error.AuthenticationFailed;
        }
    }
};

const htest = @import("test.zig");
const testing = std.testing;

test "Aegis128L test vector 1" {
    const key: [Aegis128L.key_length]u8 = [_]u8{ 0x10, 0x01 } ++ [_]u8{0x00} ** 14;
    const nonce: [Aegis128L.nonce_length]u8 = [_]u8{ 0x10, 0x00, 0x02 } ++ [_]u8{0x00} ** 13;
    const ad = [8]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07 };
    const m = [32]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f };
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aegis128L.tag_length]u8 = undefined;

    Aegis128L.encrypt(&c, &tag, &m, &ad, nonce, key);
    try Aegis128L.decrypt(&m2, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &m, &m2);

    try htest.assertEqual("79d94593d8c2119d7e8fd9b8fc77845c5c077a05b2528b6ac54b563aed8efe84", &c);
    try htest.assertEqual("cc6f3372f6aa1bb82388d695c3962d9a", &tag);

    c[0] +%= 1;
    try testing.expectError(error.AuthenticationFailed, Aegis128L.decrypt(&m2, &c, tag, &ad, nonce, key));
    c[0] -%= 1;
    tag[0] +%= 1;
    try testing.expectError(error.AuthenticationFailed, Aegis128L.decrypt(&m2, &c, tag, &ad, nonce, key));
}

test "Aegis128L test vector 2" {
    const key: [Aegis128L.key_length]u8 = [_]u8{0x00} ** 16;
    const nonce: [Aegis128L.nonce_length]u8 = [_]u8{0x00} ** 16;
    const ad = [_]u8{};
    const m = [_]u8{0x00} ** 16;
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aegis128L.tag_length]u8 = undefined;

    Aegis128L.encrypt(&c, &tag, &m, &ad, nonce, key);
    try Aegis128L.decrypt(&m2, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &m, &m2);

    try htest.assertEqual("41de9000a7b5e40e2d68bb64d99ebb19", &c);
    try htest.assertEqual("f4d997cc9b94227ada4fe4165422b1c8", &tag);
}

test "Aegis128L test vector 3" {
    const key: [Aegis128L.key_length]u8 = [_]u8{0x00} ** 16;
    const nonce: [Aegis128L.nonce_length]u8 = [_]u8{0x00} ** 16;
    const ad = [_]u8{};
    const m = [_]u8{};
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aegis128L.tag_length]u8 = undefined;

    Aegis128L.encrypt(&c, &tag, &m, &ad, nonce, key);
    try Aegis128L.decrypt(&m2, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &m, &m2);

    try htest.assertEqual("83cc600dc4e3e7e62d4055826174f149", &tag);
}

test "Aegis256 test vector 1" {
    const key: [Aegis256.key_length]u8 = [_]u8{ 0x10, 0x01 } ++ [_]u8{0x00} ** 30;
    const nonce: [Aegis256.nonce_length]u8 = [_]u8{ 0x10, 0x00, 0x02 } ++ [_]u8{0x00} ** 29;
    const ad = [8]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07 };
    const m = [32]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f };
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aegis256.tag_length]u8 = undefined;

    Aegis256.encrypt(&c, &tag, &m, &ad, nonce, key);
    try Aegis256.decrypt(&m2, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &m, &m2);

    try htest.assertEqual("f373079ed84b2709faee373584585d60accd191db310ef5d8b11833df9dec711", &c);
    try htest.assertEqual("8d86f91ee606e9ff26a01b64ccbdd91d", &tag);

    c[0] +%= 1;
    try testing.expectError(error.AuthenticationFailed, Aegis256.decrypt(&m2, &c, tag, &ad, nonce, key));
    c[0] -%= 1;
    tag[0] +%= 1;
    try testing.expectError(error.AuthenticationFailed, Aegis256.decrypt(&m2, &c, tag, &ad, nonce, key));
}

test "Aegis256 test vector 2" {
    const key: [Aegis256.key_length]u8 = [_]u8{0x00} ** 32;
    const nonce: [Aegis256.nonce_length]u8 = [_]u8{0x00} ** 32;
    const ad = [_]u8{};
    const m = [_]u8{0x00} ** 16;
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aegis256.tag_length]u8 = undefined;

    Aegis256.encrypt(&c, &tag, &m, &ad, nonce, key);
    try Aegis256.decrypt(&m2, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &m, &m2);

    try htest.assertEqual("b98f03a947807713d75a4fff9fc277a6", &c);
    try htest.assertEqual("478f3b50dc478ef7d5cf2d0f7cc13180", &tag);
}

test "Aegis256 test vector 3" {
    const key: [Aegis256.key_length]u8 = [_]u8{0x00} ** 32;
    const nonce: [Aegis256.nonce_length]u8 = [_]u8{0x00} ** 32;
    const ad = [_]u8{};
    const m = [_]u8{};
    var c: [m.len]u8 = undefined;
    var m2: [m.len]u8 = undefined;
    var tag: [Aegis256.tag_length]u8 = undefined;

    Aegis256.encrypt(&c, &tag, &m, &ad, nonce, key);
    try Aegis256.decrypt(&m2, &c, tag, &ad, nonce, key);
    try testing.expectEqualSlices(u8, &m, &m2);

    try htest.assertEqual("f7a0878f68bd083e8065354071fc27c3", &tag);
}
