/// RFC 4493 - The AES-CMAC Algorithm
/// https://www.rfc-editor.org/rfc/rfc4493
const std = @import("std");
const Aes128 = std.crypto.core.aes.Aes128;

pub fn AesCmac() type {
    return struct {
        const Self = @This();
        var ctx: std.crypto.core.aes.AesEncryptCtx(Aes128) = undefined;

        /// Create a new cmac context with the given key.
        pub fn init(key: [16]u8) Self {
            ctx = Aes128.initEnc(key);
            return Self{};
        }

        /// Generates a cmac from the given message.
        pub fn generate(self: Self, msg: []const u8) [16]u8 {
            _ = self;

            // make sub keys
            var k1 = [_]u8{0} ** 16;
            var k2 = [_]u8{0} ** 16;
            ctx.encrypt(&k1, &k1);
            makeKn(&k1, &k1);
            makeKn(&k2, &k1);

            var flag: bool = undefined;
            var Ml: [16]u8 = undefined;

            // rounds
            var n = (msg.len + 15) / 16;
            if (n == 0) {
                n = 1;
                flag = false;
            } else {
                flag = if (msg.len % 16 == 0) true else false;
            }

            if (flag) {
                Ml = xor(msg[16 * n - 16 ..], &k1);
            } else {
                var pad = padding(msg[16 * n - 16 ..], msg.len % 16);
                Ml = xor(&pad, &k2);
            }

            var X: [16]u8 = [_]u8{0} ** 16;
            var Y: [16]u8 = [_]u8{0} ** 16;
            var i: usize = 0;
            while (i < n - 1) : (i += 1) {
                Y = xor(msg[16 * i ..], &X);
                ctx.encrypt(&X, &Y);
            }
            Y = xor(&X, &Ml);

            var t: [16]u8 = undefined;
            ctx.encrypt(&t, &Y);

            return t;
        }

        fn padding(lb: []const u8, len: usize) [16]u8 {
            var pad: [16]u8 = [_]u8{0} ** 16;
            var i: usize = 0;
            while (i < 16) : (i += 1) {
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

        fn xor(a: []const u8, b: []const u8) [16]u8 {
            var res: [16]u8 = [_]u8{0} ** 16;
            for (b) |v, i| {
                res[i] = a[i] ^ v;
            }
            return res;
        }

        // make temporary keys K1 and K2
        fn makeKn(dst: []u8, src: []u8) void {
            const carry = src[15] >> 7;

            var cnext: u8 = 0;
            var i: usize = 16;
            while (i > 0) : (i -= 1) {
                const tmp = src[i - 1];
                dst[i - 1] = (tmp << 1) | cnext;
                cnext = tmp >> 7;
            }
            if (carry == 1) {
                dst[15] ^= 0x87;
            }
        }
    };
}

const testing = std.testing;

test "AesCmac - Example 1: len = 0" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    const cmac = AesCmac().init(key);

    var msg1: [0]u8 = undefined;
    const exp1 = [_]u8{
        0xbb, 0x1d, 0x69, 0x29, 0xe9, 0x59, 0x37, 0x28, 0x7f, 0xa3, 0x7d, 0x12, 0x9b, 0x75, 0x67, 0x46,
    };
    const out1 = cmac.generate(&msg1);
    try testing.expectEqualSlices(u8, &out1, &exp1);
}

test "AesCmac - Example 2: len = 16" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    const cmac = AesCmac().init(key);

    const msg2 = [_]u8{
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
    };
    const exp2 = [_]u8{
        0x07, 0x0a, 0x16, 0xb4, 0x6b, 0x4d, 0x41, 0x44, 0xf7, 0x9b, 0xdd, 0x9d, 0xd0, 0x4a, 0x28, 0x7c,
    };
    const out2 = cmac.generate(&msg2);
    try testing.expectEqualSlices(u8, &out2, &exp2);
}

test "AesCmac - Example 3: len = 40" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    const cmac = AesCmac().init(key);

    const msg3 = [_]u8{
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
        0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
        0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11,
    };
    const exp3 = [_]u8{
        0xdf, 0xa6, 0x67, 0x47, 0xde, 0x9a, 0xe6, 0x30, 0x30, 0xca, 0x32, 0x61, 0x14, 0x97, 0xc8, 0x27,
    };
    const out3 = cmac.generate(&msg3);
    try testing.expectEqualSlices(u8, &out3, &exp3);
}

test "AesCmac - Example 4: len = 64" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    const cmac = AesCmac().init(key);

    const msg4 = [_]u8{
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
        0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
        0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11, 0xe5, 0xfb, 0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef,
        0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17, 0xad, 0x2b, 0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10,
    };
    const exp4 = [_]u8{
        0x51, 0xf0, 0xbe, 0xbf, 0x7e, 0x3b, 0x9d, 0x92, 0xfc, 0x49, 0x74, 0x17, 0x79, 0x36, 0x3c, 0xfe,
    };
    const out4 = cmac.generate(&msg4);
    try testing.expectEqualSlices(u8, &out4, &exp4);
}
