// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
const std = @import("../std.zig");
const mem = std.mem;
const math = std.math;
const debug = std.debug;
const htest = @import("test.zig");

pub const Sha3_224 = Keccak(224, 0x06);
pub const Sha3_256 = Keccak(256, 0x06);
pub const Sha3_384 = Keccak(384, 0x06);
pub const Sha3_512 = Keccak(512, 0x06);
pub const Keccak_256 = Keccak(256, 0x01);
pub const Keccak_512 = Keccak(512, 0x01);

fn Keccak(comptime bits: usize, comptime delim: u8) type {
    return struct {
        const Self = @This();
        pub const block_length = 200;
        pub const digest_length = bits / 8;
        pub const Options = struct {};

        s: [200]u8,
        offset: usize,
        rate: usize,

        pub fn init(options: Options) Self {
            return Self{ .s = [_]u8{0} ** 200, .offset = 0, .rate = 200 - (bits / 4) };
        }

        pub fn hash(b: []const u8, out: *[digest_length]u8, options: Options) void {
            var d = Self.init(options);
            d.update(b);
            d.final(out);
        }

        pub fn update(d: *Self, b: []const u8) void {
            var ip: usize = 0;
            var len = b.len;
            var rate = d.rate - d.offset;
            var offset = d.offset;

            // absorb
            while (len >= rate) {
                for (d.s[offset .. offset + rate]) |*r, i|
                    r.* ^= b[ip..][i];

                keccakF(1600, &d.s);

                ip += rate;
                len -= rate;
                rate = d.rate;
                offset = 0;
            }

            for (d.s[offset .. offset + len]) |*r, i|
                r.* ^= b[ip..][i];

            d.offset = offset + len;
        }

        pub fn final(d: *Self, out: *[digest_length]u8) void {
            // padding
            d.s[d.offset] ^= delim;
            d.s[d.rate - 1] ^= 0x80;

            keccakF(1600, &d.s);

            // squeeze
            var op: usize = 0;
            var len: usize = bits / 8;

            while (len >= d.rate) {
                mem.copy(u8, out[op..], d.s[0..d.rate]);
                keccakF(1600, &d.s);
                op += d.rate;
                len -= d.rate;
            }

            mem.copy(u8, out[op..], d.s[0..len]);
        }
    };
}

const RC = [_]u64{
    0x0000000000000001, 0x0000000000008082, 0x800000000000808a, 0x8000000080008000,
    0x000000000000808b, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008a, 0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
    0x000000008000808b, 0x800000000000008b, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800a, 0x800000008000000a,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
};

const ROTC = [_]usize{
    1, 3, 6, 10, 15, 21, 28, 36, 45, 55, 2, 14, 27, 41, 56, 8, 25, 43, 62, 18, 39, 61, 20, 44,
};

const PIL = [_]usize{
    10, 7, 11, 17, 18, 3, 5, 16, 8, 21, 24, 4, 15, 23, 19, 13, 12, 2, 20, 14, 22, 9, 6, 1,
};

const M5 = [_]usize{
    0, 1, 2, 3, 4, 0, 1, 2, 3, 4,
};

fn keccakF(comptime F: usize, d: *[F / 8]u8) void {
    const B = F / 25;
    const no_rounds = comptime x: {
        break :x 12 + 2 * math.log2(B);
    };

    var s = [_]u64{0} ** 25;
    var t = [_]u64{0} ** 1;
    var c = [_]u64{0} ** 5;

    for (s) |*r, i| {
        r.* = mem.readIntLittle(u64, d[8 * i ..][0..8]);
    }

    comptime var x: usize = 0;
    comptime var y: usize = 0;
    for (RC[0..no_rounds]) |round| {
        // theta
        x = 0;
        inline while (x < 5) : (x += 1) {
            c[x] = s[x] ^ s[x + 5] ^ s[x + 10] ^ s[x + 15] ^ s[x + 20];
        }
        x = 0;
        inline while (x < 5) : (x += 1) {
            t[0] = c[M5[x + 4]] ^ math.rotl(u64, c[M5[x + 1]], @as(usize, 1));
            y = 0;
            inline while (y < 5) : (y += 1) {
                s[x + y * 5] ^= t[0];
            }
        }

        // rho+pi
        t[0] = s[1];
        x = 0;
        inline while (x < 24) : (x += 1) {
            c[0] = s[PIL[x]];
            s[PIL[x]] = math.rotl(u64, t[0], ROTC[x]);
            t[0] = c[0];
        }

        // chi
        y = 0;
        inline while (y < 5) : (y += 1) {
            x = 0;
            inline while (x < 5) : (x += 1) {
                c[x] = s[x + y * 5];
            }
            x = 0;
            inline while (x < 5) : (x += 1) {
                s[x + y * 5] = c[x] ^ (~c[M5[x + 1]] & c[M5[x + 2]]);
            }
        }

        // iota
        s[0] ^= round;
    }

    for (s) |r, i| {
        mem.writeIntLittle(u64, d[8 * i ..][0..8], r);
    }
}

