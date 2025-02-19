//! AEGIS is a very fast authenticated encryption system built on top of the core AES function.
//!
//! The AEGIS-128* variants have a 128 bit key and a 128 bit nonce.
//! The AEGIS-256* variants have a 256 bit key and a 256 bit nonce.
//! All of them can compute 128 and 256 bit authentication tags.
//!
//! The AEGIS cipher family offers performance that significantly exceeds that of AES-GCM with
//! hardware support for parallelizable AES block encryption.
//!
//! On high-end Intel CPUs with AVX-512 support, AEGIS-128X4 and AEGIS-256X4 are the fastest options.
//! On other modern server, desktop and mobile CPUs, AEGIS-128X2 and AEGIS-256X2 are usually the fastest options.
//! AEGIS-128L and AEGIS-256 perform well on a broad range of platforms, including WebAssembly.
//!
//! Unlike with AES-GCM, nonces can be safely chosen at random with no practical limit when using AEGIS-256*.
//! AEGIS-128* also allows for more messages to be safely encrypted when using random nonces.
//!
//! Unless the associated data can be fully controled by an adversary, AEGIS is believed to be key-committing,
//! making it a safer choice than most other AEADs when the key has low entropy, or can be controlled by an attacker.
//!
//! Finally, leaking the state does not leak the key.
//!
//! https://datatracker.ietf.org/doc/draft-irtf-cfrg-aegis-aead/

const std = @import("std");
const crypto = std.crypto;
const mem = std.mem;
const assert = std.debug.assert;
const AuthenticationError = crypto.errors.AuthenticationError;

/// AEGIS-128X4 with a 128 bit tag
pub const Aegis128X4 = Aegis128XGeneric(4, 128);
/// AEGIS-128X2 with a 128 bit tag
pub const Aegis128X2 = Aegis128XGeneric(2, 128);
/// AEGIS-128L with a 128 bit tag
pub const Aegis128L = Aegis128XGeneric(1, 128);

/// AEGIS-256X4 with a 128 bit tag
pub const Aegis256X4 = Aegis256XGeneric(4, 128);
/// AEGIS-256X2 with a 128 bit tag
pub const Aegis256X2 = Aegis256XGeneric(2, 128);
/// AEGIS-256 with a 128 bit tag
pub const Aegis256 = Aegis256XGeneric(1, 128);

/// AEGIS-128X4 with a 256 bit tag
pub const Aegis128X4_256 = Aegis128XGeneric(4, 256);
/// AEGIS-128X2 with a 256 bit tag
pub const Aegis128X2_256 = Aegis128XGeneric(2, 256);
/// AEGIS-128L with a 256 bit tag
pub const Aegis128L_256 = Aegis128XGeneric(1, 256);

/// AEGIS-256X4 with a 256 bit tag
pub const Aegis256X4_256 = Aegis256XGeneric(4, 256);
/// AEGIS-256X2 with a 256 bit tag
pub const Aegis256X2_256 = Aegis256XGeneric(2, 256);
/// AEGIS-256 with a 256 bit tag
pub const Aegis256_256 = Aegis256XGeneric(1, 256);

