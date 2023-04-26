const std = @import("std");
const mem = std.mem;
const expectEqual = std.testing.expectEqual;

const rotl = std.math.rotl;

pub const XxHash64 = struct {
    acc1: u64,
    acc2: u64,
    acc3: u64,
    acc4: u64,

    seed: u64,
    buf: [32]u8,
    buf_len: usize,
    byte_count: usize,

    const prime_1 = 0x9E3779B185EBCA87; // 0b1001111000110111011110011011000110000101111010111100101010000111
    const prime_2 = 0xC2B2AE3D27D4EB4F; // 0b1100001010110010101011100011110100100111110101001110101101001111
    const prime_3 = 0x165667B19E3779F9; // 0b0001011001010110011001111011000110011110001101110111100111111001
    const prime_4 = 0x85EBCA77C2B2AE63; // 0b1000010111101011110010100111011111000010101100101010111001100011
    const prime_5 = 0x27D4EB2F165667C5; // 0b0010011111010100111010110010111100010110010101100110011111000101

    pub fn init(seed: u64) XxHash64 {
        return XxHash64{
            .seed = seed,
            .acc1 = seed +% prime_1 +% prime_2,
            .acc2 = seed +% prime_2,
            .acc3 = seed,
            .acc4 = seed -% prime_1,
            .buf = undefined,
            .buf_len = 0,
            .byte_count = 0,
        };
    }

    pub fn update(self: *XxHash64, input: []const u8) void {
        if (input.len < 32 - self.buf_len) {
            @memcpy(self.buf[self.buf_len..][0..input.len], input);
            self.buf_len += input.len;
            return;
        }

        var i: usize = 0;

        if (self.buf_len > 0) {
            i = 32 - self.buf_len;
            @memcpy(self.buf[self.buf_len..][0..i], input[0..i]);
            self.processStripe(&self.buf);
            self.buf_len = 0;
        }

        while (i + 32 <= input.len) : (i += 32) {
            self.processStripe(input[i..][0..32]);
        }

        const remaining_bytes = input[i..];
        @memcpy(self.buf[0..remaining_bytes.len], remaining_bytes);
        self.buf_len = remaining_bytes.len;
    }

    inline fn processStripe(self: *XxHash64, buf: *const [32]u8) void {
        self.acc1 = round(self.acc1, mem.readIntLittle(u64, buf[0..8]));
        self.acc2 = round(self.acc2, mem.readIntLittle(u64, buf[8..16]));
        self.acc3 = round(self.acc3, mem.readIntLittle(u64, buf[16..24]));
        self.acc4 = round(self.acc4, mem.readIntLittle(u64, buf[24..32]));
        self.byte_count += 32;
    }

    inline fn round(acc: u64, lane: u64) u64 {
        const a = acc +% (lane *% prime_2);
        const b = rotl(u64, a, 31);
        return b *% prime_1;
    }

    pub fn final(self: *XxHash64) u64 {
        var acc: u64 = undefined;

        if (self.byte_count < 32) {
            acc = self.seed +% prime_5;
        } else {
            acc = rotl(u64, self.acc1, 1) +% rotl(u64, self.acc2, 7) +%
                rotl(u64, self.acc3, 12) +% rotl(u64, self.acc4, 18);
            acc = mergeAccumulator(acc, self.acc1);
            acc = mergeAccumulator(acc, self.acc2);
            acc = mergeAccumulator(acc, self.acc3);
            acc = mergeAccumulator(acc, self.acc4);
        }

        acc = acc +% @as(u64, self.byte_count) +% @as(u64, self.buf_len);

        var pos: usize = 0;
        while (pos + 8 <= self.buf_len) : (pos += 8) {
            const lane = mem.readIntLittle(u64, self.buf[pos..][0..8]);
            acc ^= round(0, lane);
            acc = rotl(u64, acc, 27) *% prime_1;
            acc +%= prime_4;
        }

        if (pos + 4 <= self.buf_len) {
            const lane = @as(u64, mem.readIntLittle(u32, self.buf[pos..][0..4]));
            acc ^= lane *% prime_1;
            acc = rotl(u64, acc, 23) *% prime_2;
            acc +%= prime_3;
            pos += 4;
        }

        while (pos < self.buf_len) : (pos += 1) {
            const lane = @as(u64, self.buf[pos]);
            acc ^= lane *% prime_5;
            acc = rotl(u64, acc, 11) *% prime_1;
        }

        acc ^= acc >> 33;
        acc *%= prime_2;
        acc ^= acc >> 29;
        acc *%= prime_3;
        acc ^= acc >> 32;

        return acc;
    }

    inline fn mergeAccumulator(acc: u64, other: u64) u64 {
        const a = acc ^ round(0, other);
        const b = a *% prime_1;
        return b +% prime_4;
    }

    pub fn hash(input: []const u8) u64 {
        var hasher = XxHash64.init(0);
        hasher.update(input);
        return hasher.final();
    }
};

