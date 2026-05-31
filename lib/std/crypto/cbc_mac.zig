const std = @import("std");
const crypto = std.crypto;
const mem = std.mem;

/// CBC-MAC with AES-128 - FIPS 113 https://csrc.nist.gov/publications/detail/fips/113/archive/1985-05-30
pub const CbcMacAes128 = CbcMac(crypto.core.aes.Aes128);

/// FIPS 113 (1985): Computer Data Authentication
/// https://csrc.nist.gov/publications/detail/fips/113/archive/1985-05-30
///
/// WARNING: CBC-MAC is insecure for variable-length messages without additional
/// protection. Only use when required by protocols like CCM that mitigate this.
pub fn CbcMac(comptime BlockCipher: type) type {
    const BlockCipherCtx = @typeInfo(@TypeOf(BlockCipher.initEnc)).@"fn".return_type.?;
    const Block = [BlockCipher.block.block_length]u8;

    return struct {
        const Self = @This();
        pub const key_length = BlockCipher.key_bits / 8;
        pub const block_length = BlockCipher.block.block_length;
        pub const mac_length = block_length;

        cipher_ctx: BlockCipherCtx,
        buf: Block = [_]u8{0} ** block_length,
        pos: usize = 0,

        pub fn create(out: *[mac_length]u8, msg: []const u8, key: *const [key_length]u8) void {
            var ctx = Self.init(key);
            ctx.update(msg);
            ctx.final(out);
        }

        pub fn init(key: *const [key_length]u8) Self {
            return Self{
                .cipher_ctx = BlockCipher.initEnc(key.*),
            };
        }

        pub fn update(self: *Self, msg: []const u8) void {
            const left = block_length - self.pos;
            var m = msg;

            // Partial buffer exists from previous update. Complete the block.
            if (m.len > left) {
                for (self.buf[self.pos..], 0..) |*b, i| b.* ^= m[i];
                m = m[left..];
                self.cipher_ctx.encrypt(&self.buf, &self.buf);
                self.pos = 0;
            }

            // Full blocks.
            while (m.len > block_length) {
                for (self.buf[0..block_length], 0..) |*b, i| b.* ^= m[i];
                m = m[block_length..];
                self.cipher_ctx.encrypt(&self.buf, &self.buf);
                self.pos = 0;
            }

            // Copy any remainder for next pass.
            if (m.len > 0) {
                for (self.buf[self.pos..][0..m.len], 0..) |*b, i| b.* ^= m[i];
                self.pos += m.len;
            }
        }

        pub fn final(self: *Self, out: *[mac_length]u8) void {
            // CBC-MAC: encrypt the current buffer state.
            // Partial blocks are implicitly zero-padded: buf[pos..] contains zeros from initialization.
            self.cipher_ctx.encrypt(out, &self.buf);
        }
    };
}

const testing = std.testing;

test "CbcMacAes128 - Empty message" {
    const key = [_]u8{ 0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c };
    var msg: [0]u8 = undefined;

    // CBC-MAC of empty message = Encrypt(0)
    const expected = [_]u8{ 0x7d, 0xf7, 0x6b, 0x0c, 0x1a, 0xb8, 0x99, 0xb3, 0x3e, 0x42, 0xf0, 0x47, 0xb9, 0x1b, 0x54, 0x6f };

    var out: [CbcMacAes128.mac_length]u8 = undefined;
    CbcMacAes128.create(&out, &msg, &key);
    try testing.expectEqualSlices(u8, &out, &expected);
}

test "CbcMacAes128 - Single block (16 bytes)" {
    const key = [_]u8{ 0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c };
    const msg = [_]u8{ 0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a };

    // CBC-MAC = Encrypt(msg XOR 0)
    const expected = [_]u8{ 0x3a, 0xd7, 0x7b, 0xb4, 0x0d, 0x7a, 0x36, 0x60, 0xa8, 0x9e, 0xca, 0xf3, 0x24, 0x66, 0xef, 0x97 };

    var out: [CbcMacAes128.mac_length]u8 = undefined;
    CbcMacAes128.create(&out, &msg, &key);
    try testing.expectEqualSlices(u8, &out, &expected);
}

test "CbcMacAes128 - Multiple blocks (40 bytes)" {
    const key = [_]u8{ 0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c };
    const msg = [_]u8{
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
        0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
        0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11,
    };

    // CBC-MAC processes: block1 | block2 | block3 (last 8 bytes zero-padded)
    const expected = [_]u8{ 0x07, 0xd1, 0x92, 0xe3, 0xe6, 0xf0, 0x99, 0xed, 0xcc, 0x39, 0xfd, 0xe6, 0xd0, 0x9c, 0x76, 0x2d };

    var out: [CbcMacAes128.mac_length]u8 = undefined;
    CbcMacAes128.create(&out, &msg, &key);
    try testing.expectEqualSlices(u8, &out, &expected);
}

test "CbcMacAes128 - Incremental update" {
    const key = [_]u8{ 0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c };
    const msg = [_]u8{
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
        0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
    };

    // Process in chunks
    var ctx = CbcMacAes128.init(&key);
    ctx.update(msg[0..10]);
    ctx.update(msg[10..20]);
    ctx.update(msg[20..]);

    var out1: [CbcMacAes128.mac_length]u8 = undefined;
    ctx.final(&out1);

    // Compare with one-shot processing
    var out2: [CbcMacAes128.mac_length]u8 = undefined;
    CbcMacAes128.create(&out2, &msg, &key);

    try testing.expectEqualSlices(u8, &out1, &out2);
}

test "CbcMacAes128 - Different from CMAC" {
    // Verify that CBC-MAC and CMAC produce different outputs
    const key = [_]u8{ 0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c };
    const msg = [_]u8{ 0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a };

    var cbc_mac_out: [CbcMacAes128.mac_length]u8 = undefined;
    CbcMacAes128.create(&cbc_mac_out, &msg, &key);

    // CMAC output for same input (from RFC 4493)
    const cmac_out = [_]u8{ 0x07, 0x0a, 0x16, 0xb4, 0x6b, 0x4d, 0x41, 0x44, 0xf7, 0x9b, 0xdd, 0x9d, 0xd0, 0x4a, 0x28, 0x7c };

    // They should be different
    try testing.expect(!mem.eql(u8, &cbc_mac_out, &cmac_out));
}