fn State128X(comptime degree: u7) type {
    return struct {
        const AesBlockVec = crypto.core.aes.BlockVec(degree);
        const State = @This();

        blocks: [8]AesBlockVec,

        const aes_block_length = AesBlockVec.block_length;
        const rate = aes_block_length * 2;
        const alignment = AesBlockVec.native_word_size;

        fn init(key: [16]u8, nonce: [16]u8) State {
            const c1 = AesBlockVec.fromBytes(&[16]u8{ 0xdb, 0x3d, 0x18, 0x55, 0x6d, 0xc2, 0x2f, 0xf1, 0x20, 0x11, 0x31, 0x42, 0x73, 0xb5, 0x28, 0xdd } ** degree);
            const c2 = AesBlockVec.fromBytes(&[16]u8{ 0x0, 0x1, 0x01, 0x02, 0x03, 0x05, 0x08, 0x0d, 0x15, 0x22, 0x37, 0x59, 0x90, 0xe9, 0x79, 0x62 } ** degree);
            const key_block = AesBlockVec.fromBytes(&(key ** degree));
            const nonce_block = AesBlockVec.fromBytes(&(nonce ** degree));
            const blocks = [8]AesBlockVec{
                key_block.xorBlocks(nonce_block),
                c1,
                c2,
                c1,
                key_block.xorBlocks(nonce_block),
                key_block.xorBlocks(c2),
                key_block.xorBlocks(c1),
                key_block.xorBlocks(c2),
            };
            var state = State{ .blocks = blocks };
            if (degree > 1) {
                const context_block = ctx: {
                    var contexts_bytes = [_]u8{0} ** aes_block_length;
                    for (0..degree) |i| {
                        contexts_bytes[i * 16] = @intCast(i);
                        contexts_bytes[i * 16 + 1] = @intCast(degree - 1);
                    }
                    break :ctx AesBlockVec.fromBytes(&contexts_bytes);
                };
                for (0..10) |_| {
                    state.blocks[3] = state.blocks[3].xorBlocks(context_block);
                    state.blocks[7] = state.blocks[7].xorBlocks(context_block);
                    state.update(nonce_block, key_block);
                }
            } else {
                for (0..10) |_| {
                    state.update(nonce_block, key_block);
                }
            }
            return state;
        }

        inline fn update(state: *State, d1: AesBlockVec, d2: AesBlockVec) void {
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

        fn absorb(state: *State, src: *const [rate]u8) void {
            const msg0 = AesBlockVec.fromBytes(src[0..aes_block_length]);
            const msg1 = AesBlockVec.fromBytes(src[aes_block_length..rate]);
            state.update(msg0, msg1);
        }

        fn enc(state: *State, dst: *[rate]u8, src: *const [rate]u8) void {
            const blocks = &state.blocks;
            const msg0 = AesBlockVec.fromBytes(src[0..aes_block_length]);
            const msg1 = AesBlockVec.fromBytes(src[aes_block_length..rate]);
            var tmp0 = msg0.xorBlocks(blocks[6]).xorBlocks(blocks[1]);
            var tmp1 = msg1.xorBlocks(blocks[2]).xorBlocks(blocks[5]);
            tmp0 = tmp0.xorBlocks(blocks[2].andBlocks(blocks[3]));
            tmp1 = tmp1.xorBlocks(blocks[6].andBlocks(blocks[7]));
            dst[0..aes_block_length].* = tmp0.toBytes();
            dst[aes_block_length..rate].* = tmp1.toBytes();
            state.update(msg0, msg1);
        }

        fn dec(state: *State, dst: *[rate]u8, src: *const [rate]u8) void {
            const blocks = &state.blocks;
            var msg0 = AesBlockVec.fromBytes(src[0..aes_block_length]).xorBlocks(blocks[6]).xorBlocks(blocks[1]);
            var msg1 = AesBlockVec.fromBytes(src[aes_block_length..rate]).xorBlocks(blocks[2]).xorBlocks(blocks[5]);
            msg0 = msg0.xorBlocks(blocks[2].andBlocks(blocks[3]));
            msg1 = msg1.xorBlocks(blocks[6].andBlocks(blocks[7]));
            dst[0..aes_block_length].* = msg0.toBytes();
            dst[aes_block_length..rate].* = msg1.toBytes();
            state.update(msg0, msg1);
        }

        fn decLast(state: *State, dst: []u8, src: []const u8) void {
            const blocks = &state.blocks;
            const z0 = blocks[6].xorBlocks(blocks[1]).xorBlocks(blocks[2].andBlocks(blocks[3]));
            const z1 = blocks[2].xorBlocks(blocks[5]).xorBlocks(blocks[6].andBlocks(blocks[7]));
            var pad = [_]u8{0} ** rate;
            pad[0..aes_block_length].* = z0.toBytes();
            pad[aes_block_length..].* = z1.toBytes();
            for (pad[0..src.len], src) |*p, x| p.* ^= x;
            @memcpy(dst, pad[0..src.len]);
            @memset(pad[src.len..], 0);
            const msg0 = AesBlockVec.fromBytes(pad[0..aes_block_length]);
            const msg1 = AesBlockVec.fromBytes(pad[aes_block_length..rate]);
            state.update(msg0, msg1);
        }

        fn finalize(state: *State, comptime tag_bits: u9, adlen: usize, mlen: usize) [tag_bits / 8]u8 {
            const blocks = &state.blocks;
            var sizes: [aes_block_length]u8 = undefined;
            mem.writeInt(u64, sizes[0..8], @as(u64, adlen) * 8, .little);
            mem.writeInt(u64, sizes[8..16], @as(u64, mlen) * 8, .little);
            for (1..degree) |i| {
                @memcpy(sizes[i * 16 ..][0..16], sizes[0..16]);
            }
            const tmp = AesBlockVec.fromBytes(&sizes).xorBlocks(blocks[2]);
            for (0..7) |_| {
                state.update(tmp, tmp);
            }
            switch (tag_bits) {
                128 => {
                    var tag_multi = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]).xorBlocks(blocks[4]).xorBlocks(blocks[5]).xorBlocks(blocks[6]).toBytes();
                    var tag = tag_multi[0..16].*;
                    @memcpy(tag[0..], tag_multi[0..16]);
                    for (1..degree) |d| {
                        for (0..16) |i| {
                            tag[i] ^= tag_multi[d * 16 + i];
                        }
                    }
                    return tag;
                },
                256 => {
                    const tag_multi_1 = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]).toBytes();
                    const tag_multi_2 = blocks[4].xorBlocks(blocks[5]).xorBlocks(blocks[6]).xorBlocks(blocks[7]).toBytes();
                    var tag = tag_multi_1[0..16].* ++ tag_multi_2[0..16].*;
                    for (1..degree) |d| {
                        for (0..16) |i| {
                            tag[i] ^= tag_multi_1[d * 16 + i];
                            tag[i + 16] ^= tag_multi_2[d * 16 + i];
                        }
                    }
                    return tag;
                },
                else => unreachable,
            }
        }

        fn finalizeMac(state: *State, comptime tag_bits: u9, datalen: usize) [tag_bits / 8]u8 {
            const blocks = &state.blocks;
            var sizes: [aes_block_length]u8 = undefined;
            mem.writeInt(u64, sizes[0..8], @as(u64, datalen) * 8, .little);
            mem.writeInt(u64, sizes[8..16], tag_bits, .little);
            for (1..degree) |i| {
                @memcpy(sizes[i * 16 ..][0..16], sizes[0..16]);
            }
            var t = blocks[2].xorBlocks(AesBlockVec.fromBytes(&sizes));
            for (0..7) |_| {
                state.update(t, t);
            }
            if (degree > 1) {
                var v = [_]u8{0} ** rate;
                switch (tag_bits) {
                    128 => {
                        const tags = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]).xorBlocks(blocks[4]).xorBlocks(blocks[5]).xorBlocks(blocks[6]).toBytes();
                        for (0..degree / 2) |d| {
                            v[0..16].* = tags[d * 32 ..][0..16].*;
                            v[rate / 2 ..][0..16].* = tags[d * 32 ..][16..32].*;
                            state.absorb(&v);
                        }
                    },
                    256 => {
                        const tags_0 = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]).toBytes();
                        const tags_1 = blocks[4].xorBlocks(blocks[5]).xorBlocks(blocks[6]).xorBlocks(blocks[7]).toBytes();
                        for (1..degree) |d| {
                            v[0..16].* = tags_0[d * 16 ..][0..16].*;
                            v[rate / 2 ..][0..16].* = tags_1[d * 16 ..][0..16].*;
                            state.absorb(&v);
                        }
                    },
                    else => unreachable,
                }
                mem.writeInt(u64, sizes[0..8], degree, .little);
                mem.writeInt(u64, sizes[8..16], tag_bits, .little);
                t = blocks[2].xorBlocks(AesBlockVec.fromBytes(&sizes));
                for (0..7) |_| {
                    state.update(t, t);
                }
            }
            switch (tag_bits) {
                128 => {
                    const tags = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]).xorBlocks(blocks[4]).xorBlocks(blocks[5]).xorBlocks(blocks[6]).toBytes();
                    return tags[0..16].*;
                },
                256 => {
                    const tags_0 = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]).toBytes();
                    const tags_1 = blocks[4].xorBlocks(blocks[5]).xorBlocks(blocks[6]).xorBlocks(blocks[7]).toBytes();
                    return tags_0[0..16].* ++ tags_1[0..16].*;
                },
                else => unreachable,
            }
        }
    };
}