pub const XxHash32 = struct {
    acc1: u32,
    acc2: u32,
    acc3: u32,
    acc4: u32,

    seed: u32,
    buf: [16]u8,
    buf_len: usize,
    byte_count: usize,

    const prime_1 = 0x9E3779B1; // 0b10011110001101110111100110110001
    const prime_2 = 0x85EBCA77; // 0b10000101111010111100101001110111
    const prime_3 = 0xC2B2AE3D; // 0b11000010101100101010111000111101
    const prime_4 = 0x27D4EB2F; // 0b00100111110101001110101100101111
    const prime_5 = 0x165667B1; // 0b00010110010101100110011110110001

    pub fn init(seed: u32) XxHash32 {
        return XxHash32{
            .seed = seed,
            .acc1 = seed +% prime_1 +% prime_2,
            .acc2 = seed +% prime_2,
            .acc3 = seed,
            .acc4 = seed -% prime_1,
            .buf = undefined,
            .buf_len = 0,
            .byte_count = 0,
        };
    }

    pub fn update(self: *XxHash32, input: []const u8) void {
        if (input.len < 16 - self.buf_len) {
            @memcpy(self.buf[self.buf_len..][0..input.len], input);
            self.buf_len += input.len;
            return;
        }

        var i: usize = 0;

        if (self.buf_len > 0) {
            i = 16 - self.buf_len;
            @memcpy(self.buf[self.buf_len..][0..i], input[0..i]);
            self.processStripe(&self.buf);
            self.buf_len = 0;
        }

        while (i + 16 <= input.len) : (i += 16) {
            self.processStripe(input[i..][0..16]);
        }

        const remaining_bytes = input[i..];
        @memcpy(self.buf[0..remaining_bytes.len], remaining_bytes);
        self.buf_len = remaining_bytes.len;
    }

    inline fn processStripe(self: *XxHash32, buf: *const [16]u8) void {
        self.acc1 = round(self.acc1, mem.readIntLittle(u32, buf[0..4]));
        self.acc2 = round(self.acc2, mem.readIntLittle(u32, buf[4..8]));
        self.acc3 = round(self.acc3, mem.readIntLittle(u32, buf[8..12]));
        self.acc4 = round(self.acc4, mem.readIntLittle(u32, buf[12..16]));
        self.byte_count += 16;
    }

    inline fn round(acc: u32, lane: u32) u32 {
        const a = acc +% (lane *% prime_2);
        const b = rotl(u32, a, 13);
        return b *% prime_1;
    }

    pub fn final(self: *XxHash32) u32 {
        var acc: u32 = undefined;

        if (self.byte_count < 16) {
            acc = self.seed +% prime_5;
        } else {
            acc = rotl(u32, self.acc1, 1) +% rotl(u32, self.acc2, 7) +%
                rotl(u32, self.acc3, 12) +% rotl(u32, self.acc4, 18);
        }

        acc = acc +% @intCast(u32, self.byte_count) +% @intCast(u32, self.buf_len);

        var pos: usize = 0;
        while (pos + 4 <= self.buf_len) : (pos += 4) {
            const lane = mem.readIntLittle(u32, self.buf[pos..][0..4]);
            acc +%= lane *% prime_3;
            acc = rotl(u32, acc, 17) *% prime_4;
        }

        while (pos < self.buf_len) : (pos += 1) {
            const lane = @as(u32, self.buf[pos]);
            acc +%= lane *% prime_5;
            acc = rotl(u32, acc, 11) *% prime_1;
        }

        acc ^= acc >> 15;
        acc *%= prime_2;
        acc ^= acc >> 13;
        acc *%= prime_3;
        acc ^= acc >> 16;

        return acc;
    }

    pub fn hash(input: []const u8) u32 {
        var hasher = XxHash32.init(0);
        hasher.update(input);
        return hasher.final();
    }
};

test "xxhash64" {
    const hash = XxHash64.hash;

    try expectEqual(hash(""), 0xef46db3751d8e999);
    try expectEqual(hash("a"), 0xd24ec4f1a98c6e5b);
    try expectEqual(hash("abc"), 0x44bc2cf5ad770999);
    try expectEqual(hash("message digest"), 0x066ed728fceeb3be);
    try expectEqual(hash("abcdefghijklmnopqrstuvwxyz"), 0xcfe1f278fa89835c);
    try expectEqual(hash("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"), 0xaaa46907d3047814);
    try expectEqual(hash("12345678901234567890123456789012345678901234567890123456789012345678901234567890"), 0xe04a477f19ee145d);
}

test "xxhash32" {
    const hash = XxHash32.hash;

    try expectEqual(hash(""), 0x02cc5d05);
    try expectEqual(hash("a"), 0x550d7456);
    try expectEqual(hash("abc"), 0x32d153ff);
    try expectEqual(hash("message digest"), 0x7c948494);
    try expectEqual(hash("abcdefghijklmnopqrstuvwxyz"), 0x63a14d5f);
    try expectEqual(hash("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"), 0x9c285e64);
    try expectEqual(hash("12345678901234567890123456789012345678901234567890123456789012345678901234567890"), 0x9c05f475);
}
