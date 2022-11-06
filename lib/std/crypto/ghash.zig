const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const utils = std.crypto.utils;

const Precomp = u128;

/// GHASH is a universal hash function that features multiplication
/// by a fixed parameter within a Galois field.
///
/// It is not a general purpose hash function - The key must be secret, unpredictable and never reused.
///
/// GHASH is typically used to compute the authentication tag in the AES-GCM construction.
pub const Ghash = struct {
    pub const block_length: usize = 16;
    pub const mac_length = 16;
    pub const key_length = 16;

    const pc_count = if (builtin.mode != .ReleaseSmall) 16 else 2;
    const agg_2_treshold = 5 * block_length;
    const agg_4_treshold = 22 * block_length;
    const agg_8_treshold = 84 * block_length;
    const agg_16_treshold = 328 * block_length;

    hx: [pc_count]Precomp,
    acc: u128 = 0,

    leftover: usize = 0,
    buf: [block_length]u8 align(16) = undefined,

    /// Initialize the GHASH state with a key, and a minimum number of block count.
    pub fn initForBlockCount(key: *const [key_length]u8, block_count: usize) Ghash {
        const h0 = mem.readIntBig(u128, key[0..16]);

        // We keep the values encoded as in GCM, not Polyval, i.e. without reversing the bits.
        // This is fine, but the reversed result would be shifted by 1 bit. So, we shift h
        // to compensate.
        const carry = ((@as(u128, 0xc2) << 120) | 1) & (@as(u128, 0) -% (h0 >> 127));
        const h = (h0 << 1) ^ carry;

        var hx: [pc_count]Precomp = undefined;
        hx[0] = h;
        if (block_count >= agg_2_treshold) {
            hx[1] = gcmReduce(clsq128(hx[0])); // h^2
        }
        if (builtin.mode != .ReleaseSmall) {
            if (block_count >= agg_4_treshold) {
                hx[2] = gcmReduce(clmul128(hx[1], h)); // h^3
                hx[3] = gcmReduce(clsq128(hx[1])); // h^4 = h^2^2
            }
            if (block_count >= agg_8_treshold) {
                hx[4] = gcmReduce(clmul128(hx[3], h)); // h^5
                hx[5] = gcmReduce(clsq128(hx[2])); // h^6 = h^3^2
                hx[6] = gcmReduce(clmul128(hx[5], h)); // h^7
                hx[7] = gcmReduce(clsq128(hx[3])); // h^8 = h^4^2
            }
            if (block_count >= agg_16_treshold) {
                hx[8] = gcmReduce(clmul128(hx[7], h)); // h^9
                hx[9] = gcmReduce(clsq128(hx[4])); // h^10 = h^5^2
                hx[10] = gcmReduce(clmul128(hx[9], h)); // h^11
                hx[11] = gcmReduce(clsq128(hx[5])); // h^12 = h^6^2
                hx[12] = gcmReduce(clmul128(hx[11], h)); // h^13
                hx[13] = gcmReduce(clsq128(hx[6])); // h^14 = h^7^2
                hx[14] = gcmReduce(clmul128(hx[13], h)); // h^15
                hx[15] = gcmReduce(clsq128(hx[7])); // h^16 = h^8^2
            }
        }
        return Ghash{ .hx = hx };
    }

    /// Initialize the GHASH state with a key.
    pub fn init(key: *const [key_length]u8) Ghash {
        return Ghash.initForBlockCount(key, math.maxInt(usize));
    }

    // Carryless multiplication of two 64-bit integers for x86_64.
    inline fn clmulPclmul(x: u64, y: u64) u128 {
        const product = asm (
            \\ vpclmulqdq $0x00, %[x], %[y], %[out]
            : [out] "=x" (-> @Vector(2, u64)),
            : [x] "x" (@bitCast(@Vector(2, u64), @as(u128, x))),
              [y] "x" (@bitCast(@Vector(2, u64), @as(u128, y))),
        );
        return (@as(u128, product[1]) << 64) | product[0];
    }

    // Carryless multiplication of two 64-bit integers for ARM crypto.
    inline fn clmulPmull(x: u64, y: u64) u128 {
        const product = asm (
            \\ pmull %[out].1q, %[x].1d, %[y].1d
            : [out] "=w" (-> @Vector(2, u64)),
            : [x] "w" (@bitCast(@Vector(2, u64), @as(u128, x))),
              [y] "w" (@bitCast(@Vector(2, u64), @as(u128, y))),
        );
        return (@as(u128, product[1]) << 64) | product[0];
    }

    // Software carryless multiplication of two 64-bit integers.
    fn clmulSoft(x: u64, y: u64) u128 {
        const x0 = x & 0x1111111111111110;
        const x1 = x & 0x2222222222222220;
        const x2 = x & 0x4444444444444440;
        const x3 = x & 0x8888888888888880;
        const y0 = y & 0x1111111111111111;
        const y1 = y & 0x2222222222222222;
        const y2 = y & 0x4444444444444444;
        const y3 = y & 0x8888888888888888;
        const z0 = (x0 * @as(u128, y0)) ^ (x1 * @as(u128, y3)) ^ (x2 * @as(u128, y2)) ^ (x3 * @as(u128, y1));
        const z1 = (x0 * @as(u128, y1)) ^ (x1 * @as(u128, y0)) ^ (x2 * @as(u128, y3)) ^ (x3 * @as(u128, y2));
        const z2 = (x0 * @as(u128, y2)) ^ (x1 * @as(u128, y1)) ^ (x2 * @as(u128, y0)) ^ (x3 * @as(u128, y3));
        const z3 = (x0 * @as(u128, y3)) ^ (x1 * @as(u128, y2)) ^ (x2 * @as(u128, y1)) ^ (x3 * @as(u128, y0));

        const x0_mask = @as(u64, 0) -% (x & 1);
        const x1_mask = @as(u64, 0) -% ((x >> 1) & 1);
        const x2_mask = @as(u64, 0) -% ((x >> 2) & 1);
        const x3_mask = @as(u64, 0) -% ((x >> 3) & 1);
        const extra = (x0_mask & y) ^ (@as(u128, x1_mask & y) << 1) ^
            (@as(u128, x2_mask & y) << 2) ^ (@as(u128, x3_mask & y) << 3);

        return (z0 & 0x11111111111111111111111111111111) ^
            (z1 & 0x22222222222222222222222222222222) ^
            (z2 & 0x44444444444444444444444444444444) ^
            (z3 & 0x88888888888888888888888888888888) ^ extra;
    }

    // Square a 128-bit integer in GF(2^128).
    fn clsq128(x: u128) u256 {
        const lo = @truncate(u64, x);
        const hi = @truncate(u64, x >> 64);
        const mid = lo ^ hi;
        const r_lo = clmul(lo, lo);
        const r_hi = clmul(hi, hi);
        const r_mid = clmul(mid, mid) ^ r_lo ^ r_hi;
        return (@as(u256, r_hi) << 128) ^ (@as(u256, r_mid) << 64) ^ r_lo;
    }

    // Multiply two 128-bit integers in GF(2^128).
    inline fn clmul128(x: u128, y: u128) u256 {
        const x_lo = @truncate(u64, x);
        const x_hi = @truncate(u64, x >> 64);
        const y_lo = @truncate(u64, y);
        const y_hi = @truncate(u64, y >> 64);
        const r_lo = clmul(x_lo, y_lo);
        const r_hi = clmul(x_hi, y_hi);
        const r_mid = clmul(x_lo ^ x_hi, y_lo ^ y_hi) ^ r_lo ^ r_hi;
        return (@as(u256, r_hi) << 128) ^ (@as(u256, r_mid) << 64) ^ r_lo;
    }

    // Reduce a 256-bit representative of a polynomial modulo the irreducible polynomial x^128 + x^127 + x^126 + x^121 + 1.
    // This is done *without reversing the bits*, using Shay Gueron's black magic demysticated here:
    // https://blog.quarkslab.com/reversing-a-finite-field-multiplication-optimization.html
    inline fn gcmReduce(x: u256) u128 {
        const p64 = (((1 << 121) | (1 << 126) | (1 << 127)) >> 64);
        const a = clmul(@truncate(u64, x), p64);
        const b = ((@truncate(u128, x) << 64) | (@truncate(u128, x) >> 64)) ^ a;
        const c = clmul(@truncate(u64, b), p64);
        const d = ((b << 64) | (b >> 64)) ^ c;
        return d ^ @truncate(u128, x >> 128);
    }

    const has_pclmul = std.Target.x86.featureSetHas(builtin.cpu.features, .pclmul);
    const has_avx = std.Target.x86.featureSetHas(builtin.cpu.features, .avx);
    const has_armaes = std.Target.aarch64.featureSetHas(builtin.cpu.features, .aes);
    const clmul = if (builtin.cpu.arch == .x86_64 and has_pclmul and has_avx) impl: {
        break :impl clmulPclmul;
    } else if (builtin.cpu.arch == .aarch64 and has_armaes) impl: {
        break :impl clmulPmull;
    } else impl: {
        break :impl clmulSoft;
    };

    // Process 16 byte blocks.
    fn blocks(st: *Ghash, msg: []const u8) void {
        assert(msg.len % 16 == 0); // GHASH blocks() expects full blocks
        var acc = st.acc;

        var i: usize = 0;

        if (builtin.mode != .ReleaseSmall and msg.len >= agg_16_treshold) {
            // 16-blocks aggregated reduction
            while (i + 256 <= msg.len) : (i += 256) {
                var u = clmul128(acc ^ mem.readIntBig(u128, msg[i..][0..16]), st.hx[15 - 0]);
                comptime var j = 1;
                inline while (j < 16) : (j += 1) {
                    u ^= clmul128(mem.readIntBig(u128, msg[i..][j * 16 ..][0..16]), st.hx[15 - j]);
                }
                acc = gcmReduce(u);
            }
        } else if (builtin.mode != .ReleaseSmall and msg.len >= agg_8_treshold) {
            // 8-blocks aggregated reduction
            while (i + 128 <= msg.len) : (i += 128) {
                var u = clmul128(acc ^ mem.readIntBig(u128, msg[i..][0..16]), st.hx[7 - 0]);
                comptime var j = 1;
                inline while (j < 8) : (j += 1) {
                    u ^= clmul128(mem.readIntBig(u128, msg[i..][j * 16 ..][0..16]), st.hx[7 - j]);
                }
                acc = gcmReduce(u);
            }
        } else if (builtin.mode != .ReleaseSmall and msg.len >= agg_4_treshold) {
            // 4-blocks aggregated reduction
            while (i + 64 <= msg.len) : (i += 64) {
                var u = clmul128(acc ^ mem.readIntBig(u128, msg[i..][0..16]), st.hx[3 - 0]);
                comptime var j = 1;
                inline while (j < 4) : (j += 1) {
                    u ^= clmul128(mem.readIntBig(u128, msg[i..][j * 16 ..][0..16]), st.hx[3 - j]);
                }
                acc = gcmReduce(u);
            }
        } else if (msg.len >= agg_2_treshold) {
            // 2-blocks aggregated reduction
            while (i + 32 <= msg.len) : (i += 32) {
                var u = clmul128(acc ^ mem.readIntBig(u128, msg[i..][0..16]), st.hx[1 - 0]);
                comptime var j = 1;
                inline while (j < 2) : (j += 1) {
                    u ^= clmul128(mem.readIntBig(u128, msg[i..][j * 16 ..][0..16]), st.hx[1 - j]);
                }
                acc = gcmReduce(u);
            }
        }
        // remaining blocks
        if (i < msg.len) {
            const n = (msg.len - i) / 16;
            var u = clmul128(acc ^ mem.readIntBig(u128, msg[i..][0..16]), st.hx[n - 1 - 0]);
            var j: usize = 1;
            while (j < n) : (j += 1) {
                u ^= clmul128(mem.readIntBig(u128, msg[i..][j * 16 ..][0..16]), st.hx[n - 1 - j]);
            }
            i += n * 16;
            acc = gcmReduce(u);
        }
        assert(i == msg.len);
        st.acc = acc;
    }

    /// Absorb a message into the GHASH state.
    pub fn update(st: *Ghash, m: []const u8) void {
        var mb = m;

        if (st.leftover > 0) {
            const want = math.min(block_length - st.leftover, mb.len);
            const mc = mb[0..want];
            for (mc) |x, i| {
                st.buf[st.leftover + i] = x;
            }
            mb = mb[want..];
            st.leftover += want;
            if (st.leftover < block_length) {
                return;
            }
            st.blocks(&st.buf);
            st.leftover = 0;
        }
        if (mb.len >= block_length) {
            const want = mb.len & ~(block_length - 1);
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

    /// Zero-pad to align the next input to the first byte of a block
    pub fn pad(st: *Ghash) void {
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

    /// Compute the GHASH of the entire input.
    pub fn final(st: *Ghash, out: *[mac_length]u8) void {
        st.pad();
        mem.writeIntBig(u128, out[0..16], st.acc);

        utils.secureZero(u8, @ptrCast([*]u8, st)[0..@sizeOf(Ghash)]);
    }

    /// Compute the GHASH of a message.
    pub fn create(out: *[mac_length]u8, msg: []const u8, key: *const [key_length]u8) void {
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
    try htest.assertEqual("889295fa746e8b174bf4ec80a65dea41", &out);

    st = Ghash.init(&key);
    st.update(m[0..100]);
    st.update(m[100..]);
    st.final(&out);
    try htest.assertEqual("889295fa746e8b174bf4ec80a65dea41", &out);
}