/// AEGIS is a very fast authenticated encryption system built on top of the core AES function.
///
/// The 128 bits variants of AEGIS have a 128 bit key and a 128 bit nonce.
///
/// https://datatracker.ietf.org/doc/draft-irtf-cfrg-aegis-aead/
fn Aegis128XGeneric(comptime degree: u7, comptime tag_bits: u9) type {
    comptime assert(degree > 0); // degree must be greater than 0
    comptime assert(tag_bits == 128 or tag_bits == 256); // tag must be 128 or 256 bits

    return struct {
        const State = State128X(degree);

        pub const tag_length = tag_bits / 8;
        pub const nonce_length = 16;
        pub const key_length = 16;
        pub const block_length = State.rate;

        const alignment = State.alignment;

        /// c: ciphertext: output buffer should be of size m.len
        /// tag: authentication tag: output MAC
        /// m: message
        /// ad: Associated Data
        /// npub: public nonce
        /// k: private key
        pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) void {
            assert(c.len == m.len);
            var state = State.init(key, npub);
            var src: [block_length]u8 align(alignment) = undefined;
            var dst: [block_length]u8 align(alignment) = undefined;
            var i: usize = 0;
            while (i + block_length <= ad.len) : (i += block_length) {
                state.absorb(ad[i..][0..block_length]);
            }
            if (ad.len % block_length != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. ad.len % block_length], ad[i..][0 .. ad.len % block_length]);
                state.absorb(&src);
            }
            i = 0;
            while (i + block_length <= m.len) : (i += block_length) {
                state.enc(c[i..][0..block_length], m[i..][0..block_length]);
            }
            if (m.len % block_length != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. m.len % block_length], m[i..][0 .. m.len % block_length]);
                state.enc(&dst, &src);
                @memcpy(c[i..][0 .. m.len % block_length], dst[0 .. m.len % block_length]);
            }
            tag.* = state.finalize(tag_bits, ad.len, m.len);
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
            var state = State.init(key, npub);
            var src: [block_length]u8 align(alignment) = undefined;
            var i: usize = 0;
            while (i + block_length <= ad.len) : (i += block_length) {
                state.absorb(ad[i..][0..block_length]);
            }
            if (ad.len % block_length != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. ad.len % block_length], ad[i..][0 .. ad.len % block_length]);
                state.absorb(&src);
            }
            i = 0;
            while (i + block_length <= m.len) : (i += block_length) {
                state.dec(m[i..][0..block_length], c[i..][0..block_length]);
            }
            if (m.len % block_length != 0) {
                state.decLast(m[i..], c[i..]);
            }
            var computed_tag = state.finalize(tag_bits, ad.len, m.len);
            const verify = crypto.timing_safe.eql([tag_length]u8, computed_tag, tag);
            if (!verify) {
                crypto.secureZero(u8, &computed_tag);
                @memset(m, undefined);
                return error.AuthenticationFailed;
            }
        }
    };
}

