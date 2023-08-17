const std = @import("std");
const mem = std.mem;
const expectEqual = std.testing.expectEqual;

const rotl = std.math.rotl;

pub const XxHash64 = struct {
    accumulator: Accumulator,
    seed: u64,
    buf: [32]u8,
    buf_len: usize,
    byte_count: usize,

    const prime_1 = 0x9E3779B185EBCA87; // 0b1001111000110111011110011011000110000101111010111100101010000111
    const prime_2 = 0xC2B2AE3D27D4EB4F; // 0b1100001010110010101011100011110100100111110101001110101101001111
    const prime_3 = 0x165667B19E3779F9; // 0b0001011001010110011001111011000110011110001101110111100111111001
    const prime_4 = 0x85EBCA77C2B2AE63; // 0b1000010111101011110010100111011111000010101100101010111001100011
    const prime_5 = 0x27D4EB2F165667C5; // 0b0010011111010100111010110010111100010110010101100110011111000101

    const Accumulator = struct {
        acc1: u64,
        acc2: u64,
        acc3: u64,
        acc4: u64,

        fn init(seed: u64) Accumulator {
            return .{
                .acc1 = seed +% prime_1 +% prime_2,
                .acc2 = seed +% prime_2,
                .acc3 = seed,
                .acc4 = seed -% prime_1,
            };
        }

        fn updateEmpty(self: *Accumulator, input: anytype, comptime unroll_count: usize) usize {
            var i: usize = 0;

            if (unroll_count > 0) {
                const unrolled_bytes = unroll_count * 32;
                while (i + unrolled_bytes <= input.len) : (i += unrolled_bytes) {
                    inline for (0..unroll_count) |j| {
                        self.processStripe(input[i + j * 32 ..][0..32]);
                    }
                }
            }

            while (i + 32 <= input.len) : (i += 32) {
                self.processStripe(input[i..][0..32]);
            }

            return i;
        }

        fn processStripe(self: *Accumulator, buf: *const [32]u8) void {
            self.acc1 = round(self.acc1, mem.readIntLittle(u64, buf[0..8]));
            self.acc2 = round(self.acc2, mem.readIntLittle(u64, buf[8..16]));
            self.acc3 = round(self.acc3, mem.readIntLittle(u64, buf[16..24]));
            self.acc4 = round(self.acc4, mem.readIntLittle(u64, buf[24..32]));
        }

        fn merge(self: Accumulator) u64 {
            var acc = rotl(u64, self.acc1, 1) +% rotl(u64, self.acc2, 7) +%
                rotl(u64, self.acc3, 12) +% rotl(u64, self.acc4, 18);
            acc = mergeAccumulator(acc, self.acc1);
            acc = mergeAccumulator(acc, self.acc2);
            acc = mergeAccumulator(acc, self.acc3);
            acc = mergeAccumulator(acc, self.acc4);
            return acc;
        }

        fn mergeAccumulator(acc: u64, other: u64) u64 {
            const a = acc ^ round(0, other);
            const b = a *% prime_1;
            return b +% prime_4;
        }
    };

    fn finalize(
        unfinished: u64,
        byte_count: usize,
        partial: anytype,
    ) u64 {
        std.debug.assert(partial.len < 32);
        var acc = unfinished +% @as(u64, byte_count) +% @as(u64, partial.len);

        switch (partial.len) {
            inline 0, 1, 2, 3 => |count| {
                inline for (0..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            inline 4, 5, 6, 7 => |count| {
                acc = finalize4(acc, partial[0..4]);
                inline for (4..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            inline 8, 9, 10, 11 => |count| {
                acc = finalize8(acc, partial[0..8]);
                inline for (8..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            inline 12, 13, 14, 15 => |count| {
                acc = finalize8(acc, partial[0..8]);
                acc = finalize4(acc, partial[8..12]);
                inline for (12..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            inline 16, 17, 18, 19 => |count| {
                acc = finalize8(acc, partial[0..8]);
                acc = finalize8(acc, partial[8..16]);
                inline for (16..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            inline 20, 21, 22, 23 => |count| {
                acc = finalize8(acc, partial[0..8]);
                acc = finalize8(acc, partial[8..16]);
                acc = finalize4(acc, partial[16..20]);
                inline for (20..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            inline 24, 25, 26, 27 => |count| {
                acc = finalize8(acc, partial[0..8]);
                acc = finalize8(acc, partial[8..16]);
                acc = finalize8(acc, partial[16..24]);
                inline for (24..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            inline 28, 29, 30, 31 => |count| {
                acc = finalize8(acc, partial[0..8]);
                acc = finalize8(acc, partial[8..16]);
                acc = finalize8(acc, partial[16..24]);
                acc = finalize4(acc, partial[24..28]);
                inline for (28..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            else => unreachable,
        }
    }

    fn finalize8(v: u64, bytes: *const [8]u8) u64 {
        var acc = v;
        const lane = mem.readIntLittle(u64, bytes);
        acc ^= round(0, lane);
        acc = rotl(u64, acc, 27) *% prime_1;
        acc +%= prime_4;
        return acc;
    }

    fn finalize4(v: u64, bytes: *const [4]u8) u64 {
        var acc = v;
        const lane = @as(u64, mem.readIntLittle(u32, bytes));
        acc ^= lane *% prime_1;
        acc = rotl(u64, acc, 23) *% prime_2;
        acc +%= prime_3;
        return acc;
    }

    fn finalize1(v: u64, byte: u8) u64 {
        var acc = v;
        const lane = @as(u64, byte);
        acc ^= lane *% prime_5;
        acc = rotl(u64, acc, 11) *% prime_1;
        return acc;
    }

    fn avalanche(value: u64) u64 {
        var result = value ^ (value >> 33);
        result *%= prime_2;
        result ^= result >> 29;
        result *%= prime_3;
        result ^= result >> 32;

        return result;
    }

    pub fn init(seed: u64) XxHash64 {
        return XxHash64{
            .accumulator = Accumulator.init(seed),
            .seed = seed,
            .buf = undefined,
            .buf_len = 0,
            .byte_count = 0,
        };
    }

    pub fn update(self: *XxHash64, input: anytype) void {
        validateType(@TypeOf(input));

        if (input.len < 32 - self.buf_len) {
            @memcpy(self.buf[self.buf_len..][0..input.len], input);
            self.buf_len += input.len;
            return;
        }

        var i: usize = 0;

        if (self.buf_len > 0) {
            i = 32 - self.buf_len;
            @memcpy(self.buf[self.buf_len..][0..i], input[0..i]);
            self.accumulator.processStripe(&self.buf);
            self.byte_count += self.buf_len;
        }

        i += self.accumulator.updateEmpty(input[i..], 32);
        self.byte_count += i;

        const remaining_bytes = input[i..];
        @memcpy(self.buf[0..remaining_bytes.len], remaining_bytes);
        self.buf_len = remaining_bytes.len;
    }

    fn round(acc: u64, lane: u64) u64 {
        const a = acc +% (lane *% prime_2);
        const b = rotl(u64, a, 31);
        return b *% prime_1;
    }

    pub fn final(self: *XxHash64) u64 {
        const unfinished = if (self.byte_count < 32)
            self.seed +% prime_5
        else
            self.accumulator.merge();

        return finalize(unfinished, self.byte_count, self.buf[0..self.buf_len]);
    }

    const Size = enum {
        small,
        large,
        unknown,
    };

    pub fn hash(seed: u64, input: anytype) u64 {
        validateType(@TypeOf(input));

        if (input.len < 32) {
            return finalize(seed +% prime_5, 0, input);
        } else {
            var hasher = Accumulator.init(seed);
            const i = hasher.updateEmpty(input, 0);
            return finalize(hasher.merge(), i, input[i..]);
        }
    }
};

pub const XxHash32 = struct {
    accumulator: Accumulator,
    seed: u32,
    buf: [16]u8,
    buf_len: usize,
    byte_count: usize,

    const prime_1 = 0x9E3779B1; // 0b10011110001101110111100110110001
    const prime_2 = 0x85EBCA77; // 0b10000101111010111100101001110111
    const prime_3 = 0xC2B2AE3D; // 0b11000010101100101010111000111101
    const prime_4 = 0x27D4EB2F; // 0b00100111110101001110101100101111
    const prime_5 = 0x165667B1; // 0b00010110010101100110011110110001

    const Accumulator = struct {
        acc1: u32,
        acc2: u32,
        acc3: u32,
        acc4: u32,

        fn init(seed: u32) Accumulator {
            return .{
                .acc1 = seed +% prime_1 +% prime_2,
                .acc2 = seed +% prime_2,
                .acc3 = seed,
                .acc4 = seed -% prime_1,
            };
        }

        fn updateEmpty(self: *Accumulator, input: anytype, comptime unroll_count: usize) usize {
            var i: usize = 0;

            if (unroll_count > 0) {
                const unrolled_bytes = unroll_count * 16;
                while (i + unrolled_bytes <= input.len) : (i += unrolled_bytes) {
                    inline for (0..unroll_count) |j| {
                        self.processStripe(input[i + j * 16 ..][0..16]);
                    }
                }
            }

            while (i + 16 <= input.len) : (i += 16) {
                self.processStripe(input[i..][0..16]);
            }

            return i;
        }

        fn processStripe(self: *Accumulator, buf: *const [16]u8) void {
            self.acc1 = round(self.acc1, mem.readIntLittle(u32, buf[0..4]));
            self.acc2 = round(self.acc2, mem.readIntLittle(u32, buf[4..8]));
            self.acc3 = round(self.acc3, mem.readIntLittle(u32, buf[8..12]));
            self.acc4 = round(self.acc4, mem.readIntLittle(u32, buf[12..16]));
        }

        fn merge(self: Accumulator) u32 {
            return rotl(u32, self.acc1, 1) +% rotl(u32, self.acc2, 7) +%
                rotl(u32, self.acc3, 12) +% rotl(u32, self.acc4, 18);
        }
    };

    pub fn init(seed: u32) XxHash32 {
        return XxHash32{
            .accumulator = Accumulator.init(seed),
            .seed = seed,
            .buf = undefined,
            .buf_len = 0,
            .byte_count = 0,
        };
    }

    pub fn update(self: *XxHash32, input: []const u8) void {
        validateType(@TypeOf(input));

        if (input.len < 16 - self.buf_len) {
            @memcpy(self.buf[self.buf_len..][0..input.len], input);
            self.buf_len += input.len;
            return;
        }

        var i: usize = 0;

        if (self.buf_len > 0) {
            i = 16 - self.buf_len;
            @memcpy(self.buf[self.buf_len..][0..i], input[0..i]);
            self.accumulator.processStripe(&self.buf);
            self.byte_count += self.buf_len;
            self.buf_len = 0;
        }

        i += self.accumulator.updateEmpty(input[i..], 16);
        self.byte_count += i;

        const remaining_bytes = input[i..];
        @memcpy(self.buf[0..remaining_bytes.len], remaining_bytes);
        self.buf_len = remaining_bytes.len;
    }

    fn round(acc: u32, lane: u32) u32 {
        const a = acc +% (lane *% prime_2);
        const b = rotl(u32, a, 13);
        return b *% prime_1;
    }

    pub fn final(self: *XxHash32) u32 {
        const unfinished = if (self.byte_count < 16)
            self.seed +% prime_5
        else
            self.accumulator.merge();

        return finalize(unfinished, self.byte_count, self.buf[0..self.buf_len]);
    }

    fn finalize(unfinished: u32, byte_count: usize, partial: anytype) u32 {
        std.debug.assert(partial.len < 16);
        var acc = unfinished +% @as(u32, @intCast(byte_count)) +% @as(u32, @intCast(partial.len));

        switch (partial.len) {
            inline 0, 1, 2, 3 => |count| {
                inline for (0..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            inline 4, 5, 6, 7 => |count| {
                acc = finalize4(acc, partial[0..4]);
                inline for (4..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            inline 8, 9, 10, 11 => |count| {
                acc = finalize4(acc, partial[0..4]);
                acc = finalize4(acc, partial[4..8]);
                inline for (8..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            inline 12, 13, 14, 15 => |count| {
                acc = finalize4(acc, partial[0..4]);
                acc = finalize4(acc, partial[4..8]);
                acc = finalize4(acc, partial[8..12]);
                inline for (12..count) |i| acc = finalize1(acc, partial[i]);
                return avalanche(acc);
            },
            else => unreachable,
        }

        return avalanche(acc);
    }

    fn finalize4(v: u32, bytes: *const [4]u8) u32 {
        var acc = v;
        const lane = mem.readIntLittle(u32, bytes);
        acc +%= lane *% prime_3;
        acc = rotl(u32, acc, 17) *% prime_4;
        return acc;
    }

    fn finalize1(v: u32, byte: u8) u32 {
        var acc = v;
        const lane = @as(u32, byte);
        acc +%= lane *% prime_5;
        acc = rotl(u32, acc, 11) *% prime_1;
        return acc;
    }

    fn avalanche(value: u32) u32 {
        var acc = value ^ value >> 15;
        acc *%= prime_2;
        acc ^= acc >> 13;
        acc *%= prime_3;
        acc ^= acc >> 16;

        return acc;
    }

    pub fn hash(seed: u32, input: anytype) u32 {
        validateType(@TypeOf(input));

        if (input.len < 16) {
            return finalize(seed +% prime_5, 0, input);
        } else {
            var hasher = Accumulator.init(seed);
            const i = hasher.updateEmpty(input, 0);
            return finalize(hasher.merge(), i, input[i..]);
        }
    }
};

fn validateType(comptime T: type) void {
    comptime {
        if (!((std.meta.trait.isSlice(T) or
            std.meta.trait.is(.Array)(T) or
            std.meta.trait.isPtrTo(.Array)(T)) and
            std.meta.Elem(T) == u8))
        {
            @compileError("expect a slice, array or pointer to array of u8, got " ++ @typeName(T));
        }
    }
}

fn testExpect(comptime H: type, seed: anytype, input: []const u8, expected: u64) !void {
    try expectEqual(expected, H.hash(0, input));

    var hasher = H.init(seed);
    hasher.update(input);
    try expectEqual(expected, hasher.final());
}

test "xxhash64" {
    const H = XxHash64;
    try testExpect(H, 0, "", 0xef46db3751d8e999);
    try testExpect(H, 0, "a", 0xd24ec4f1a98c6e5b);
    try testExpect(H, 0, "abc", 0x44bc2cf5ad770999);
    try testExpect(H, 0, "message digest", 0x066ed728fceeb3be);
    try testExpect(H, 0, "abcdefghijklmnopqrstuvwxyz", 0xcfe1f278fa89835c);
    try testExpect(H, 0, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", 0xaaa46907d3047814);
    try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890", 0xe04a477f19ee145d);
}

test "xxhash32" {
    const H = XxHash32;

    try testExpect(H, 0, "", 0x02cc5d05);
    try testExpect(H, 0, "a", 0x550d7456);
    try testExpect(H, 0, "abc", 0x32d153ff);
    try testExpect(H, 0, "message digest", 0x7c948494);
    try testExpect(H, 0, "abcdefghijklmnopqrstuvwxyz", 0x63a14d5f);
    try testExpect(H, 0, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", 0x9c285e64);
    try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890", 0x9c05f475);
}
