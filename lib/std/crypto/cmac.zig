const std = @import("std");
const crypto = std.crypto;
const mem = std.mem;

/// CMAC with AES-128 - RFC 4493 https://www.rfc-editor.org/rfc/rfc4493
pub const CmacAes128 = Cmac(crypto.core.aes.Aes128);

/// NIST Special Publication 800-38B - The CMAC Mode for Authentication
/// https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-38b.pdf
pub fn Cmac(comptime BlockCipher: type) type {
    const BlockCipherCtx = @typeInfo(@TypeOf(BlockCipher.initEnc)).@"fn".return_type.?;
    const Block = [BlockCipher.block.block_length]u8;

    return struct {
        const Self = @This();
        pub const key_length = BlockCipher.key_bits / 8;
        pub const block_length = BlockCipher.block.block_length;
        pub const mac_length = block_length;

        cipher_ctx: BlockCipherCtx,
        k1: Block,
        k2: Block,
        buf: Block = [_]u8{0} ** block_length,
        pos: usize = 0,

        pub fn create(out: *[mac_length]u8, msg: []const u8, key: *const [key_length]u8) void {
            var ctx = Self.init(key);
            ctx.update(msg);
            ctx.final(out);
        }

        pub fn init(key: *const [key_length]u8) Self {
            const cipher_ctx = BlockCipher.initEnc(key.*);
            const zeros = [_]u8{0} ** block_length;
            var k1: Block = undefined;
            cipher_ctx.encrypt(&k1, &zeros);
            k1 = double(k1);
            return Self{
                .cipher_ctx = cipher_ctx,
                .k1 = k1,
                .k2 = double(k1),
            };
        }

        pub fn update(self: *Self, msg: []const u8) void {
            const left = block_length - self.pos;
            var m = msg;
            if (m.len > left) {
                for (self.buf[self.pos..], 0..) |*b, i| b.* ^= m[i];
                m = m[left..];
                self.cipher_ctx.encrypt(&self.buf, &self.buf);
                self.pos = 0;
            }
            while (m.len > block_length) {
                for (self.buf[0..block_length], 0..) |*b, i| b.* ^= m[i];
                m = m[block_length..];
                self.cipher_ctx.encrypt(&self.buf, &self.buf);
                self.pos = 0;
            }
            if (m.len > 0) {
                for (self.buf[self.pos..][0..m.len], 0..) |*b, i| b.* ^= m[i];
                self.pos += m.len;
            }
        }

        pub fn final(self: *Self, out: *[mac_length]u8) void {
            var mac = self.k1;
            if (self.pos < block_length) {
                mac = self.k2;
                mac[self.pos] ^= 0x80;
            }
            for (&mac, 0..) |*b, i| b.* ^= self.buf[i];
            self.cipher_ctx.encrypt(out, &mac);
        }

        fn double(l: Block) Block {
            const Int = std.meta.Int(.unsigned, block_length * 8);
            const l_ = mem.readInt(Int, &l, .big);
            const l_2 = switch (block_length) {
                8 => (l_ << 1) ^ (0x1b & -%(l_ >> 63)), // mod x^64 + x^4 + x^3 + x + 1
                16 => (l_ << 1) ^ (0x87 & -%(l_ >> 127)), // mod x^128 + x^7 + x^2 + x + 1
                32 => (l_ << 1) ^ (0x0425 & -%(l_ >> 255)), // mod x^256 + x^10 + x^5 + x^2 + 1
                64 => (l_ << 1) ^ (0x0125 & -%(l_ >> 511)), // mod x^512 + x^8 + x^5 + x^2 + 1
                else => @compileError("unsupported block length"),
            };
            var l2: Block = undefined;
            mem.writeInt(Int, &l2, l_2, .big);
            return l2;
        }
    };
}

const testing = std.testing;

test "CmacAes128 - Example 1: len = 0" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    var msg: [0]u8 = undefined;
    const exp = [_]u8{
        0xbb, 0x1d, 0x69, 0x29, 0xe9, 0x59, 0x37, 0x28, 0x7f, 0xa3, 0x7d, 0x12, 0x9b, 0x75, 0x67, 0x46,
    };
    var out: [CmacAes128.mac_length]u8 = undefined;
    CmacAes128.create(&out, &msg, &key);
    try testing.expectEqualSlices(u8, &out, &exp);
}

test "CmacAes128 - Example 2: len = 16" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    const msg = [_]u8{
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
    };
    const exp = [_]u8{
        0x07, 0x0a, 0x16, 0xb4, 0x6b, 0x4d, 0x41, 0x44, 0xf7, 0x9b, 0xdd, 0x9d, 0xd0, 0x4a, 0x28, 0x7c,
    };
    var out: [CmacAes128.mac_length]u8 = undefined;
    CmacAes128.create(&out, &msg, &key);
    try testing.expectEqualSlices(u8, &out, &exp);
}

test "CmacAes128 - Example 3: len = 40" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    const msg = [_]u8{
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
        0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
        0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11,
    };
    const exp = [_]u8{
        0xdf, 0xa6, 0x67, 0x47, 0xde, 0x9a, 0xe6, 0x30, 0x30, 0xca, 0x32, 0x61, 0x14, 0x97, 0xc8, 0x27,
    };
    var out: [CmacAes128.mac_length]u8 = undefined;
    CmacAes128.create(&out, &msg, &key);
    try testing.expectEqualSlices(u8, &out, &exp);
}

test "CmacAes128 - Example 4: len = 64" {
    const key = [_]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };
    const msg = [_]u8{
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
        0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
        0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11, 0xe5, 0xfb, 0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef,
        0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17, 0xad, 0x2b, 0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10,
    };
    const exp = [_]u8{
        0x51, 0xf0, 0xbe, 0xbf, 0x7e, 0x3b, 0x9d, 0x92, 0xfc, 0x49, 0x74, 0x17, 0x79, 0x36, 0x3c, 0xfe,
    };
    var out: [CmacAes128.mac_length]u8 = undefined;
    CmacAes128.create(&out, &msg, &key);
    try testing.expectEqualSlices(u8, &out, &exp);
}
