//! AEGIS is a very fast authenticated encryption system built on top of the core AES function.
//!
//! The AEGIS-128L variant has a 128 bit key, a 128 bit nonce, and processes 256 bit message blocks.
//! The AEGIS-256  variant has a 256 bit key, a 256 bit nonce, and processes 128 bit message blocks.
//!
//! The AEGIS cipher family offers performance that significantly exceeds that of AES-GCM with
//! hardware support for parallelizable AES block encryption.
//!
//! Unlike with AES-GCM, nonces can be safely chosen at random with no practical limit when using AEGIS-256.
//! AEGIS-128L also allows for more messages to be safely encrypted when using random nonces.
//!
//! AEGIS is believed to be key-committing, making it a safer choice than most other AEADs
//! when the key has low entropy, or can be controlled by an attacker.
//!
//! Finally, leaking the state does not leak the key.
//!
//! https://datatracker.ietf.org/doc/draft-irtf-cfrg-aegis-aead/

const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;
const AesBlock = std.crypto.core.aes.Block;
const AuthenticationError = std.crypto.errors.AuthenticationError;

/// AEGIS-128L with a 128-bit authentication tag.
pub const Aegis128L = Aegis128LGeneric(128);

/// AEGIS-128L with a 256-bit authentication tag.
pub const Aegis128L_256 = Aegis128LGeneric(256);

/// AEGIS-256 with a 128-bit authentication tag.
pub const Aegis256 = Aegis256Generic(128);

/// AEGIS-256 with a 256-bit authentication tag.
pub const Aegis256_256 = Aegis256Generic(256);

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

    inline fn update(state: *State128L, d1: AesBlock, d2: AesBlock) void {
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

    fn absorb(state: *State128L, src: *const [32]u8) void {
        const msg0 = AesBlock.fromBytes(src[0..16]);
        const msg1 = AesBlock.fromBytes(src[16..32]);
        state.update(msg0, msg1);
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

    fn mac(state: *State128L, comptime tag_bits: u9, adlen: usize, mlen: usize) [tag_bits / 8]u8 {
        const blocks = &state.blocks;
        var sizes: [16]u8 = undefined;
        mem.writeIntLittle(u64, sizes[0..8], adlen * 8);
        mem.writeIntLittle(u64, sizes[8..16], mlen * 8);
        const tmp = AesBlock.fromBytes(&sizes).xorBlocks(blocks[2]);
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            state.update(tmp, tmp);
        }
        return switch (tag_bits) {
            128 => blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3])
                .xorBlocks(blocks[4]).xorBlocks(blocks[5]).xorBlocks(blocks[6]).toBytes(),
            256 => tag: {
                const t1 = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3]);
                const t2 = blocks[4].xorBlocks(blocks[5]).xorBlocks(blocks[6]).xorBlocks(blocks[7]);
                break :tag t1.toBytes() ++ t2.toBytes();
            },
            else => unreachable,
        };
    }
};