fn State256X(comptime degree: u7) type {
    return struct {
        const AesBlockVec = crypto.core.aes.BlockVec(degree);
        const State = @This();

        blocks: [6]AesBlockVec,

        const aes_block_length = AesBlockVec.block_length;
        const rate = aes_block_length;
        const alignment = AesBlockVec.native_word_size;

        fn init(key: [32]u8, nonce: [32]u8) State {
            const c1 = AesBlockVec.fromBytes(&[16]u8{ 0xdb, 0x3d, 0x18, 0x55, 0x6d, 0xc2, 0x2f, 0xf1, 0x20, 0x11, 0x31, 0x42, 0x73, 0xb5, 0x28, 0xdd } ** degree);
            const c2 = AesBlockVec.fromBytes(&[16]u8{ 0x0, 0x1, 0x01, 0x02, 0x03, 0x05, 0x08, 0x0d, 0x15, 0x22, 0x37, 0x59, 0x90, 0xe9, 0x79, 0x62 } ** degree);
            const key_block1 = AesBlockVec.fromBytes(key[0..16] ** degree);
            const key_block2 = AesBlockVec.fromBytes(key[16..32] ** degree);
            const nonce_block1 = AesBlockVec.fromBytes(nonce[0..16] ** degree);
            const nonce_block2 = AesBlockVec.fromBytes(nonce[16..32] ** degree);
            const kxn1 = key_block1.xorBlocks(nonce_block1);
            const kxn2 = key_block2.xorBlocks(nonce_block2);
            const blocks = [6]AesBlockVec{
                kxn1,
                kxn2,
                c1,
                c2,
                key_block1.xorBlocks(c2),
                key_block2.xorBlocks(c1),
            };
            var state = State{ .blocks = blocks };
            if (degree > 1) {
                const context_block = ctx: {
                    var contexts_bytes = [_]u8{0} ** aes_block_length;
                    for (0..degree) |i| {
                        contexts_bytes[i * 16] = @intCast(i);
                        contexts_bytes[i * 16 + 1] = @intCast(degree - 1);
                    }
                    break :ctx AesBlockVec.fromBytes(&contexts_bytes);
                };
                for (0..4) |_| {
                    state.blocks[3] = state.blocks[3].xorBlocks(context_block);
                    state.blocks[5] = state.blocks[5].xorBlocks(context_block);
                    state.update(key_block1);
                    state.blocks[3] = state.blocks[3].xorBlocks(context_block);
                    state.blocks[5] = state.blocks[5].xorBlocks(context_block);
                    state.update(key_block2);
                    state.blocks[3] = state.blocks[3].xorBlocks(context_block);
                    state.blocks[5] = state.blocks[5].xorBlocks(context_block);
                    state.update(kxn1);
                    state.blocks[3] = state.blocks[3].xorBlocks(context_block);
                    state.blocks[5] = state.blocks[5].xorBlocks(context_block);
                    state.update(kxn2);
                }
            } else {
                for (0..4) |_| {
                    state.update(key_block1);
                    state.update(key_block2);
                    state.update(kxn1);
                    state.update(kxn2);
                }
            }
            return state;
        }

        inline fn update(state: *State, d: AesBlockVec) void {
            const blocks = &state.blocks;
            const tmp = blocks[5].encrypt(blocks[0]);
            comptime var i: usize = 5;
            inline while (i > 0) : (i -= 1) {
                blocks[i] = blocks[i - 1].encrypt(blocks[i]);
            }
            blocks[0] = tmp.xorBlocks(d);
        }

        fn absorb(state: *State, src: *const [rate]u8) void {
            const msg = AesBlockVec.fromBytes(src);
            state.update(msg);
        }

        fn enc(state: *State, dst: *[rate]u8, src: *const [rate]u8) void {
            const blocks = &state.blocks;
            const msg = AesBlockVec.fromBytes(src);
            var tmp = msg.xorBlocks(blocks[5]).xorBlocks(blocks[4]).xorBlocks(blocks[1]);
            tmp = tmp.xorBlocks(blocks[2].andBlocks(blocks[3]));
            dst.* = tmp.toBytes();
            state.update(msg);
        }

        fn dec(state: *State, dst: *[rate]u8, src: *const [rate]u8) void {
            const blocks = &state.blocks;
            var msg = AesBlockVec.fromBytes(src).xorBlocks(blocks[5]).xorBlocks(blocks[4]).xorBlocks(blocks[1]);
            msg = msg.xorBlocks(blocks[2].andBlocks(blocks[3]));
            dst.* = msg.toBytes();
            state.update(msg);
        }

        fn decLast(state: *State, dst: []u8, src: []const u8) void {
            const blocks = &state.blocks;
            const z = blocks[5].xorBlocks(blocks[4]).xorBlocks(blocks[1]).xorBlocks(blocks[2].andBlocks(blocks[3]));
            var pad = z.toBytes();
            for (pad[0..src.len], src) |*p, x| p.* ^= x;
            @memcpy(dst, pad[0..src.len]);
            @memset(pad[src.len..], 0);
            const msg = AesBlockVec.fromBytes(pad[0..]);
            state.update(msg);
        }

        fn finalize(state: *State, comptime tag_bits: u9, adlen: usize, mlen: usize) [tag_bits / 8]u8 {
            const blocks = &state.blocks;
            var sizes: [aes_block_length]u8 = undefined;
            mem.writeInt(u64, sizes[0..8], @as(u64, adlen) * 8, .little);
            mem.writeInt(u64, sizes[8..16], @as(u64, mlen) * 8, .little);
            for (1..degree) |i| {
                @memcpy(sizes[i * 16 ..][0..16], sizes[0..16]);
            }
            const tmp = AesBlockVec.fromBytes(&sizes).xorBlocks(blocks[3]);
            for (0..7) |_| {
                state.update(tmp);
            }
            switch (tag_bits) {
                128 => {
                    var tag_multi = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]).xorBlocks(blocks[4]).xorBlocks(blocks[5]).toBytes();
                    var tag = tag_multi[0..16].*;
                    @memcpy(tag[0..], tag_multi[0..16]);
                    for (1..degree) |d| {
                        for (0..16) |i| {
                            tag[i] ^= tag_multi[d * 16 + i];
                        }
                    }
                    return tag;
                },
                256 => {
                    const tag_multi_1 = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).toBytes();
                    const tag_multi_2 = blocks[3].xorBlocks(blocks[4]).xorBlocks(blocks[5]).toBytes();
                    var tag = tag_multi_1[0..16].* ++ tag_multi_2[0..16].*;
                    for (1..degree) |d| {
                        for (0..16) |i| {
                            tag[i] ^= tag_multi_1[d * 16 + i];
                            tag[i + 16] ^= tag_multi_2[d * 16 + i];
                        }
                    }
                    return tag;
                },
                else => unreachable,
            }
        }

        fn finalizeMac(state: *State, comptime tag_bits: u9, datalen: usize) [tag_bits / 8]u8 {
            const blocks = &state.blocks;
            var sizes: [aes_block_length]u8 = undefined;
            mem.writeInt(u64, sizes[0..8], @as(u64, datalen) * 8, .little);
            mem.writeInt(u64, sizes[8..16], tag_bits, .little);
            for (1..degree) |i| {
                @memcpy(sizes[i * 16 ..][0..16], sizes[0..16]);
            }
            var t = blocks[3].xorBlocks(AesBlockVec.fromBytes(&sizes));
            for (0..7) |_| {
                state.update(t);
            }
            if (degree > 1) {
                var v = [_]u8{0} ** rate;
                switch (tag_bits) {
                    128 => {
                        const tags = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]).xorBlocks(blocks[4]).xorBlocks(blocks[5]).toBytes();
                        for (1..degree) |d| {
                            v[0..16].* = tags[d * 16 ..][0..16].*;
                            state.absorb(&v);
                        }
                    },
                    256 => {
                        const tags_0 = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).toBytes();
                        const tags_1 = blocks[3].xorBlocks(blocks[4]).xorBlocks(blocks[5]).toBytes();
                        for (1..degree) |d| {
                            v[0..16].* = tags_0[d * 16 ..][0..16].*;
                            state.absorb(&v);
                            v[0..16].* = tags_1[d * 16 ..][0..16].*;
                            state.absorb(&v);
                        }
                    },
                    else => unreachable,
                }
                mem.writeInt(u64, sizes[0..8], degree, .little);
                mem.writeInt(u64, sizes[8..16], tag_bits, .little);
                t = blocks[3].xorBlocks(AesBlockVec.fromBytes(&sizes));
                for (0..7) |_| {
                    state.update(t);
                }
            }
            switch (tag_bits) {
                128 => {
                    const tags = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]).xorBlocks(blocks[4]).xorBlocks(blocks[5]).toBytes();
                    return tags[0..16].*;
                },
                256 => {
                    const tags_0 = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).toBytes();
                    const tags_1 = blocks[3].xorBlocks(blocks[4]).xorBlocks(blocks[5]).toBytes();
                    return tags_0[0..16].* ++ tags_1[0..16].*;
                },
                else => unreachable,
            }
        }
    };
}

