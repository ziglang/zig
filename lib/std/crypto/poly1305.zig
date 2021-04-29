// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const utils = std.crypto.utils;
const mem = std.mem;

pub const Poly1305 = struct {
    pub const block_length: usize = 16;
    pub const mac_length = 16;
    pub const key_length = 32;

    // constant multiplier (from the secret key)
    r: [3]u64,
    // accumulated hash
    h: [3]u64 = [_]u64{ 0, 0, 0 },
    // random number added at the end (from the secret key)
    pad: [2]u64,
    // how many bytes are waiting to be processed in a partial block
    leftover: usize = 0,
    // partial block buffer
    buf: [block_length]u8 align(16) = undefined,

    pub fn init(key: *const [key_length]u8) Poly1305 {
        const t0 = mem.readIntLittle(u64, key[0..8]);
        const t1 = mem.readIntLittle(u64, key[8..16]);
        return Poly1305{
            .r = [_]u64{
                t0 & 0xffc0fffffff,
                ((t0 >> 44) | (t1 << 20)) & 0xfffffc0ffff,
                ((t1 >> 24)) & 0x00ffffffc0f,
            },
            .pad = [_]u64{
                mem.readIntLittle(u64, key[16..24]),
                mem.readIntLittle(u64, key[24..32]),
            },
        };
    }

    fn blocks(st: *Poly1305, m: []const u8, comptime last: bool) void {
        const hibit: u64 = if (last) 0 else 1 << 40;
        const r0 = st.r[0];
        const r1 = st.r[1];
        const r2 = st.r[2];
        var h0 = st.h[0];
        var h1 = st.h[1];
        var h2 = st.h[2];
        const s1 = r1 * (5 << 2);
        const s2 = r2 * (5 << 2);
        var i: usize = 0;
        while (i + block_length <= m.len) : (i += block_length) {
            // h += m[i]
            const t0 = mem.readIntLittle(u64, m[i..][0..8]);
            const t1 = mem.readIntLittle(u64, m[i + 8 ..][0..8]);
            h0 += @truncate(u44, t0);
            h1 += @truncate(u44, (t0 >> 44) | (t1 << 20));
            h2 += @truncate(u42, t1 >> 24) | hibit;

            // h *= r
            const d0 = @as(u128, h0) * r0 + @as(u128, h1) * s2 + @as(u128, h2) * s1;
            var d1 = @as(u128, h0) * r1 + @as(u128, h1) * r0 + @as(u128, h2) * s2;
            var d2 = @as(u128, h0) * r2 + @as(u128, h1) * r1 + @as(u128, h2) * r0;

            // partial reduction
            var carry = @intCast(u64, d0 >> 44);
            h0 = @truncate(u44, d0);
            d1 += carry;
            carry = @intCast(u64, d1 >> 44);
            h1 = @truncate(u44, d1);
            d2 += carry;
            carry = @intCast(u64, d2 >> 42);
            h2 = @truncate(u42, d2);
            h0 += @truncate(u64, carry) * 5;
            carry = h0 >> 44;
            h0 = @truncate(u44, h0);
            h1 += carry;
        }
        st.h = [_]u64{ h0, h1, h2 };
    }

    pub fn update(st: *Poly1305, m: []const u8) void {
        var mb = m;

        // handle leftover
        if (st.leftover > 0) {
            const want = std.math.min(block_length - st.leftover, mb.len);
            const mc = mb[0..want];
            for (mc) |x, i| {
                st.buf[st.leftover + i] = x;
            }
            mb = mb[want..];
            st.leftover += want;
            if (st.leftover < block_length) {
                return;
            }
            st.blocks(&st.buf, false);
            st.leftover = 0;
        }

        // process full blocks
        if (mb.len >= block_length) {
            const want = mb.len & ~(block_length - 1);
            st.blocks(mb[0..want], false);
            mb = mb[want..];
        }

        // store leftover
        if (mb.len > 0) {
            for (mb) |x, i| {
                st.buf[st.leftover + i] = x;
            }
            st.leftover += mb.len;
        }
    }

    /// Zero-pad to align the next input to the first byte of a block
    pub fn pad(st: *Poly1305) void {
        if (st.leftover == 0) {
            return;
        }
        var i = st.leftover;
        while (i < block_length) : (i += 1) {
            st.buf[i] = 0;
        }
        st.blocks(&st.buf);
        st.leftover = 0;
    }

    pub fn final(st: *Poly1305, out: *[mac_length]u8) void {
        if (st.leftover > 0) {
            var i = st.leftover;
            st.buf[i] = 1;
            i += 1;
            while (i < block_length) : (i += 1) {
                st.buf[i] = 0;
            }
            st.blocks(&st.buf, true);
        }
        // fully carry h
        var carry = st.h[1] >> 44;
        st.h[1] = @truncate(u44, st.h[1]);
        st.h[2] += carry;
        carry = st.h[2] >> 42;
        st.h[2] = @truncate(u42, st.h[2]);
        st.h[0] += carry * 5;
        carry = st.h[0] >> 44;
        st.h[0] = @truncate(u44, st.h[0]);
        st.h[1] += carry;
        carry = st.h[1] >> 44;
        st.h[1] = @truncate(u44, st.h[1]);
        st.h[2] += carry;
        carry = st.h[2] >> 42;
        st.h[2] = @truncate(u42, st.h[2]);
        st.h[0] += carry * 5;
        carry = st.h[0] >> 44;
        st.h[0] = @truncate(u44, st.h[0]);
        st.h[1] += carry;

        // compute h + -p
        var g0 = st.h[0] + 5;
        carry = g0 >> 44;
        g0 = @truncate(u44, g0);
        var g1 = st.h[1] + carry;
        carry = g1 >> 44;
        g1 = @truncate(u44, g1);
        var g2 = st.h[2] + carry -% (1 << 42);

        // (hopefully) constant-time select h if h < p, or h + -p if h >= p
        const mask = (g2 >> 63) -% 1;
        g0 &= mask;
        g1 &= mask;
        g2 &= mask;
        const nmask = ~mask;
        st.h[0] = (st.h[0] & nmask) | g0;
        st.h[1] = (st.h[1] & nmask) | g1;
        st.h[2] = (st.h[2] & nmask) | g2;

        // h = (h + pad)
        const t0 = st.pad[0];
        const t1 = st.pad[1];
        st.h[0] += @truncate(u44, t0);
        carry = st.h[0] >> 44;
        st.h[0] = @truncate(u44, st.h[0]);
        st.h[1] += @truncate(u44, (t0 >> 44) | (t1 << 20)) + carry;
        carry = st.h[1] >> 44;
        st.h[1] = @truncate(u44, st.h[1]);
        st.h[2] += @truncate(u42, t1 >> 24) + carry;
        st.h[2] = @truncate(u42, st.h[2]);

        // mac = h % (2^128)
        st.h[0] |= st.h[1] << 44;
        st.h[1] = (st.h[1] >> 20) | (st.h[2] << 24);

        mem.writeIntLittle(u64, out[0..8], st.h[0]);
        mem.writeIntLittle(u64, out[8..16], st.h[1]);

        utils.secureZero(u8, @ptrCast([*]u8, st)[0..@sizeOf(Poly1305)]);
    }

    pub fn create(out: *[mac_length]u8, msg: []const u8, key: *const [key_length]u8) void {
        var st = Poly1305.init(key);
        st.update(msg);
        st.final(out);
    }
};

test "poly1305 rfc7439 vector1" {
    const expected_mac = "\xa8\x06\x1d\xc1\x30\x51\x36\xc6\xc2\x2b\x8b\xaf\x0c\x01\x27\xa9";

    const msg = "Cryptographic Forum Research Group";
    const key = "\x85\xd6\xbe\x78\x57\x55\x6d\x33\x7f\x44\x52\xfe\x42\xd5\x06\xa8" ++
        "\x01\x03\x80\x8a\xfb\x0d\xb2\xfd\x4a\xbf\xf6\xaf\x41\x49\xf5\x1b";

    var mac: [16]u8 = undefined;
    Poly1305.create(mac[0..], msg, key);

    std.testing.expectEqualSlices(u8, expected_mac, &mac);
}
