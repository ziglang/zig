/// RFC 4493 - The AES-CMAC Algorithm
/// https://www.rfc-editor.org/rfc/rfc4493
const std = @import("std");
const mem = std.mem;
const Aes = std.crypto.core.aes;

pub const AesCmac = Cmac();

pub fn Cmac() type {
    return struct {
        const Self = @This();
        pub const key_length = Aes.Block.block_length;
        pub const mac_length = Aes.Block.block_length;
        ctx: std.crypto.core.aes.AesEncryptCtx(Aes.Aes128),

        pub fn create(out: *[mac_length]u8, msg: []const u8, key: []const u8) void {
            var scratch: [key_length]u8 = undefined;
            if (key.len > key_length) {
                mem.copy(u8, scratch[0..], key[0..key_length]);
            } else {
                mem.copy(u8, scratch[0..], key);
            }
            const ctx = Self.init(scratch);
            ctx.generate(out, msg);
        }

        /// Create a new cmac context with the given key.
        pub fn init(key: [key_length]u8) Self {
            return Self{ .ctx = Aes.Aes128.initEnc(key) };
        }

        /// Generates a cmac from the given message.
        pub fn generate(self: Self, out: *[mac_length]u8, msg: []const u8) void {

            // make sub keys
            var k1 = [_]u8{0} ** Aes.Block.block_length;
            var k2 = [_]u8{0} ** Aes.Block.block_length;
            self.ctx.encrypt(&k1, &k1);
            const t1 = k1[Aes.Block.block_length - 1];
            shiftBitLeft(&k1, &k1);
            k1[Aes.Block.block_length - 1] ^= 0x87 & -%(t1 >> 7);
            const t2 = k1[Aes.Block.block_length - 1];
            shiftBitLeft(&k2, &k1);
            k2[Aes.Block.block_length - 1] ^= 0x87 & -%(t2 >> 7);

            var flag: bool = undefined;
            var Ml: [Aes.Block.block_length]u8 = undefined;

            // rounds
            var n = (msg.len + 15) / Aes.Block.block_length;
            if (n == 0) {
                n = 1;
                flag = false;
            } else {
                flag = if (msg.len % Aes.Block.block_length == 0) true else false;
            }

            if (flag) {
                Ml = xor(msg[Aes.Block.block_length * n - Aes.Block.block_length ..], &k1);
            } else {
                var pad = padding(msg[Aes.Block.block_length * n - Aes.Block.block_length ..], msg.len % Aes.Block.block_length);
                Ml = xor(&pad, &k2);
            }

            var X: [Aes.Block.block_length]u8 = [_]u8{0} ** Aes.Block.block_length;
            var Y: [Aes.Block.block_length]u8 = [_]u8{0} ** Aes.Block.block_length;
            var i: usize = 0;
            while (i < n - 1) : (i += 1) {
                Y = xor(msg[Aes.Block.block_length * i ..], &X);
                self.ctx.encrypt(&X, &Y);
            }
            Y = xor(&X, &Ml);

            // var t: [Aes.Block.block_length]u8 = undefined;
            self.ctx.encrypt(out, &Y);
        }

        fn padding(lb: []const u8, len: usize) [Aes.Block.block_length]u8 {
            var pad: [Aes.Block.block_length]u8 = [_]u8{0} ** Aes.Block.block_length;
            var i: usize = 0;
            while (i < Aes.Block.block_length) : (i += 1) {
                if (i < len) {
                    pad[i] = lb[i];
                } else if (i == len) {
                    pad[i] = 0x80;
                } else {
                    break;
                }
            }
            return pad;
        }

        fn xor(a: []const u8, b: []const u8) [Aes.Block.block_length]u8 {
            var res: [Aes.Block.block_length]u8 = [_]u8{0} ** Aes.Block.block_length;
            for (b) |v, i| {
                res[i] = a[i] ^ v;
            }
            return res;
        }

        fn shiftBitLeft(dst: []u8, src: []u8) void {
            var cnext: u8 = 0;
            var i: usize = Aes.Block.block_length;
            while (i > 0) : (i -= 1) {
                const tmp = src[i - 1];
                dst[i - 1] = (tmp << 1) | cnext;
                cnext = tmp >> 7;
            }
        }
    };
}

const testing = std.testing;

test "AesCmac - Example 1: len = 0" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    const ctx = AesCmac.init(key);

    var msg: [0]u8 = undefined;
    const exp = [_]u8{
        0xbb, 0x1d, 0x69, 0x29, 0xe9, 0x59, 0x37, 0x28, 0x7f, 0xa3, 0x7d, 0x12, 0x9b, 0x75, 0x67, 0x46,
    };
    var out: [AesCmac.mac_length]u8 = undefined;
    ctx.generate(&out, &msg);
    try testing.expectEqualSlices(u8, &out, &exp);
}

test "AesCmac - Example 2: len = 16" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    const ctx = AesCmac.init(key);

    const msg = [_]u8{
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
    };
    const exp = [_]u8{
        0x07, 0x0a, 0x16, 0xb4, 0x6b, 0x4d, 0x41, 0x44, 0xf7, 0x9b, 0xdd, 0x9d, 0xd0, 0x4a, 0x28, 0x7c,
    };
    var out: [AesCmac.mac_length]u8 = undefined;
    ctx.generate(&out, &msg);
    try testing.expectEqualSlices(u8, &out, &exp);
}

test "AesCmac - Example 3: len = 40" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    const ctx = AesCmac.init(key);

    const msg = [_]u8{
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
        0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
        0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11,
    };
    const exp = [_]u8{
        0xdf, 0xa6, 0x67, 0x47, 0xde, 0x9a, 0xe6, 0x30, 0x30, 0xca, 0x32, 0x61, 0x14, 0x97, 0xc8, 0x27,
    };
    var out: [AesCmac.mac_length]u8 = undefined;
    ctx.generate(&out, &msg);
    try testing.expectEqualSlices(u8, &out, &exp);
}

test "AesCmac - Example 4: len = 64" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    const ctx = AesCmac.init(key);

    const msg = [_]u8{
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
        0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
        0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11, 0xe5, 0xfb, 0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef,
        0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17, 0xad, 0x2b, 0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10,
    };
    const exp = [_]u8{
        0x51, 0xf0, 0xbe, 0xbf, 0x7e, 0x3b, 0x9d, 0x92, 0xfc, 0x49, 0x74, 0x17, 0x79, 0x36, 0x3c, 0xfe,
    };
    var out: [AesCmac.mac_length]u8 = undefined;
    ctx.generate(&out, &msg);
    try testing.expectEqualSlices(u8, &out, &exp);
}

test "bench call" {
    const KiB = 1024;
    const Mac = AesCmac;
    var prng = std.rand.DefaultPrng.init(0);
    const random = prng.random();

    var in: [512 * KiB]u8 = undefined;
    random.bytes(in[0..]);

    const key_length = if (Mac.key_length == 0) 32 else Mac.key_length;
    var key: [key_length]u8 = undefined;
    random.bytes(key[0..]);

    var mac: [Mac.mac_length]u8 = undefined;
    Mac.create(mac[0..], in[0..], key[0..]);
    mem.doNotOptimizeAway(&mac);
}