/// AEGIS is a very fast authenticated encryption system built on top of the core AES function.
///
/// The 256 bits variants of AEGIS have a 256 bit key and a 256 bit nonce.
///
/// https://datatracker.ietf.org/doc/draft-irtf-cfrg-aegis-aead/
fn Aegis256XGeneric(comptime degree: u7, comptime tag_bits: u9) type {
    comptime assert(degree > 0); // degree must be greater than 0
    comptime assert(tag_bits == 128 or tag_bits == 256); // tag must be 128 or 256 bits

    return struct {
        const State = State256X(degree);

        pub const tag_length = tag_bits / 8;
        pub const nonce_length = 32;
        pub const key_length = 32;
        pub const block_length = State.rate;

        const alignment = State.alignment;

        /// c: ciphertext: output buffer should be of size m.len
        /// tag: authentication tag: output MAC
        /// m: message
        /// ad: Associated Data
        /// npub: public nonce
        /// k: private key
        pub fn encrypt(c: []u8, tag: *[tag_length]u8, m: []const u8, ad: []const u8, npub: [nonce_length]u8, key: [key_length]u8) void {
            assert(c.len == m.len);
            var state = State.init(key, npub);
            var src: [block_length]u8 align(alignment) = undefined;
            var dst: [block_length]u8 align(alignment) = undefined;
            var i: usize = 0;
            while (i + block_length <= ad.len) : (i += block_length) {
                state.enc(&dst, ad[i..][0..block_length]);
            }
            if (ad.len % block_length != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. ad.len % block_length], ad[i..][0 .. ad.len % block_length]);
                state.enc(&dst, &src);
            }
            i = 0;
            while (i + block_length <= m.len) : (i += block_length) {
                state.enc(c[i..][0..block_length], m[i..][0..block_length]);
            }
            if (m.len % block_length != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. m.len % block_length], m[i..][0 .. m.len % block_length]);
                state.enc(&dst, &src);
                @memcpy(c[i..][0 .. m.len % block_length], dst[0 .. m.len % block_length]);
            }
            tag.* = state.finalize(tag_bits, ad.len, m.len);
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
            var state = State.init(key, npub);
            var src: [block_length]u8 align(alignment) = undefined;
            var i: usize = 0;
            while (i + block_length <= ad.len) : (i += block_length) {
                state.absorb(ad[i..][0..block_length]);
            }
            if (ad.len % block_length != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. ad.len % block_length], ad[i..][0 .. ad.len % block_length]);
                state.absorb(&src);
            }
            i = 0;
            while (i + block_length <= m.len) : (i += block_length) {
                state.dec(m[i..][0..block_length], c[i..][0..block_length]);
            }
            if (m.len % block_length != 0) {
                state.decLast(m[i..], c[i..]);
            }
            var computed_tag = state.finalize(tag_bits, ad.len, m.len);
            const verify = crypto.timing_safe.eql([tag_length]u8, computed_tag, tag);
            if (!verify) {
                crypto.secureZero(u8, &computed_tag);
                @memset(m, undefined);
                return error.AuthenticationFailed;
            }
        }
    };
}