test "sha3-224 single" {
    htest.assertEqualHash(Sha3_224, "6b4e03423667dbb73b6e15454f0eb1abd4597f9a1b078e3f5b5a6bc7", "");
    htest.assertEqualHash(Sha3_224, "e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf", "abc");
    htest.assertEqualHash(Sha3_224, "543e6868e1666c1a643630df77367ae5a62a85070a51c14cbf665cbc", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha3-224 streaming" {
    var h = Sha3_224.init(.{});
    var out: [28]u8 = undefined;

    h.final(out[0..]);
    htest.assertEqual("6b4e03423667dbb73b6e15454f0eb1abd4597f9a1b078e3f5b5a6bc7", out[0..]);

    h = Sha3_224.init(.{});
    h.update("abc");
    h.final(out[0..]);
    htest.assertEqual("e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf", out[0..]);

    h = Sha3_224.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    htest.assertEqual("e642824c3f8cf24ad09234ee7d3c766fc9a3a5168d0c94ad73b46fdf", out[0..]);
}

test "sha3-256 single" {
    htest.assertEqualHash(Sha3_256, "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a", "");
    htest.assertEqualHash(Sha3_256, "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532", "abc");
    htest.assertEqualHash(Sha3_256, "916f6061fe879741ca6469b43971dfdb28b1a32dc36cb3254e812be27aad1d18", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha3-256 streaming" {
    var h = Sha3_256.init(.{});
    var out: [32]u8 = undefined;

    h.final(out[0..]);
    htest.assertEqual("a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a", out[0..]);

    h = Sha3_256.init(.{});
    h.update("abc");
    h.final(out[0..]);
    htest.assertEqual("3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532", out[0..]);

    h = Sha3_256.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    htest.assertEqual("3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532", out[0..]);
}

test "sha3-256 aligned final" {
    var block = [_]u8{0} ** Sha3_256.block_length;
    var out: [Sha3_256.digest_length]u8 = undefined;

    var h = Sha3_256.init(.{});
    h.update(&block);
    h.final(out[0..]);
}

test "sha3-384 single" {
    const h1 = "0c63a75b845e4f7d01107d852e4c2485c51a50aaaa94fc61995e71bbee983a2ac3713831264adb47fb6bd1e058d5f004";
    htest.assertEqualHash(Sha3_384, h1, "");
    const h2 = "ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b298d88cea927ac7f539f1edf228376d25";
    htest.assertEqualHash(Sha3_384, h2, "abc");
    const h3 = "79407d3b5916b59c3e30b09822974791c313fb9ecc849e406f23592d04f625dc8c709b98b43b3852b337216179aa7fc7";
    htest.assertEqualHash(Sha3_384, h3, "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha3-384 streaming" {
    var h = Sha3_384.init(.{});
    var out: [48]u8 = undefined;

    const h1 = "0c63a75b845e4f7d01107d852e4c2485c51a50aaaa94fc61995e71bbee983a2ac3713831264adb47fb6bd1e058d5f004";
    h.final(out[0..]);
    htest.assertEqual(h1, out[0..]);

    const h2 = "ec01498288516fc926459f58e2c6ad8df9b473cb0fc08c2596da7cf0e49be4b298d88cea927ac7f539f1edf228376d25";
    h = Sha3_384.init(.{});
    h.update("abc");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);

    h = Sha3_384.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);
}

test "sha3-512 single" {
    const h1 = "a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26";
    htest.assertEqualHash(Sha3_512, h1, "");
    const h2 = "b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0";
    htest.assertEqualHash(Sha3_512, h2, "abc");
    const h3 = "afebb2ef542e6579c50cad06d2e578f9f8dd6881d7dc824d26360feebf18a4fa73e3261122948efcfd492e74e82e2189ed0fb440d187f382270cb455f21dd185";
    htest.assertEqualHash(Sha3_512, h3, "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "sha3-512 streaming" {
    var h = Sha3_512.init(.{});
    var out: [64]u8 = undefined;

    const h1 = "a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26";
    h.final(out[0..]);
    htest.assertEqual(h1, out[0..]);

    const h2 = "b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0";
    h = Sha3_512.init(.{});
    h.update("abc");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);

    h = Sha3_512.init(.{});
    h.update("a");
    h.update("b");
    h.update("c");
    h.final(out[0..]);
    htest.assertEqual(h2, out[0..]);
}

test "sha3-512 aligned final" {
    var block = [_]u8{0} ** Sha3_512.block_length;
    var out: [Sha3_512.digest_length]u8 = undefined;

    var h = Sha3_512.init(.{});
    h.update(&block);
    h.final(out[0..]);
}

test "keccak-256 single" {
    htest.assertEqualHash(Keccak_256, "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470", "");
    htest.assertEqualHash(Keccak_256, "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45", "abc");
    htest.assertEqualHash(Keccak_256, "f519747ed599024f3882238e5ab43960132572b7345fbeb9a90769dafd21ad67", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}

test "keccak-512 single" {
    htest.assertEqualHash(Keccak_512, "0eab42de4c3ceb9235fc91acffe746b29c29a8c366b7c60e4e67c466f36a4304c00fa9caf9d87976ba469bcbe06713b435f091ef2769fb160cdab33d3670680e", "");
    htest.assertEqualHash(Keccak_512, "18587dc2ea106b9a1563e32b3312421ca164c7f1f07bc922a9c83d77cea3a1e5d0c69910739025372dc14ac9642629379540c17e2a65b19d77aa511a9d00bb96", "abc");
    htest.assertEqualHash(Keccak_512, "ac2fb35251825d3aa48468a9948c0a91b8256f6d97d8fa4160faff2dd9dfcc24f3f1db7a983dad13d53439ccac0b37e24037e7b95f80f59f37a2f683c4ba4682", "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu");
}