fn Aegis128LGeneric(comptime tag_bits: u9) type {
    comptime assert(tag_bits == 128 or tag_bits == 256); // tag must be 128 or 256 bits

    return struct {
        pub const tag_length = tag_bits / 8;
        pub const nonce_length = 16;
        pub const key_length = 16;
        pub const block_length = 32;

        const State = State128L;

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
                state.absorb(ad[i..][0..32]);
            }
            if (ad.len % 32 != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. ad.len % 32], ad[i..][0 .. ad.len % 32]);
                state.absorb(&src);
            }
            i = 0;
            while (i + 32 <= m.len) : (i += 32) {
                state.enc(c[i..][0..32], m[i..][0..32]);
            }
            if (m.len % 32 != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. m.len % 32], m[i..][0 .. m.len % 32]);
                state.enc(&dst, &src);
                @memcpy(c[i..][0 .. m.len % 32], dst[0 .. m.len % 32]);
            }
            tag.* = state.mac(tag_bits, ad.len, m.len);
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
                state.absorb(ad[i..][0..32]);
            }
            if (ad.len % 32 != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. ad.len % 32], ad[i..][0 .. ad.len % 32]);
                state.absorb(&src);
            }
            i = 0;
            while (i + 32 <= m.len) : (i += 32) {
                state.dec(m[i..][0..32], c[i..][0..32]);
            }
            if (m.len % 32 != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. m.len % 32], c[i..][0 .. m.len % 32]);
                state.dec(&dst, &src);
                @memcpy(m[i..][0 .. m.len % 32], dst[0 .. m.len % 32]);
                @memset(dst[0 .. m.len % 32], 0);
                const blocks = &state.blocks;
                blocks[0] = blocks[0].xorBlocks(AesBlock.fromBytes(dst[0..16]));
                blocks[4] = blocks[4].xorBlocks(AesBlock.fromBytes(dst[16..32]));
            }
            const computed_tag = state.mac(tag_bits, ad.len, m.len);
            var acc: u8 = 0;
            for (computed_tag, 0..) |_, j| {
                acc |= (computed_tag[j] ^ tag[j]);
            }
            if (acc != 0) {
                @memset(m, undefined);
                return error.AuthenticationFailed;
            }
        }
    };
}

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

    inline fn update(state: *State256, d: AesBlock) void {
        const blocks = &state.blocks;
        const tmp = blocks[5].encrypt(blocks[0]);
        comptime var i: usize = 5;
        inline while (i > 0) : (i -= 1) {
            blocks[i] = blocks[i - 1].encrypt(blocks[i]);
        }
        blocks[0] = tmp.xorBlocks(d);
    }

    fn absorb(state: *State256, src: *const [16]u8) void {
        const msg = AesBlock.fromBytes(src);
        state.update(msg);
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

    fn mac(state: *State256, comptime tag_bits: u9, adlen: usize, mlen: usize) [tag_bits / 8]u8 {
        const blocks = &state.blocks;
        var sizes: [16]u8 = undefined;
        mem.writeIntLittle(u64, sizes[0..8], adlen * 8);
        mem.writeIntLittle(u64, sizes[8..16], mlen * 8);
        const tmp = AesBlock.fromBytes(&sizes).xorBlocks(blocks[3]);
        var i: usize = 0;
        while (i < 7) : (i += 1) {
            state.update(tmp);
        }
        return switch (tag_bits) {
            128 => blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]).xorBlocks(blocks[3])
                .xorBlocks(blocks[4]).xorBlocks(blocks[5]).toBytes(),
            256 => tag: {
                const t1 = blocks[0].xorBlocks(blocks[1]).xorBlocks(blocks[2]);
                const t2 = blocks[3].xorBlocks(blocks[4]).xorBlocks(blocks[5]);
                break :tag t1.toBytes() ++ t2.toBytes();
            },
            else => unreachable,
        };
    }
};

/// AEGIS is a very fast authenticated encryption system built on top of the core AES function.
///
/// The 256 bit variant of AEGIS has a 256 bit key, a 256 bit nonce, and processes 128 bit message blocks.
///
/// https://datatracker.ietf.org/doc/draft-irtf-cfrg-aegis-aead/
fn Aegis256Generic(comptime tag_bits: u9) type {
    comptime assert(tag_bits == 128 or tag_bits == 256); // tag must be 128 or 256 bits

    return struct {
        pub const tag_length = tag_bits / 8;
        pub const nonce_length = 32;
        pub const key_length = 32;
        pub const block_length = 16;

        const State = State256;

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
                @memset(src[0..], 0);
                @memcpy(src[0 .. ad.len % 16], ad[i..][0 .. ad.len % 16]);
                state.enc(&dst, &src);
            }
            i = 0;
            while (i + 16 <= m.len) : (i += 16) {
                state.enc(c[i..][0..16], m[i..][0..16]);
            }
            if (m.len % 16 != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. m.len % 16], m[i..][0 .. m.len % 16]);
                state.enc(&dst, &src);
                @memcpy(c[i..][0 .. m.len % 16], dst[0 .. m.len % 16]);
            }
            tag.* = state.mac(tag_bits, ad.len, m.len);
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
                @memset(src[0..], 0);
                @memcpy(src[0 .. ad.len % 16], ad[i..][0 .. ad.len % 16]);
                state.enc(&dst, &src);
            }
            i = 0;
            while (i + 16 <= m.len) : (i += 16) {
                state.dec(m[i..][0..16], c[i..][0..16]);
            }
            if (m.len % 16 != 0) {
                @memset(src[0..], 0);
                @memcpy(src[0 .. m.len % 16], c[i..][0 .. m.len % 16]);
                state.dec(&dst, &src);
                @memcpy(m[i..][0 .. m.len % 16], dst[0 .. m.len % 16]);
                @memset(dst[0 .. m.len % 16], 0);
                const blocks = &state.blocks;
                blocks[0] = blocks[0].xorBlocks(AesBlock.fromBytes(&dst));
            }
            const computed_tag = state.mac(tag_bits, ad.len, m.len);
            var acc: u8 = 0;
            for (computed_tag, 0..) |_, j| {
                acc |= (computed_tag[j] ^ tag[j]);
            }
            if (acc != 0) {
                @memset(m, undefined);
                return error.AuthenticationFailed;
            }
        }
    };
}