/// The `Aegis128X4Mac` message authentication function outputs 256 bit tags.
/// In addition to being extremely fast, its large state, non-linearity
/// and non-invertibility provides the following properties:
/// - 128 bit security, stronger than GHash/Polyval/Poly1305.
/// - Recovering the secret key from the state would require ~2^128 attempts,
///   which is infeasible for any practical adversary.
/// - It has a large security margin against internal collisions.
pub const Aegis128X4Mac = AegisMac(Aegis128X4_256);

/// The `Aegis128X2Mac` message authentication function outputs 256 bit tags.
/// In addition to being extremely fast, its large state, non-linearity
/// and non-invertibility provides the following properties:
/// - 128 bit security, stronger than GHash/Polyval/Poly1305.
/// - Recovering the secret key from the state would require ~2^128 attempts,
///   which is infeasible for any practical adversary.
/// - It has a large security margin against internal collisions.
pub const Aegis128X2Mac = AegisMac(Aegis128X2_256);

/// The `Aegis128LMac` message authentication function outputs 256 bit tags.
/// In addition to being extremely fast, its large state, non-linearity
/// and non-invertibility provides the following properties:
/// - 128 bit security, stronger than GHash/Polyval/Poly1305.
/// - Recovering the secret key from the state would require ~2^128 attempts,
///   which is infeasible for any practical adversary.
/// - It has a large security margin against internal collisions.
pub const Aegis128LMac = AegisMac(Aegis128L_256);

/// The `Aegis256X4Mac` message authentication function has a 256-bit key size,
/// and outputs 256 bit tags.
/// The key size is the main practical difference with `Aegis128X4Mac`.
/// AEGIS' large state, non-linearity and non-invertibility provides the
/// following properties:
/// - 256 bit security against forgery.
/// - Recovering the secret key from the state would require ~2^256 attempts,
///   which is infeasible for any practical adversary.
/// - It has a large security margin against internal collisions.
pub const Aegis256X4Mac = AegisMac(Aegis256X4_256);

/// The `Aegis256X2Mac` message authentication function has a 256-bit key size,
/// and outputs 256 bit tags.
/// The key size is the main practical difference with `Aegis128X2Mac`.
/// AEGIS' large state, non-linearity and non-invertibility provides the
/// following properties:
/// - 256 bit security against forgery.
/// - Recovering the secret key from the state would require ~2^256 attempts,
///   which is infeasible for any practical adversary.
/// - It has a large security margin against internal collisions.
pub const Aegis256X2Mac = AegisMac(Aegis256X2_256);

/// The `Aegis256Mac` message authentication function has a 256-bit key size,
/// and outputs 256 bit tags.
/// The key size is the main practical difference with `Aegis128LMac`.
/// AEGIS' large state, non-linearity and non-invertibility provides the
/// following properties:
/// - 256 bit security against forgery.
/// - Recovering the secret key from the state would require ~2^256 attempts,
///   which is infeasible for any practical adversary.
/// - It has a large security margin against internal collisions.
pub const Aegis256Mac = AegisMac(Aegis256_256);

/// AEGIS-128X4 MAC with 128-bit tags
pub const Aegis128X4Mac_128 = AegisMac(Aegis128X4);

/// AEGIS-128X2 MAC with 128-bit tags
pub const Aegis128X2Mac_128 = AegisMac(Aegis128X2);

/// AEGIS-128L MAC with 128-bit tags
pub const Aegis128LMac_128 = AegisMac(Aegis128L);

/// AEGIS-256X4 MAC with 128-bit tags
pub const Aegis256X4Mac_128 = AegisMac(Aegis256X4);

/// AEGIS-256X2 MAC with 128-bit tags
pub const Aegis256X2Mac_128 = AegisMac(Aegis256X2);

/// AEGIS-256 MAC with 128-bit tags
pub const Aegis256Mac_128 = AegisMac(Aegis256);

