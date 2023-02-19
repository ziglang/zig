const std = @import("../std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const math = std.math;
const mem = std.mem;
const utils = std.crypto.utils;

const Precomp = u128;

/// GHASH is a universal hash function that uses multiplication by a fixed
/// parameter within a Galois field.
///
/// It is not a general purpose hash function - The key must be secret, unpredictable and never reused.
///
/// GHASH is typically used to compute the authentication tag in the AES-GCM construction.
pub const Ghash = Hash(.Big, true);

/// POLYVAL is a universal hash function that uses multiplication by a fixed
/// parameter within a Galois field.
///
/// It is not a general purpose hash function - The key must be secret, unpredictable and never reused.
///
/// POLYVAL is typically used to compute the authentication tag in the AES-GCM-SIV construction.
pub const Polyval = Hash(.Little, false);

fn Hash(comptime endian: std.builtin.Endian, comptime shift_key: bool) type {
    return struct {
        const Self = @This();

        pub const block_length: usize = 16;
        pub const mac_length = 16;
        pub const key_length = 16;

        const pc_count = if (builtin.mode != .ReleaseSmall) 16 else 2;
        const agg_4_threshold = 22;
        const agg_8_threshold = 84;
        const agg_16_threshold = 328;

        // Before the Haswell architecture, the carryless multiplication instruction was
        // extremely slow. Even with 128-bit operands, using Karatsuba multiplication was
        // thus faster than a schoolbook multiplication.
        // This is no longer the case -- Modern CPUs, including ARM-based ones, have a fast
        // carryless multiplication instruction; using 4 multiplications is now faster than
        // 3 multiplications with extra shifts and additions.
        const mul_algorithm = if (builtin.cpu.arch == .x86) .karatsuba else .schoolbook;

        hx: [pc_count]Precomp,
        acc: u128 = 0,

        leftover: usize = 0,
        buf: [block_length]u8 align(16) = undefined,

        /// Initialize the GHASH state with a key, and a minimum number of block count.
        pub fn initForBlockCount(key: *const [key_length]u8, block_count: usize) Self {
            var h = mem.readInt(u128, key[0..16], endian);
            if (shift_key) {
                // Shift the key by 1 bit to the left & reduce for GCM.
                const carry = ((@as(u128, 0xc2) << 120) | 1) & (@as(u128, 0) -% (h >> 127));
                h = (h << 1) ^ carry;
            }
            var hx: [pc_count]Precomp = undefined;
            hx[0] = h;
            hx[1] = reduce(clsq128(hx[0])); // h^2

            if (builtin.mode != .ReleaseSmall) {
                hx[2] = reduce(clmul128(hx[1], h)); // h^3
                hx[3] = reduce(clsq128(hx[1])); // h^4 = h^2^2
                if (block_count >= agg_8_threshold) {
                    hx[4] = reduce(clmul128(hx[3], h)); // h^5
                    hx[5] = reduce(clsq128(hx[2])); // h^6 = h^3^2
                    hx[6] = reduce(clmul128(hx[5], h)); // h^7
                    hx[7] = reduce(clsq128(hx[3])); // h^8 = h^4^2
                }
                if (block_count >= agg_16_threshold) {
                    var i: usize = 8;
                    while (i < 16) : (i += 2) {
                        hx[i] = reduce(clmul128(hx[i - 1], h));
                        hx[i + 1] = reduce(clsq128(hx[i / 2]));
                    }
                }
            }
            return Self{ .hx = hx };
        }

        /// Initialize the GHASH state with a key.
        pub fn init(key: *const [key_length]u8) Self {
            return Self.initForBlockCount(key, math.maxInt(usize));
        }

        const Selector = enum { lo, hi, hi_lo };

        // Carryless multiplication of two 64-bit integers for x86_64.
        inline fn clmulPclmul(x: u128, y: u128, comptime half: Selector) u128 {
            switch (half) {
                .hi => {
                    const product = asm (
                        \\ vpclmulqdq $0x11, %[x], %[y], %[out]
                        : [out] "=x" (-> @Vector(2, u64)),
                        : [x] "x" (@bitCast(@Vector(2, u64), x)),
                          [y] "x" (@bitCast(@Vector(2, u64), y)),
                    );
                    return @bitCast(u128, product);
                },
                .lo => {
                    const product = asm (
                        \\ vpclmulqdq $0x00, %[x], %[y], %[out]
                        : [out] "=x" (-> @Vector(2, u64)),
                        : [x] "x" (@bitCast(@Vector(2, u64), x)),
                          [y] "x" (@bitCast(@Vector(2, u64), y)),
                    );
                    return @bitCast(u128, product);
                },
                .hi_lo => {
                    const product = asm (
                        \\ vpclmulqdq $0x10, %[x], %[y], %[out]
                        : [out] "=x" (-> @Vector(2, u64)),
                        : [x] "x" (@bitCast(@Vector(2, u64), x)),
                          [y] "x" (@bitCast(@Vector(2, u64), y)),
                    );
                    return @bitCast(u128, product);
                },
            }
        }

        // Carryless multiplication of two 64-bit integers for ARM crypto.
        inline fn clmulPmull(x: u128, y: u128, comptime half: Selector) u128 {
            switch (half) {
                .hi => {
                    const product = asm (
                        \\ pmull2 %[out].1q, %[x].2d, %[y].2d
                        : [out] "=w" (-> @Vector(2, u64)),
                        : [x] "w" (@bitCast(@Vector(2, u64), x)),
                          [y] "w" (@bitCast(@Vector(2, u64), y)),
                    );
                    return @bitCast(u128, product);
                },
                .lo => {
                    const product = asm (
                        \\ pmull %[out].1q, %[x].1d, %[y].1d
                        : [out] "=w" (-> @Vector(2, u64)),
                        : [x] "w" (@bitCast(@Vector(2, u64), x)),
                          [y] "w" (@bitCast(@Vector(2, u64), y)),
                    );
                    return @bitCast(u128, product);
                },
                .hi_lo => {
                    const product = asm (
                        \\ pmull %[out].1q, %[x].1d, %[y].1d
                        : [out] "=w" (-> @Vector(2, u64)),
                        : [x] "w" (@bitCast(@Vector(2, u64), x >> 64)),
                          [y] "w" (@bitCast(@Vector(2, u64), y)),
                    );
                    return @bitCast(u128, product);
                },
            }
        }

        // Software carryless multiplication of two 64-bit integers.
        fn clmulSoft(x_: u128, y_: u128, comptime half: Selector) u128 {
            const x = @truncate(u64, if (half == .hi or half == .hi_lo) x_ >> 64 else x_);
            const y = @truncate(u64, if (half == .hi) y_ >> 64 else y_);

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

        const I256 = struct {
            hi: u128,
            lo: u128,
            mid: u128,
        };

        inline fn xor256(x: *I256, y: I256) void {
            x.* = I256{
                .hi = x.hi ^ y.hi,
                .lo = x.lo ^ y.lo,
                .mid = x.mid ^ y.mid,
            };
        }

        // Square a 128-bit integer in GF(2^128).
        fn clsq128(x: u128) I256 {
            return .{
                .hi = clmul(x, x, .hi),
                .lo = clmul(x, x, .lo),
                .mid = 0,
            };
        }

        // Multiply two 128-bit integers in GF(2^128).
        inline fn clmul128(x: u128, y: u128) I256 {
            if (mul_algorithm == .karatsuba) {
                const x_hi = @truncate(u64, x >> 64);
                const y_hi = @truncate(u64, y >> 64);
                const r_lo = clmul(x, y, .lo);
                const r_hi = clmul(x, y, .hi);
                const r_mid = clmul(x ^ x_hi, y ^ y_hi, .lo) ^ r_lo ^ r_hi;
                return .{
                    .hi = r_hi,
                    .lo = r_lo,
                    .mid = r_mid,
                };
            } else {
                return .{
                    .hi = clmul(x, y, .hi),
                    .lo = clmul(x, y, .lo),
                    .mid = clmul(x, y, .hi_lo) ^ clmul(y, x, .hi_lo),
                };
            }
        }

        // Reduce a 256-bit representative of a polynomial modulo the irreducible polynomial x^128 + x^127 + x^126 + x^121 + 1.
        // This is done using Shay Gueron's black magic demysticated here:
        // https://blog.quarkslab.com/reversing-a-finite-field-multiplication-optimization.html
        inline fn reduce(x: I256) u128 {
            const hi = x.hi ^ (x.mid >> 64);
            const lo = x.lo ^ (x.mid << 64);
            const p64 = (((1 << 121) | (1 << 126) | (1 << 127)) >> 64);
            const a = clmul(lo, p64, .lo);
            const b = ((lo << 64) | (lo >> 64)) ^ a;
            const c = clmul(b, p64, .lo);
            const d = ((b << 64) | (b >> 64)) ^ c;
            return d ^ hi;
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
        fn blocks(st: *Self, msg: []const u8) void {
            assert(msg.len % 16 == 0); // GHASH blocks() expects full blocks
            var acc = st.acc;

            var i: usize = 0;

            if (builtin.mode != .ReleaseSmall and msg.len >= agg_16_threshold * block_length) {
                // 16-blocks aggregated reduction
                while (i + 256 <= msg.len) : (i += 256) {
                    var u = clmul128(acc ^ mem.readInt(u128, msg[i..][0..16], endian), st.hx[15 - 0]);
                    comptime var j = 1;
                    inline while (j < 16) : (j += 1) {
                        xor256(&u, clmul128(mem.readInt(u128, msg[i..][j * 16 ..][0..16], endian), st.hx[15 - j]));
                    }
                    acc = reduce(u);
                }
            } else if (builtin.mode != .ReleaseSmall and msg.len >= agg_8_threshold * block_length) {
                // 8-blocks aggregated reduction
                while (i + 128 <= msg.len) : (i += 128) {
                    var u = clmul128(acc ^ mem.readInt(u128, msg[i..][0..16], endian), st.hx[7 - 0]);
                    comptime var j = 1;
                    inline while (j < 8) : (j += 1) {
                        xor256(&u, clmul128(mem.readInt(u128, msg[i..][j * 16 ..][0..16], endian), st.hx[7 - j]));
                    }
                    acc = reduce(u);
                }
            } else if (builtin.mode != .ReleaseSmall and msg.len >= agg_4_threshold * block_length) {
                // 4-blocks aggregated reduction
                while (i + 64 <= msg.len) : (i += 64) {
                    var u = clmul128(acc ^ mem.readInt(u128, msg[i..][0..16], endian), st.hx[3 - 0]);
                    comptime var j = 1;
                    inline while (j < 4) : (j += 1) {
                        xor256(&u, clmul128(mem.readInt(u128, msg[i..][j * 16 ..][0..16], endian), st.hx[3 - j]));
                    }
                    acc = reduce(u);
                }
            }
            // 2-blocks aggregated reduction
            while (i + 32 <= msg.len) : (i += 32) {
                var u = clmul128(acc ^ mem.readInt(u128, msg[i..][0..16], endian), st.hx[1 - 0]);
                comptime var j = 1;
                inline while (j < 2) : (j += 1) {
                    xor256(&u, clmul128(mem.readInt(u128, msg[i..][j * 16 ..][0..16], endian), st.hx[1 - j]));
                }
                acc = reduce(u);
            }
            // remaining blocks
            if (i < msg.len) {
                const u = clmul128(acc ^ mem.readInt(u128, msg[i..][0..16], endian), st.hx[0]);
                acc = reduce(u);
                i += 16;
            }
            assert(i == msg.len);
            st.acc = acc;
        }

        /// Absorb a message into the GHASH state.
        pub fn update(st: *Self, m: []const u8) void {
            var mb = m;

            if (st.leftover > 0) {
                const want = math.min(block_length - st.leftover, mb.len);
                const mc = mb[0..want];
                for (mc, 0..) |x, i| {
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
                for (mb, 0..) |x, i| {
                    st.buf[st.leftover + i] = x;
                }
                st.leftover += mb.len;
            }
        }

        /// Zero-pad to align the next input to the first byte of a block
        pub fn pad(st: *Self) void {
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
        pub fn final(st: *Self, out: *[mac_length]u8) void {
            st.pad();
            mem.writeInt(u128, out[0..16], st.acc, endian);

            utils.secureZero(u8, @ptrCast([*]u8, st)[0..@sizeOf(Self)]);
        }

        /// Compute the GHASH of a message.
        pub fn create(out: *[mac_length]u8, msg: []const u8, key: *const [key_length]u8) void {
            var st = Self.init(key);
            st.update(msg);
            st.final(out);
        }
    };
}

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

test "ghash2" {
    var key: [16]u8 = undefined;
    var i: usize = 0;
    while (i < key.len) : (i += 1) {
        key[i] = @intCast(u8, i * 15 + 1);
    }
    const tvs = [_]struct { len: usize, hash: [:0]const u8 }{
        .{ .len = 5263, .hash = "b9395f37c131cd403a327ccf82ec016a" },
        .{ .len = 1361, .hash = "8c24cb3664e9a36e32ddef0c8178ab33" },
        .{ .len = 1344, .hash = "015d7243b52d62eee8be33a66a9658cc" },
        .{ .len = 1000, .hash = "56e148799944193f351f2014ef9dec9d" },
        .{ .len = 512, .hash = "ca4882ce40d37546185c57709d17d1ca" },
        .{ .len = 128, .hash = "d36dc3aac16cfe21a75cd5562d598c1c" },
        .{ .len = 111, .hash = "6e2bea99700fd19cf1694e7b56543320" },
        .{ .len = 80, .hash = "aa28f4092a7cca155f3de279cf21aa17" },
        .{ .len = 16, .hash = "9d7eb5ed121a52a4b0996e4ec9b98911" },
        .{ .len = 1, .hash = "968a203e5c7a98b6d4f3112f4d6b89a7" },
        .{ .len = 0, .hash = "00000000000000000000000000000000" },
    };
    inline for (tvs) |tv| {
        var m: [tv.len]u8 = undefined;
        i = 0;
        while (i < m.len) : (i += 1) {
            m[i] = @truncate(u8, i % 254 + 1);
        }
        var st = Ghash.init(&key);
        st.update(&m);
        var out: [16]u8 = undefined;
        st.final(&out);
        try htest.assertEqual(tv.hash, &out);
    }
}

test "polyval" {
    const key = [_]u8{0x42} ** 16;
    const m = [_]u8{0x69} ** 256;

    var st = Polyval.init(&key);
    st.update(&m);
    var out: [16]u8 = undefined;
    st.final(&out);
    try htest.assertEqual("0713c82b170eef25c8955ddf72c85ccb", &out);

    st = Polyval.init(&key);
    st.update(m[0..100]);
    st.update(m[100..]);
    st.final(&out);
    try htest.assertEqual("0713c82b170eef25c8955ddf72c85ccb", &out);
}
