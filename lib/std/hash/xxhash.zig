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

pub const XxHash3 = struct {
    const Block = @Vector(8, u64);
    const secret: [192]u8 align(@alignOf(Block)) = [_]u8{
        0xb8, 0xfe, 0x6c, 0x39, 0x23, 0xa4, 0x4b, 0xbe, 0x7c, 0x01, 0x81, 0x2c, 0xf7, 0x21, 0xad, 0x1c,
        0xde, 0xd4, 0x6d, 0xe9, 0x83, 0x90, 0x97, 0xdb, 0x72, 0x40, 0xa4, 0xa4, 0xb7, 0xb3, 0x67, 0x1f,
        0xcb, 0x79, 0xe6, 0x4e, 0xcc, 0xc0, 0xe5, 0x78, 0x82, 0x5a, 0xd0, 0x7d, 0xcc, 0xff, 0x72, 0x21,
        0xb8, 0x08, 0x46, 0x74, 0xf7, 0x43, 0x24, 0x8e, 0xe0, 0x35, 0x90, 0xe6, 0x81, 0x3a, 0x26, 0x4c,
        0x3c, 0x28, 0x52, 0xbb, 0x91, 0xc3, 0x00, 0xcb, 0x88, 0xd0, 0x65, 0x8b, 0x1b, 0x53, 0x2e, 0xa3,
        0x71, 0x64, 0x48, 0x97, 0xa2, 0x0d, 0xf9, 0x4e, 0x38, 0x19, 0xef, 0x46, 0xa9, 0xde, 0xac, 0xd8,
        0xa8, 0xfa, 0x76, 0x3f, 0xe3, 0x9c, 0x34, 0x3f, 0xf9, 0xdc, 0xbb, 0xc7, 0xc7, 0x0b, 0x4f, 0x1d,
        0x8a, 0x51, 0xe0, 0x4b, 0xcd, 0xb4, 0x59, 0x31, 0xc8, 0x9f, 0x7e, 0xc9, 0xd9, 0x78, 0x73, 0x64,
        0xea, 0xc5, 0xac, 0x83, 0x34, 0xd3, 0xeb, 0xc3, 0xc5, 0x81, 0xa0, 0xff, 0xfa, 0x13, 0x63, 0xeb,
        0x17, 0x0d, 0xdd, 0x51, 0xb7, 0xf0, 0xda, 0x49, 0xd3, 0x16, 0x55, 0x26, 0x29, 0xd4, 0x68, 0x9e,
        0x2b, 0x16, 0xbe, 0x58, 0x7d, 0x47, 0xa1, 0xfc, 0x8f, 0xf8, 0xb8, 0xd1, 0x7a, 0xd0, 0x31, 0xce,
        0x45, 0xcb, 0x3a, 0x8f, 0x95, 0x16, 0x04, 0x28, 0xaf, 0xd7, 0xfb, 0xca, 0xbb, 0x4b, 0x40, 0x7e,
    };

    const primes32 = [_]u32{
        0x9E3779B1,
        0x85EBCA77,
        0xC2B2AE3D,
        0x27D4EB2F,
        0x165667B1,
    };
    const primes64 = [_]u64{
        0x9E3779B185EBCA87,
        0xC2B2AE3D27D4EB4F,
        0x165667B19E3779F9,
        0x85EBCA77C2B2AE63,
        0x27D4EB2F165667C5,
    };

    const primesMX = [_]u64{
        0x165667919E3779F9,
        0x9FB21C651E98DF25,
    };

    const defaultAcc: Block = @bitCast([8]u64{
        primes32[2], primes64[0], primes64[1], primes64[2],
        primes64[3], primes32[1], primes64[4], primes32[0],
    });

    acc: Block,
    buf: [256]u8,
    scrt: *align(@alignOf(Block)) const [secret.len]u8,

    buf_len: usize,
    totalLen: usize,
    stripesSoFar: usize,

    seed: u64,

    inline fn read(comptime int: type, data: []const u8) int {
        return std.mem.readIntLittle(int, data[0..@sizeOf(int)]);
    }

    inline fn fold(a: u64, b: u64) u64 {
        const c = @as(u128, a) *% b;
        return @as(u64, @truncate(c)) ^ @as(u64, @truncate(c >> 64));
    }

    inline fn mix16(in: []const u8, scrt: []const u8, seed: u64) u64 {
        const lo = read(u64, in[0..]) ^ (read(u64, scrt[0..]) +% seed);
        const hi = read(u64, in[8..]) ^ (read(u64, scrt[8..]) -% seed);
        return fold(lo, hi);
    }

    fn avalanceH3(x0: u64) u64 {
        const x1 = (x0 ^ (x0 >> 37)) *% primesMX[0];
        return x1 ^ (x1 >> 32);
    }

    fn avalanceH64(x0: u64) u64 {
        const x1 = (x0 ^ (x0 >> 33)) *% primes64[1];
        const x2 = (x1 ^ (x1 >> 29)) *% primes64[2];
        return x2 ^ (x2 >> 32);
    }

    fn avalanceRRMXMX(x0: u64, len: u64) u64 {
        const x1 = (x0 ^ rotl(u64, x0, 49) ^ rotl(u64, x0, 24)) *% primesMX[1];
        const x2 = (x1 ^ ((x1 >> 35) +% len)) *% primesMX[1];
        return x2 ^ (x2 >> 28);
    }

    pub fn hash(seed: u64, input: anytype) u64 {
        validateType(@TypeOf(input));

        if (input.len <= 16) return hash16(seed, input[0..input.len]);
        if (input.len <= 128) return hash128(seed, input[0..input.len]);
        if (input.len <= 240) return hash240(seed, input[0..input.len]);

        return hashLong(seed, input[0..input.len]);
    }

    inline fn hash16(seed: u64, in: []const u8) u64 {
        std.debug.assert(in.len <= 16);

        // 9 to 16
        if (in.len > 8) {
            const a = (read(u64, secret[24..]) ^ read(u64, secret[32..])) +% seed;
            const b = (read(u64, secret[40..]) ^ read(u64, secret[48..])) -% seed;
            const lo = a ^ read(u64, in);
            const hi = b ^ read(u64, in[in.len - 8 ..]);

            const x0 = fold(lo, hi) +% @byteSwap(lo) +% hi +% in.len;

            return avalanceH3(x0);
        }

        // 4 to 8
        if (in.len >= 4) {
            const a = seed ^ (@as(u64, @byteSwap(@as(u32, @truncate(seed)))) << 32);
            const b = (@as(u64, read(u32, in)) << 32) +% read(u32, in[in.len - 4 ..]);

            const c1 = read(u64, secret[8..]);
            const c2 = read(u64, secret[16..]);
            const c = (c1 ^ c2) -% a;
            const x0 = b ^ c;

            return avalanceRRMXMX(x0, in.len);
        }

        // 1 to 3
        if (in.len > 0) {
            const a = (@as(u32, @truncate(in.len)) << 8) | in[in.len - 1];
            const b = (@as(u32, in[0]) << 16) | (@as(u32, in[in.len >> 1]) << 24);
            const c = seed +% (read(u32, secret[0..]) ^ read(u32, secret[4..]));

            const x0 = (a | b) ^ c;

            return avalanceH64(x0);
        }

        const x0 = seed ^ read(u64, secret[56..]) ^ read(u64, secret[64..]);
        return avalanceH64(x0);
    }

    inline fn hash128(seed: u64, in: []const u8) u64 {
        std.debug.assert(in.len <= 128);
        std.debug.assert(in.len > 0);

        var acc = primes64[0] *% in.len;

        if (@import("builtin").mode == .ReleaseSmall) {
            var i = @as(u32, @truncate(in.len - 1)) / 32;
            while (true) {
                acc +%= mix16(in[16 * i ..], secret[32 * i ..], seed);
                acc +%= mix16(in[in.len - 16 * (i + 1) ..], secret[32 * i + 16 ..], seed);
                i = std.math.sub(u32, i, 1) catch break;
            }
        } else {
            if (in.len > 32) {
                if (in.len > 64) {
                    if (in.len > 96) {
                        acc +%= mix16(in[48..], secret[96..], seed);
                        acc +%= mix16(in[in.len - 64 ..], secret[112..], seed);
                    }

                    acc +%= mix16(in[32..], secret[64..], seed);
                    acc +%= mix16(in[in.len - 48 ..], secret[80..], seed);
                }

                acc +%= mix16(in[16..], secret[32..], seed);
                acc +%= mix16(in[in.len - 32 ..], secret[48..], seed);
            }

            acc +%= mix16(in[0..], secret[0..], seed);
            acc +%= mix16(in[in.len - 16 ..], secret[16..], seed);
        }

        return avalanceH3(acc);
    }

    noinline fn hash240(seed: u64, in: []const u8) u64 {
        std.debug.assert(in.len <= 240);
        std.debug.assert(in.len > 0);

        var acc = primes64[0] *% in.len;
        for (0..8) |i| {
            acc +%= mix16(in[16 * i ..], secret[16 * i ..], seed);
        }
        acc = avalanceH3(acc);

        for (8..(in.len / 16)) |i| {
            acc +%= mix16(in[16 * i ..], secret[16 * (i - 8) + 3 ..], seed);
        }
        acc +%= mix16(in[in.len - 16 ..], secret[119..], seed);

        return avalanceH3(acc);
    }

    noinline fn hashLong(seed: u64, in: []const u8) u64 {
        var scrt: *align(@alignOf(Block)) const [secret.len]u8 = &secret;
        var custom_secret: [secret.len]u8 align(@alignOf(Block)) = undefined;

        if (seed == 0) {
            const apply: u128 = @bitCast([2]u64{ seed, @as(u64, 0) -% seed });
            const scale: Block = @bitCast([_]u128{apply} ** 4);
            scrt = &custom_secret;

            const src: [3]Block = @bitCast(secret);
            const dst: *[3]Block = @ptrCast(&custom_secret);
            for (src, dst) |s, *d| d.* = s +% scale;
        }

        var acc: Block = defaultAcc;

        const num_stripe_blocks = (scrt.len - @sizeOf(Block)) / 8;
        const block_len = @sizeOf(Block) * num_stripe_blocks;
        const num_blocks = (in.len - 1) / block_len;

        for (0..num_blocks) |n| {
            accumulate(&acc, in.ptr + (n * block_len), scrt, num_stripe_blocks);

            acc ^= acc >> @splat(@as(u6, 47));
            acc ^= @as(Block, @bitCast(scrt[scrt.len - @sizeOf(Block) ..][0..@sizeOf(Block)].*));
            acc *%= @splat(@as(u64, primes32[0]));
        }

        const num_stripes = ((in.len - 1) - (block_len * num_blocks)) / @sizeOf(Block);
        accumulate(&acc, in.ptr + (num_blocks * block_len), scrt, num_stripes);
        accumulateBlock(&acc, in.ptr + (in.len - @sizeOf(Block)), @alignCast(scrt.ptr + 121));

        const last: Block = @bitCast(scrt[11 .. 11 + @sizeOf(Block)].*);
        acc ^= last;

        var result64 = primes64[0] *% in.len;
        for (@as([4][2]u64, @bitCast(acc))) |p| {
            result64 +%= fold(p[0], p[1]);
        }

        return avalanceH3(result64);
    }

    inline fn accumulate(acc: *Block, in: [*]const u8, scrt: [*]const u8, num_stripes: usize) void {
        for (0..num_stripes) |n| {
            const in_block = in + (n * @sizeOf(Block));
            @prefetch(in_block + 320, .{});
            accumulateBlock(acc, in_block, scrt + (n * 8));
        }
    }

    inline fn accumulateBlock(
        noalias acc: *Block,
        noalias in: [*]const u8,
        noalias scrt: [*]const u8,
    ) void {
        const data: Block = @bitCast(in[0..@sizeOf(Block)].*);
        const keys: Block = @bitCast(scrt[0..@sizeOf(Block)].*);

        const flipped = keys ^ data;
        const lo = flipped & @as(@Vector(8, u32), @splat(@as(u64, 0xffffffff)));
        const hi = flipped >> @as(@Vector(8, u32), @splat(@as(u6, 32)));

        const swapped = @shuffle(u64, data, undefined, [_]i32{ 1, 0, 3, 2, 5, 4, 7, 6 });
        acc.* +%= swapped +% (lo *% hi);
    }

    // Streaming

    pub fn init(seed: u64) XxHash3 {
        var scrt: *align(@alignOf(Block)) const [secret.len]u8 = &secret;
        var custom_secret: [secret.len]u8 align(@alignOf(Block)) = undefined;

        if (seed == 0) {
            const apply: u128 = @bitCast([2]u64{ seed, @as(u64, 0) -% seed });
            const scale: Block = @bitCast([_]u128{apply} ** 4);
            scrt = &custom_secret;

            const src: [3]Block = @bitCast(secret);
            const dst: *[3]Block = @ptrCast(&custom_secret);
            for (src, dst) |s, *d| d.* = s +% scale;
        }

        return XxHash3{
            .scrt = scrt,
            .seed = seed,
            .buf_len = 0,
            .buf = undefined,
            .totalLen = 0,
            .acc = defaultAcc,
            .stripesSoFar = 0,
        };
    }

    // Brings the hasher state back to as it was at init.
    pub fn reset(self: *XxHash3, seed: u64) void {
        init(seed);
        self.seed = seed;
        self.buf_len = 0;
        self.acc = defaultAcc;
    }

    fn consumeStripes(state: *XxHash3, numStripes: usize, input: []const u8) void {
        var nbStripes = numStripes;
        var internal_input = input;

        // if (nbStripes >= (16 - state.stripesSoFar)) {
        //     var stripesThisIter = 16 - state.stripesSoFar;
        //     while (nbStripes >= 16) {
        //         // f_acc

        //         // Scramble
        //         state.acc ^= state.acc >> @splat(@as(u6, 47));
        //         state.acc ^= @as(Block, @bitCast(state.scrt[state.scrt.len - @sizeOf(Block) ..][0..@sizeOf(Block)].*));
        //         state.acc *%= @splat(@as(u64, primes32[0]));

        //         internal_input = internal_input[stripesThisIter * 64 ..];
        //         nbStripes -= stripesThisIter;
        //         stripesThisIter = 16;
        //     }
        //     state.stripesSoFar = 0;
        // }

        if (nbStripes > 0) {
            // f_acc

            std.debug.print("{d}\n", .{nbStripes * 64});

            internal_input = internal_input[nbStripes * 64 ..];
            state.stripesSoFar += nbStripes;
        }
    }

    fn digest(state: *XxHash3, local_acc: *Block) void {
        local_acc.* = state.acc;
        std.debug.print("BufLen: {d}\n", .{state.buf_len});

        if (state.buf_len >= 64) {
            const nbStripes = (state.buf_len - 1) / 64;
            const stripesSoFar = state.stripesSoFar;

            std.debug.print("StripesSoFar: {d}\n", .{stripesSoFar});
            std.debug.print("NbStripes: {d}\n", .{nbStripes});

            consumeStripes(state, nbStripes, &state.buf);
        } else {}

        // accumulateBlock(local_acc, lastStripePtr, state.scrt);
    }

    pub fn update(self: *XxHash3, input: []const u8) void {
        validateType(@TypeOf(input));
        if (input.len == 0) return;
        var internal_input = input;

        // const xxh_u8* const bEnd = input + len;
        // bEnd: The adress past the end of the input buffer

        const bEnd = &internal_input[input.len - 1];

        std.debug.print("BEnd: {x}\n", .{bEnd});

        self.totalLen += input.len;

        std.debug.print("Input: {s}\n", .{input});

        if (input.len <= 256 - self.buf_len) {
            std.debug.print("TMP Buffer\n", .{});

            @memcpy(self.buf[self.buf_len..][0..input.len], input);
            self.buf_len += input.len;
            return;
        }

        if (self.buf_len > 0) {
            const loadSize = 256 - self.buf_len;

            std.debug.print("Load size: {d}\n", .{loadSize});

            @memcpy(self.buf[self.buf_len..][0..loadSize], input[0..loadSize]);
            internal_input = internal_input[loadSize..];

            std.debug.print("Buffer: {s}\n", .{self.buf});

            std.debug.print("Input: {s}\n", .{internal_input});

            consumeStripes(self, 4, internal_input);

            self.buf_len = 0;
        }

        std.debug.assert(self.buf_len == 0);
        @memcpy(self.buf[0..self.buf.len], internal_input[0..internal_input.len]);
        self.buf_len = 66; // TODO: remove
    }

    pub fn final(self: *XxHash3) u64 {
        if (self.totalLen > 240) {
            std.debug.print("Total length: {d}\n", .{self.totalLen});

            // Local Acc
            var local_acc: Block = undefined;

            digest(self, &local_acc);

            std.debug.print("Local Acc: {x}\n", .{local_acc});
        }

        return 0;
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

const verify = @import("verify.zig");

fn testExpect(comptime H: type, seed: anytype, input: []const u8, expected: u64) !void {
    try expectEqual(expected, H.hash(seed, input));

    var hasher = H.init(seed);
    hasher.update(input);
    try expectEqual(expected, hasher.final());
}

test "xxhash.3" {
    const H = XxHash3;

    std.debug.print("\n", .{});

    // try testExpect(H, 0, "", 0x2d06800538d394c2);
    // try testExpect(H, 0, "a", 0xe6c632b61e964e1f);
    // try testExpect(H, 0, "abc", 0x78af5f94892f3950);
    // try testExpect(H, 0, "message", 0x0b1ca9b8977554fa);
    // try testExpect(H, 0, "message digest", 0x160d8e9329be94f9);
    // try testExpect(H, 0, "abcdefghijklmnopqrstuvwxyz", 0x810f9ca067fbb90c);
    // try testExpect(H, 0, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", 0x643542bb51639cb2);
    // try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890", 0x7f58aa2520c681f9);

    var hasher = H.init(0);

    hasher.update("ab");
    // hasher.update("12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890");

    const hash = hasher.final();

    // const hash = H.hash(0, "ab12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890");

    std.debug.print("Hash: {x}\n", .{hash});
}

test "xxhash3 smhasher" {
    const Test = struct {
        fn do() !void {
            try expectEqual(verify.smhasher(XxHash3.hash), 0xD677BC30);
        }
    };
    try Test.do();
    @setEvalBranchQuota(75000);
    comptime try Test.do();
}

test "xxhash3 iterative api" {
    const Test = struct {
        fn do() !void {
            try verify.iterativeApi(XxHash3);
        }
    };
    try Test.do();
    @setEvalBranchQuota(30000);
    comptime try Test.do();
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

test "xxhash64 smhasher" {
    const Test = struct {
        fn do() !void {
            try expectEqual(verify.smhasher(XxHash64.hash), 0x024B7CF4);
        }
    };
    try Test.do();
    @setEvalBranchQuota(75000);
    comptime try Test.do();
}

test "xxhash64 iterative api" {
    const Test = struct {
        fn do() !void {
            try verify.iterativeApi(XxHash64);
        }
    };
    try Test.do();
    @setEvalBranchQuota(30000);
    comptime try Test.do();
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

test "xxhash32 smhasher" {
    const Test = struct {
        fn do() !void {
            try expectEqual(verify.smhasher(XxHash32.hash), 0xBA88B743);
        }
    };
    try Test.do();
    @setEvalBranchQuota(75000);
    comptime try Test.do();
}

test "xxhash32 iterative api" {
    const Test = struct {
        fn do() !void {
            try verify.iterativeApi(XxHash32);
        }
    };
    try Test.do();
    @setEvalBranchQuota(30000);
    comptime try Test.do();
}