fn AegisMac(comptime T: type) type {
    return struct {
        const Mac = @This();

        pub const mac_length = T.tag_length;
        pub const key_length = T.key_length;
        pub const nonce_length = T.nonce_length;
        pub const block_length = T.block_length;

        state: T.State,
        buf: [block_length]u8 = undefined,
        off: usize = 0,
        msg_len: usize = 0,

        /// Initialize a state for the MAC function, with a key and a nonce
        pub fn initWithNonce(key: *const [key_length]u8, nonce: *const [nonce_length]u8) Mac {
            return Mac{
                .state = T.State.init(key.*, nonce.*),
            };
        }

        /// Initialize a state for the MAC function, with a default nonce
        pub fn init(key: *const [key_length]u8) Mac {
            return Mac{
                .state = T.State.init(key.*, [_]u8{0} ** nonce_length),
            };
        }

        /// Add data to the state
        pub fn update(self: *Mac, b: []const u8) void {
            self.msg_len += b.len;

            const len_partial = @min(b.len, block_length - self.off);
            @memcpy(self.buf[self.off..][0..len_partial], b[0..len_partial]);
            self.off += len_partial;
            if (self.off < block_length) {
                return;
            }
            self.state.absorb(&self.buf);

            var i = len_partial;
            self.off = 0;
            while (i + block_length * 2 <= b.len) : (i += block_length * 2) {
                self.state.absorb(b[i..][0..block_length]);
                self.state.absorb(b[i..][block_length .. block_length * 2]);
            }
            while (i + block_length <= b.len) : (i += block_length) {
                self.state.absorb(b[i..][0..block_length]);
            }
            if (i != b.len) {
                self.off = b.len - i;
                @memcpy(self.buf[0..self.off], b[i..]);
            }
        }

        /// Return an authentication tag for the current state
        pub fn final(self: *Mac, out: *[mac_length]u8) void {
            if (self.off > 0) {
                var pad = [_]u8{0} ** block_length;
                @memcpy(pad[0..self.off], self.buf[0..self.off]);
                self.state.absorb(&pad);
            }
            out.* = self.state.finalizeMac(T.tag_length * 8, self.msg_len);
        }

        /// Return an authentication tag for a message, a key and a nonce
        pub fn createWithNonce(out: *[mac_length]u8, msg: []const u8, key: *const [key_length]u8, nonce: *const [nonce_length]u8) void {
            var ctx = Mac.initWithNonce(key, nonce);
            ctx.update(msg);
            ctx.final(out);
        }

        /// Return an authentication tag for a message and a key
        pub fn create(out: *[mac_length]u8, msg: []const u8, key: *const [key_length]u8) void {
            var ctx = Mac.init(key);
            ctx.update(msg);
            ctx.final(out);
        }

        pub const Error = error{};
        pub const Writer = std.io.Writer(*Mac, Error, write);

        fn write(self: *Mac, bytes: []const u8) Error!usize {
            self.update(bytes);
            return bytes.len;
        }

        pub fn writer(self: *Mac) Writer {
            return .{ .context = self };
        }
    };
}

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

test "Aegis128X2 test vector 1" {
    const key: [Aegis128X2.key_length]u8 = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };
    const nonce: [Aegis128X2.nonce_length]u8 = [_]u8{ 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f };
    var empty = [_]u8{};
    var tag: [Aegis128X2.tag_length]u8 = undefined;
    var tag256: [Aegis128X2_256.tag_length]u8 = undefined;

    Aegis128X2.encrypt(&empty, &tag, &empty, &empty, nonce, key);
    Aegis128X2_256.encrypt(&empty, &tag256, &empty, &empty, nonce, key);
    try htest.assertEqual("63117dc57756e402819a82e13eca8379", &tag);
    try htest.assertEqual("b92c71fdbd358b8a4de70b27631ace90cffd9b9cfba82028412bac41b4f53759", &tag256);
    tag[0] +%= 1;
    try testing.expectError(error.AuthenticationFailed, Aegis128X2.decrypt(&empty, &empty, tag, &empty, nonce, key));
    tag256[0] +%= 1;
    try testing.expectError(error.AuthenticationFailed, Aegis128X2_256.decrypt(&empty, &empty, tag256, &empty, nonce, key));
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

test "Aegis256X4 test vector 1" {
    const key: [Aegis256X4.key_length]u8 = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f };
    const nonce: [Aegis256X4.nonce_length]u8 = [_]u8{ 0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f };
    var empty = [_]u8{};
    var tag: [Aegis256X4.tag_length]u8 = undefined;
    var tag256: [Aegis256X4_256.tag_length]u8 = undefined;

    Aegis256X4.encrypt(&empty, &tag, &empty, &empty, nonce, key);
    Aegis256X4_256.encrypt(&empty, &tag256, &empty, &empty, nonce, key);
    try htest.assertEqual("3b7fee6cee7bf17888ad11ed2397beb4", &tag);
    try htest.assertEqual("6093a1a8aab20ec635dc1ca71745b01b5bec4fc444c9ffbebd710d4a34d20eaf", &tag256);
    tag[0] +%= 1;
    try testing.expectError(error.AuthenticationFailed, Aegis256X4.decrypt(&empty, &empty, tag, &empty, nonce, key));
    tag256[0] +%= 1;
    try testing.expectError(error.AuthenticationFailed, Aegis256X4_256.decrypt(&empty, &empty, tag256, &empty, nonce, key));
}

