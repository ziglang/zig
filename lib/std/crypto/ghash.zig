// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
//
// Adapted from BearSSL's ctmul64 implementation originally written by Thomas Pornin <pornin@bolet.org>

const std = @import("../std.zig");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;

/// GHASH is a universal hash function that features multiplication
/// by a fixed parameter within a Galois field.
///
/// It is not a general purpose hash function - The key must be secret, unpredictable and never reused.
///
/// GHASH is typically used to compute the authentication tag in the AES-GCM construction.
pub const Ghash = struct {
    pub const block_size: usize = 16;
    pub const mac_length = 16;
    pub const minimum_key_length = 16;

    y0: u64 = 0,
    y1: u64 = 0,
    h0: u64,
    h1: u64,
    h2: u64,
    h0r: u64,
    h1r: u64,
    h2r: u64,

    leftover: usize = 0,
    buf: [block_size]u8 align(16) = undefined,

    pub fn init(key: *const [minimum_key_length]u8) Ghash {
        const h1 = mem.readIntBig(u64, key[0..8]);
        const h0 = mem.readIntBig(u64, key[8..16]);
        const h1r = @bitReverse(u64, h1);
        const h0r = @bitReverse(u64, h0);
        const h2 = h0 ^ h1;
        const h2r = h0r ^ h1r;

        return Ghash{
            .h0 = h0,
            .h1 = h1,
            .h2 = h2,
            .h0r = h0r,
            .h1r = h1r,
            .h2r = h2r,
        };
    }

    fn bmul(x: u64, y: u64) u64 {
        const x0 = x & 0x1111111111111111;
        const x1 = x & 0x2222222222222222;
        const x2 = x & 0x4444444444444444;
        const x3 = x & 0x8888888888888888;
        const y0 = y & 0x1111111111111111;
        const y1 = y & 0x2222222222222222;
        const y2 = y & 0x4444444444444444;
        const y3 = y & 0x8888888888888888;
        var z0 = (x0 *% y0) ^ (x1 *% y3) ^ (x2 *% y2) ^ (x3 *% y1);
        var z1 = (x0 *% y1) ^ (x1 *% y0) ^ (x2 *% y3) ^ (x3 *% y2);
        var z2 = (x0 *% y2) ^ (x1 *% y1) ^ (x2 *% y0) ^ (x3 *% y3);
        var z3 = (x0 *% y3) ^ (x1 *% y2) ^ (x2 *% y1) ^ (x3 *% y0);
        z0 &= 0x1111111111111111;
        z1 &= 0x2222222222222222;
        z2 &= 0x4444444444444444;
        z3 &= 0x8888888888888888;

        return z0 | z1 | z2 | z3;
    }

    fn blocks(st: *Ghash, msg: []const u8) void {
        assert(msg.len % 16 == 0); // GHASH blocks() expects full blocks
        var y1 = st.y1;
        var y0 = st.y0;

        var i: usize = 0;
        while (i + 16 <= msg.len) : (i += 16) {
            y1 ^= mem.readIntBig(u64, msg[i..][0..8]);
            y0 ^= mem.readIntBig(u64, msg[i..][8..16]);

            const y1r = @bitReverse(u64, y1);
            const y0r = @bitReverse(u64, y0);
            const y2 = y0 ^ y1;
            const y2r = y0r ^ y1r;

            const z0 = bmul(y0, st.h0);
            const z1 = bmul(y1, st.h1);
            var z2 = bmul(y2, st.h2);
            var z0h = bmul(y0r, st.h0r);
            var z1h = bmul(y1r, st.h1r);
            var z2h = bmul(y2r, st.h2r);
            z2 ^= z0 ^ z1;
            z2h ^= z0h ^ z1h;
            z0h = @bitReverse(u64, z0h) >> 1;
            z1h = @bitReverse(u64, z1h) >> 1;
            z2h = @bitReverse(u64, z2h) >> 1;

            var v3 = z1h;
            var v2 = z1 ^ z2h;
            var v1 = z0h ^ z2;
            var v0 = z0;

            v3 = (v3 << 1) | (v2 >> 63);
            v2 = (v2 << 1) | (v1 >> 63);
            v1 = (v1 << 1) | (v0 >> 63);
            v0 = (v0 << 1);

            v2 ^= v0 ^ (v0 >> 1) ^ (v0 >> 2) ^ (v0 >> 7);
            v1 ^= (v0 << 63) ^ (v0 << 62) ^ (v0 << 57);
            y1 = v3 ^ v1 ^ (v1 >> 1) ^ (v1 >> 2) ^ (v1 >> 7);
            y0 = v2 ^ (v1 << 63) ^ (v1 << 62) ^ (v1 << 57);
        }
        st.y1 = y1;
        st.y0 = y0;
    }

    pub fn update(st: *Ghash, m: []const u8) void {
        var mb = m;

        if (st.leftover > 0) {
            const want = math.min(block_size - st.leftover, mb.len);
            const mc = mb[0..want];
            for (mc) |x, i| {
                st.buf[st.leftover + i] = x;
            }
            mb = mb[want..];
            st.leftover += want;
            if (st.leftover > block_size) {
                return;
            }
            st.blocks(&st.buf);
            st.leftover = 0;
        }
        if (mb.len >= block_size) {
            const want = mb.len & ~(block_size - 1);
            st.blocks(mb[0..want]);
            mb = mb[want..];
        }
        if (mb.len > 0) {
            for (mb) |x, i| {
                st.buf[st.leftover + i] = x;
            }
            st.leftover += mb.len;
        }
    }

    pub fn final(st: *Ghash, out: *[mac_length]u8) void {
        if (st.leftover > 0) {
            var i = st.leftover;
            while (i < block_size) : (i += 1) {
                st.buf[i] = 0;
            }
            st.blocks(&st.buf);
        }
        mem.writeIntBig(u64, out[0..8], st.y1);
        mem.writeIntBig(u64, out[8..16], st.y0);

        mem.secureZero(u8, @ptrCast([*]u8, st)[0..@sizeOf(Ghash)]);
    }

    pub fn create(out: *[mac_length]u8, msg: []const u8, key: *const [minimum_key_length]u8) void {
        var st = Ghash.init(key);
        st.update(msg);
        st.final(out);
    }
};

const htest = @import("test.zig");

test "ghash" {
    const key = [_]u8{0x42} ** 16;
    const m = [_]u8{0x69} ** 256;

    var st = Ghash.init(&key);
    st.update(&m);
    var out: [16]u8 = undefined;
    st.final(&out);
    htest.assertEqual("889295fa746e8b174bf4ec80a65dea41", &out);

    st = Ghash.init(&key);
    st.update(m[0..100]);
    st.update(m[100..]);
    st.final(&out);
    htest.assertEqual("889295fa746e8b174bf4ec80a65dea41", &out);
}