/// The `Aegis128LMac` message authentication function outputs 256 bit tags.
/// In addition to being extremely fast, its large state, non-linearity
/// and non-invertibility provides the following properties:
/// - 128 bit security, stronger than GHash/Polyval/Poly1305.
/// - Recovering the secret key from the state would require ~2^128 attempts,
///   which is infeasible for any practical adversary.
/// - It has a large security margin against internal collisions.
pub const Aegis128LMac = AegisMac(Aegis128L_256);

/// The `Aegis256Mac` message authentication function has a 256-bit key size,
/// and outputs 256 bit tags. Unless theoretical multi-target attacks are a
/// concern, the AEGIS-128L variant should be preferred.
/// AEGIS' large state, non-linearity and non-invertibility provides the
/// following properties:
/// - More than 128 bit security against forgery.
/// - Recovering the secret key from the state would require ~2^256 attempts,
///   which is infeasible for any practical adversary.
/// - It has a large security margin against internal collisions.
pub const Aegis256Mac = AegisMac(Aegis256_256);

/// Aegis128L MAC with a 128-bit output.
/// A MAC with a 128-bit output is not safe unless the number of messages
/// authenticated with the same key remains small.
/// After 2^48 messages, the probability of a collision is already ~ 2^-33.
/// If unsure, use the  Aegis128LMac type, that has a 256 bit output.
pub const Aegis128LMac_128 = AegisMac(Aegis128L);

/// Aegis256 MAC with a 128-bit output.
/// A MAC with a 128-bit output is not safe unless the number of messages
/// authenticated with the same key remains small.
/// After 2^48 messages, the probability of a collision is already ~ 2^-33.
/// If unsure, use the  Aegis256Mac type, that has a 256 bit output.
pub const Aegis256Mac_128 = AegisMac(Aegis256);

fn AegisMac(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const mac_length = T.tag_length;
        pub const key_length = T.key_length;
        pub const block_length = T.block_length;

        state: T.State,
        buf: [block_length]u8 = undefined,
        off: usize = 0,
        msg_len: usize = 0,

        /// Initialize a state for the MAC function
        pub fn init(key: *const [key_length]u8) Self {
            const nonce = [_]u8{0} ** T.nonce_length;
            return Self{
                .state = T.State.init(key.*, nonce),
            };
        }

        /// Add data to the state
        pub fn update(self: *Self, b: []const u8) void {
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
            while (i + block_length <= b.len) : (i += block_length) {
                self.state.absorb(b[i..][0..block_length]);
            }
            if (i != b.len) {
                self.off = b.len - i;
                @memcpy(self.buf[0..self.off], b[i..]);
            }
        }

        /// Return an authentication tag for the current state
        pub fn final(self: *Self, out: *[mac_length]u8) void {
            if (self.off > 0) {
                var pad = [_]u8{0} ** block_length;
                @memcpy(pad[0..self.off], self.buf[0..self.off]);
                self.state.absorb(&pad);
            }
            out.* = self.state.mac(T.tag_length * 8, self.msg_len, 0);
        }

        /// Return an authentication tag for a message and a key
        pub fn create(out: *[mac_length]u8, msg: []const u8, key: *const [key_length]u8) void {
            var ctx = Self.init(key);
            ctx.update(msg);
            ctx.final(out);
        }

        pub const Error = error{};
        pub const Writer = std.io.Writer(*Self, Error, write);

        fn write(self: *Self, bytes: []const u8) Error!usize {
            self.update(bytes);
            return bytes.len;
        }

        pub fn writer(self: *Self) Writer {
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
    try htest.assertEqual("f8840849602738d81037cbaa0f584ea95759e2ac60263ce77346bcdc79fe4319", &tag);

    st = st_init;
    st.update(msg[0..31]);
    st.update(msg[31..]);
    st.final(&tag);
    try htest.assertEqual("f8840849602738d81037cbaa0f584ea95759e2ac60263ce77346bcdc79fe4319", &tag);

    st = st_init;
    st.update(msg[0..14]);
    st.update(msg[14..30]);
    st.update(msg[30..]);
    st.final(&tag);
    try htest.assertEqual("f8840849602738d81037cbaa0f584ea95759e2ac60263ce77346bcdc79fe4319", &tag);

    var empty: [0]u8 = undefined;
    const nonce = [_]u8{0x00} ** Aegis128L_256.nonce_length;
    Aegis128L_256.encrypt(&empty, &tag, &empty, &msg, nonce, key);
    try htest.assertEqual("f8840849602738d81037cbaa0f584ea95759e2ac60263ce77346bcdc79fe4319", &tag);

    // An update whose size is not a multiple of the block size
    st = st_init;
    st.update(msg[0..33]);
    st.final(&tag);
    try htest.assertEqual("c7cf649a844c1a6676cf6d91b1658e0aee54a4da330b0a8d3bc7ea4067551d1b", &tag);
}