test "Aegis MAC" {
    const key = [_]u8{0x00} ** Aegis128LMac.key_length;
    var msg: [64]u8 = undefined;
    for (&msg, 0..) |*m, i| {
        m.* = @as(u8, @truncate(i));
    }
    const st_init = Aegis128LMac.init(&key);
    var st = st_init;
    var tag: [Aegis128LMac.mac_length]u8 = undefined;

    st.update(msg[0..32]);
    st.update(msg[32..]);
    st.final(&tag);
    try htest.assertEqual("f5eb88d90b7d31c9a679eb94ed1374cd14816b19cdb77930d1a5158f8595983b", &tag);

    st = st_init;
    st.update(msg[0..31]);
    st.update(msg[31..]);
    st.final(&tag);
    try htest.assertEqual("f5eb88d90b7d31c9a679eb94ed1374cd14816b19cdb77930d1a5158f8595983b", &tag);

    st = st_init;
    st.update(msg[0..14]);
    st.update(msg[14..30]);
    st.update(msg[30..]);
    st.final(&tag);
    try htest.assertEqual("f5eb88d90b7d31c9a679eb94ed1374cd14816b19cdb77930d1a5158f8595983b", &tag);

    // An update whose size is not a multiple of the block size
    st = st_init;
    st.update(msg[0..33]);
    st.final(&tag);
    try htest.assertEqual("07b3ba5ad9ceee5ef1906e3396f0fa540fbcd2f33833ef97c35bdc2ae9ae0535", &tag);
}

test "AEGISMAC-128* test vectors" {
    const key = [_]u8{ 0x10, 0x01 } ++ [_]u8{0x00} ** (16 - 2);
    const nonce = [_]u8{ 0x10, 0x00, 0x02 } ++ [_]u8{0x00} ** (16 - 3);
    var msg: [35]u8 = undefined;
    for (&msg, 0..) |*byte, i| byte.* = @truncate(i);
    var mac128: [16]u8 = undefined;
    var mac256: [32]u8 = undefined;

    Aegis128LMac.createWithNonce(&mac256, &msg, &key, &nonce);
    Aegis128LMac_128.createWithNonce(&mac128, &msg, &key, &nonce);
    try htest.assertEqual("d3f09b2842ad301687d6902c921d7818", &mac128);
    try htest.assertEqual("9490e7c89d420c9f37417fa625eb38e8cad53c5cbec55285e8499ea48377f2a3", &mac256);

    Aegis128X2Mac.createWithNonce(&mac256, &msg, &key, &nonce);
    Aegis128X2Mac_128.createWithNonce(&mac128, &msg, &key, &nonce);
    try htest.assertEqual("6873ee34e6b5c59143b6d35c5e4f2c6e", &mac128);
    try htest.assertEqual("afcba3fc2d63c8d6c7f2d63f3ec8fbbbaf022e15ac120e78ffa7755abccd959c", &mac256);

    Aegis128X4Mac.createWithNonce(&mac256, &msg, &key, &nonce);
    Aegis128X4Mac_128.createWithNonce(&mac128, &msg, &key, &nonce);
    try htest.assertEqual("c45a98fd9ab8956ce616eb008cfe4e53", &mac128);
    try htest.assertEqual("26fdc76f41b1da7aec7779f6e964beae8904e662f05aca8345ae3befb357412a", &mac256);
}

test "AEGISMAC-256* test vectors" {
    const key = [_]u8{ 0x10, 0x01 } ++ [_]u8{0x00} ** (32 - 2);
    const nonce = [_]u8{ 0x10, 0x00, 0x02 } ++ [_]u8{0x00} ** (32 - 3);
    var msg: [35]u8 = undefined;
    for (&msg, 0..) |*byte, i| byte.* = @truncate(i);
    var mac128: [16]u8 = undefined;
    var mac256: [32]u8 = undefined;

    Aegis256Mac.createWithNonce(&mac256, &msg, &key, &nonce);
    Aegis256Mac_128.createWithNonce(&mac128, &msg, &key, &nonce);
    try htest.assertEqual("c08e20cfc56f27195a46c9cef5c162d4", &mac128);
    try htest.assertEqual("a5c906ede3d69545c11e20afa360b221f936e946ed2dba3d7c75ad6dc2784126", &mac256);

    Aegis256X2Mac.createWithNonce(&mac256, &msg, &key, &nonce);
    Aegis256X2Mac_128.createWithNonce(&mac128, &msg, &key, &nonce);
    try htest.assertEqual("fb319cb6dd728a764606fb14d37f2a5e", &mac128);
    try htest.assertEqual("0844b20ed5147ceae89c7a160263afd4b1382d6b154ecf560ce8a342cb6a8fd1", &mac256);

    Aegis256X4Mac.createWithNonce(&mac256, &msg, &key, &nonce);
    Aegis256X4Mac_128.createWithNonce(&mac128, &msg, &key, &nonce);
    try htest.assertEqual("a51f9bc5beae60cce77f0dbc60761edd", &mac128);
    try htest.assertEqual("b36a16ef07c36d75a91f437502f24f545b8dfa88648ed116943c29fead3bf10c", &mac256);
}
