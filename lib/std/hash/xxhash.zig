const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expectEqual = std.testing.expectEqual;
const native_endian = builtin.cpu.arch.endian();

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
            self.acc1 = round(self.acc1, mem.readInt(u64, buf[0..8], .little));
            self.acc2 = round(self.acc2, mem.readInt(u64, buf[8..16], .little));
            self.acc3 = round(self.acc3, mem.readInt(u64, buf[16..24], .little));
            self.acc4 = round(self.acc4, mem.readInt(u64, buf[24..32], .little));
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
        const lane = mem.readInt(u64, bytes, .little);
        acc ^= round(0, lane);
        acc = rotl(u64, acc, 27) *% prime_1;
        acc +%= prime_4;
        return acc;
    }

    fn finalize4(v: u64, bytes: *const [4]u8) u64 {
        var acc = v;
        const lane = @as(u64, mem.readInt(u32, bytes, .little));
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
            self.acc1 = round(self.acc1, mem.readInt(u32, buf[0..4], .little));
            self.acc2 = round(self.acc2, mem.readInt(u32, buf[4..8], .little));
            self.acc3 = round(self.acc3, mem.readInt(u32, buf[8..12], .little));
            self.acc4 = round(self.acc4, mem.readInt(u32, buf[12..16], .little));
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
        const lane = mem.readInt(u32, bytes, .little);
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
    const default_secret: [192]u8 = .{
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

    const prime_mx1 = 0x165667919E3779F9;
    const prime_mx2 = 0x9FB21C651E98DF25;

    inline fn avalanche(mode: union(enum) { h3, h64, rrmxmx: u64 }, x0: u64) u64 {
        switch (mode) {
            .h3 => {
                const x1 = (x0 ^ (x0 >> 37)) *% prime_mx1;
                return x1 ^ (x1 >> 32);
            },
            .h64 => {
                const x1 = (x0 ^ (x0 >> 33)) *% XxHash64.prime_2;
                const x2 = (x1 ^ (x1 >> 29)) *% XxHash64.prime_3;
                return x2 ^ (x2 >> 32);
            },
            .rrmxmx => |len| {
                const x1 = (x0 ^ rotl(u64, x0, 49) ^ rotl(u64, x0, 24)) *% prime_mx2;
                const x2 = (x1 ^ ((x1 >> 35) +% len)) *% prime_mx2;
                return x2 ^ (x2 >> 28);
            },
        }
    }

    inline fn fold(a: u64, b: u64) u64 {
        const wide: [2]u64 = @bitCast(@as(u128, a) *% b);
        return wide[0] ^ wide[1];
    }

    inline fn swap(x: anytype) @TypeOf(x) {
        return if (native_endian == .big) @byteSwap(x) else x;
    }

    inline fn disableAutoVectorization(x: anytype) void {
        if (!@inComptime()) asm volatile (""
            :
            : [x] "r" (x),
        );
    }

    inline fn mix16(seed: u64, input: []const u8, secret: []const u8) u64 {
        const blk: [4]u64 = @bitCast([_][16]u8{ input[0..16].*, secret[0..16].* });
        disableAutoVectorization(seed);

        return fold(
            swap(blk[0]) ^ (swap(blk[2]) +% seed),
            swap(blk[1]) ^ (swap(blk[3]) -% seed),
        );
    }

    const Accumulator = extern struct {
        consumed: usize = 0,
        seed: u64,
        secret: [192]u8 = undefined,
        state: Block = Block{
            XxHash32.prime_3,
            XxHash64.prime_1,
            XxHash64.prime_2,
            XxHash64.prime_3,
            XxHash64.prime_4,
            XxHash32.prime_2,
            XxHash64.prime_5,
            XxHash32.prime_1,
        },

        inline fn init(seed: u64) Accumulator {
            var self = Accumulator{ .seed = seed };
            for (
                std.mem.bytesAsSlice(Block, &self.secret),
                std.mem.bytesAsSlice(Block, &default_secret),
            ) |*dst, src| {
                dst.* = swap(swap(src) +% Block{
                    seed, @as(u64, 0) -% seed,
                    seed, @as(u64, 0) -% seed,
                    seed, @as(u64, 0) -% seed,
                    seed, @as(u64, 0) -% seed,
                });
            }
            return self;
        }

        inline fn round(
            noalias state: *Block,
            noalias input_block: *align(1) const Block,
            noalias secret_block: *align(1) const Block,
        ) void {
            const data = swap(input_block.*);
            const mixed = data ^ swap(secret_block.*);
            state.* +%= (mixed & @as(Block, @splat(0xffffffff))) *% (mixed >> @splat(32));
            state.* +%= @shuffle(u64, data, undefined, [_]i32{ 1, 0, 3, 2, 5, 4, 7, 6 });
        }

        fn accumulate(noalias self: *Accumulator, blocks: []align(1) const Block) void {
            const secret = std.mem.bytesAsSlice(u64, self.secret[self.consumed * 8 ..]);
            for (blocks, secret[0..blocks.len]) |*input_block, *secret_block| {
                @prefetch(@as([*]const u8, @ptrCast(input_block)) + 320, .{});
                round(&self.state, input_block, @ptrCast(secret_block));
            }
        }

        fn scramble(self: *Accumulator) void {
            const secret_block: Block = @bitCast(self.secret[192 - @sizeOf(Block) .. 192].*);
            self.state ^= self.state >> @splat(47);
            self.state ^= swap(secret_block);
            self.state *%= @as(Block, @splat(XxHash32.prime_1));
        }

        fn consume(noalias self: *Accumulator, input_blocks: []align(1) const Block) void {
            const blocks_per_scramble = 1024 / @sizeOf(Block);
            std.debug.assert(self.consumed <= blocks_per_scramble);

            var blocks = input_blocks;
            var blocks_until_scramble = blocks_per_scramble - self.consumed;
            while (blocks.len >= blocks_until_scramble) {
                self.accumulate(blocks[0..blocks_until_scramble]);
                self.scramble();

                self.consumed = 0;
                blocks = blocks[blocks_until_scramble..];
                blocks_until_scramble = blocks_per_scramble;
            }

            self.accumulate(blocks);
            self.consumed += blocks.len;
        }

        fn digest(noalias self: *Accumulator, total_len: u64, noalias last_block: *align(1) const Block) u64 {
            const secret_block = self.secret[192 - @sizeOf(Block) - 7 ..][0..@sizeOf(Block)];
            round(&self.state, last_block, @ptrCast(secret_block));

            const merge_block: Block = @bitCast(self.secret[11 .. 11 + @sizeOf(Block)].*);
            self.state ^= swap(merge_block);

            var result = XxHash64.prime_1 *% total_len;
            inline for (0..4) |i| {
                result +%= fold(self.state[i * 2], self.state[i * 2 + 1]);
            }
            return avalanche(.h3, result);
        }
    };

    // Public API - Oneshot

    pub fn hash(seed: u64, input: anytype) u64 {
        const secret = &default_secret;
        if (input.len > 240) return hashLong(seed, input);
        if (input.len > 128) return hash240(seed, input, secret);
        if (input.len > 16) return hash128(seed, input, secret);
        if (input.len > 8) return hash16(seed, input, secret);
        if (input.len > 3) return hash8(seed, input, secret);
        if (input.len > 0) return hash3(seed, input, secret);

        const flip: [2]u64 = @bitCast(secret[56..72].*);
        const key = swap(flip[0]) ^ swap(flip[1]);
        return avalanche(.h64, seed ^ key);
    }

    fn hash3(seed: u64, input: anytype, noalias secret: *const [192]u8) u64 {
        @setCold(true);
        std.debug.assert(input.len > 0 and input.len < 4);

        const flip: [2]u32 = @bitCast(secret[0..8].*);
        const blk: u32 = @bitCast([_]u8{
            input[input.len - 1],
            @truncate(input.len),
            input[0],
            input[input.len / 2],
        });

        const key = @as(u64, swap(flip[0]) ^ swap(flip[1])) +% seed;
        return avalanche(.h64, key ^ swap(blk));
    }

    fn hash8(seed: u64, input: anytype, noalias secret: *const [192]u8) u64 {
        @setCold(true);
        std.debug.assert(input.len >= 4 and input.len <= 8);

        const flip: [2]u64 = @bitCast(secret[8..24].*);
        const blk: [2]u32 = @bitCast([_][4]u8{
            input[0..4].*,
            input[input.len - 4 ..][0..4].*,
        });

        const mixed = seed ^ (@as(u64, @byteSwap(@as(u32, @truncate(seed)))) << 32);
        const key = (swap(flip[0]) ^ swap(flip[1])) -% mixed;
        const combined = (@as(u64, swap(blk[0])) << 32) +% swap(blk[1]);
        return avalanche(.{ .rrmxmx = input.len }, key ^ combined);
    }

    fn hash16(seed: u64, input: anytype, noalias secret: *const [192]u8) u64 {
        @setCold(true);
        std.debug.assert(input.len > 8 and input.len <= 16);

        const flip: [4]u64 = @bitCast(secret[24..56].*);
        const blk: [2]u64 = @bitCast([_][8]u8{
            input[0..8].*,
            input[input.len - 8 ..][0..8].*,
        });

        const lo = swap(blk[0]) ^ ((swap(flip[0]) ^ swap(flip[1])) +% seed);
        const hi = swap(blk[1]) ^ ((swap(flip[2]) ^ swap(flip[3])) -% seed);
        const combined = @as(u64, input.len) +% @byteSwap(lo) +% hi +% fold(lo, hi);
        return avalanche(.h3, combined);
    }

    fn hash128(seed: u64, input: anytype, noalias secret: *const [192]u8) u64 {
        @setCold(true);
        std.debug.assert(input.len > 16 and input.len <= 128);

        var acc = XxHash64.prime_1 *% @as(u64, input.len);
        inline for (0..4) |i| {
            const in_offset = 48 - (i * 16);
            const scrt_offset = 96 - (i * 32);
            if (input.len > scrt_offset) {
                acc +%= mix16(seed, input[in_offset..], secret[scrt_offset..]);
                acc +%= mix16(seed, input[input.len - (in_offset + 16) ..], secret[scrt_offset + 16 ..]);
            }
        }
        return avalanche(.h3, acc);
    }

    fn hash240(seed: u64, input: anytype, noalias secret: *const [192]u8) u64 {
        @setCold(true);
        std.debug.assert(input.len > 128 and input.len <= 240);

        var acc = XxHash64.prime_1 *% @as(u64, input.len);
        inline for (0..8) |i| {
            acc +%= mix16(seed, input[i * 16 ..], secret[i * 16 ..]);
        }

        var acc_end = mix16(seed, input[input.len - 16 ..], secret[136 - 17 ..]);
        for (8..(input.len / 16)) |i| {
            acc_end +%= mix16(seed, input[i * 16 ..], secret[((i - 8) * 16) + 3 ..]);
            disableAutoVectorization(i);
        }

        acc = avalanche(.h3, acc) +% acc_end;
        return avalanche(.h3, acc);
    }

    noinline fn hashLong(seed: u64, input: []const u8) u64 {
        @setCold(true);
        std.debug.assert(input.len >= 240);

        const block_count = ((input.len - 1) / @sizeOf(Block)) * @sizeOf(Block);
        const last_block = input[input.len - @sizeOf(Block) ..][0..@sizeOf(Block)];

        var acc = Accumulator.init(seed);
        acc.consume(std.mem.bytesAsSlice(Block, input[0..block_count]));
        return acc.digest(input.len, @ptrCast(last_block));
    }

    // Public API - Streaming

    buffered: usize = 0,
    buffer: [256]u8 = undefined,
    total_len: usize = 0,
    accumulator: Accumulator,

    pub fn init(seed: u64) XxHash3 {
        return .{ .accumulator = Accumulator.init(seed) };
    }

    pub fn update(self: *XxHash3, input: anytype) void {
        self.total_len += input.len;
        std.debug.assert(self.buffered <= self.buffer.len);

        // Copy the input into the buffer if we haven't filled it up yet.
        const remaining = self.buffer.len - self.buffered;
        if (input.len <= remaining) {
            @memcpy(self.buffer[self.buffered..][0..input.len], input);
            self.buffered += input.len;
            return;
        }

        // Input will overflow the buffer. Fill up the buffer with some input and consume it.
        var consumable: []const u8 = input;
        if (self.buffered > 0) {
            @memcpy(self.buffer[self.buffered..], consumable[0..remaining]);
            consumable = consumable[remaining..];

            self.accumulator.consume(std.mem.bytesAsSlice(Block, &self.buffer));
            self.buffered = 0;
        }

        // The input isn't small enough to fit in the buffer. Consume it directly.
        if (consumable.len > self.buffer.len) {
            const block_count = ((consumable.len - 1) / @sizeOf(Block)) * @sizeOf(Block);
            self.accumulator.consume(std.mem.bytesAsSlice(Block, consumable[0..block_count]));
            consumable = consumable[block_count..];

            // In case we consume all remaining input, write the last block to end of the buffer
            // to populate the last_block_copy in final() similar to hashLong()'s last_block.
            @memcpy(
                self.buffer[self.buffer.len - @sizeOf(Block) .. self.buffer.len],
                (consumable.ptr - @sizeOf(Block))[0..@sizeOf(Block)],
            );
        }

        // Copy in any remaining input into the buffer.
        std.debug.assert(consumable.len <= self.buffer.len);
        @memcpy(self.buffer[0..consumable.len], consumable);
        self.buffered = consumable.len;
    }

    pub fn final(self: *XxHash3) u64 {
        std.debug.assert(self.buffered <= self.total_len);
        std.debug.assert(self.buffered <= self.buffer.len);

        // Use Oneshot hashing for smaller sizes as it doesn't use Accumulator like hashLong.
        if (self.total_len <= 240) {
            return hash(self.accumulator.seed, self.buffer[0..self.total_len]);
        }

        // Make a copy of the Accumulator state in case `self` needs to update() / be used later.
        var accumulator_copy = self.accumulator;
        var last_block_copy: [@sizeOf(Block)]u8 = undefined;

        // Digest the last block onthe Accumulator copy.
        return accumulator_copy.digest(self.total_len, last_block: {
            if (self.buffered >= @sizeOf(Block)) {
                const block_count = ((self.buffered - 1) / @sizeOf(Block)) * @sizeOf(Block);
                accumulator_copy.consume(std.mem.bytesAsSlice(Block, self.buffer[0..block_count]));
                break :last_block @ptrCast(self.buffer[self.buffered - @sizeOf(Block) ..][0..@sizeOf(Block)]);
            } else {
                const remaining = @sizeOf(Block) - self.buffered;
                @memcpy(last_block_copy[0..remaining], self.buffer[self.buffer.len - remaining ..][0..remaining]);
                @memcpy(last_block_copy[remaining..][0..self.buffered], self.buffer[0..self.buffered]);
                break :last_block @ptrCast(&last_block_copy);
            }
        });
    }
};

const verify = @import("verify.zig");

fn testExpect(comptime H: type, seed: anytype, input: []const u8, expected: u64) !void {
    try expectEqual(expected, H.hash(seed, input));

    var hasher = H.init(seed);
    hasher.update(input);
    try expectEqual(expected, hasher.final());
}

test "xxhash3" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const H = XxHash3;
    // Non-Seeded Tests
    try testExpect(H, 0, "", 0x2d06800538d394c2);
    try testExpect(H, 0, "a", 0xe6c632b61e964e1f);
    try testExpect(H, 0, "abc", 0x78af5f94892f3950);
    try testExpect(H, 0, "message", 0x0b1ca9b8977554fa);
    try testExpect(H, 0, "message digest", 0x160d8e9329be94f9);
    try testExpect(H, 0, "abcdefghijklmnopqrstuvwxyz", 0x810f9ca067fbb90c);
    try testExpect(H, 0, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", 0x643542bb51639cb2);
    try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890", 0x7f58aa2520c681f9);
    try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678", 0xb66ea795b5edc38c);
    try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890", 0x8845e0b1b57330de);
    try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123123", 0xf031f373d63c5653);
    try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890", 0xf1bf601f9d868dce);

    // Seeded Tests
    try testExpect(H, 1, "", 0x4dc5b0cc826f6703);
    try testExpect(H, 1, "a", 0xd2f6d0996f37a720);
    try testExpect(H, 1, "abc", 0x6b4467b443c76228);
    try testExpect(H, 1, "message", 0x73fb1cf20d561766);
    try testExpect(H, 1, "message digest", 0xfe71a82a70381174);
    try testExpect(H, 1, "abcdefghijklmnopqrstuvwxyz", 0x902a2c2d016a37ba);
    try testExpect(H, 1, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", 0xbf552e540c5c6882);
    try testExpect(H, 1, "12345678901234567890123456789012345678901234567890123456789012345678901234567890", 0xf2ca33235a6b865b);
    try testExpect(H, 1, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678", 0x6ef5cf958ba52c4);
    try testExpect(H, 1, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890", 0xfbc5f9c53d21cb2f);
    try testExpect(H, 1, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123123", 0x48682aca3b1c5c18);
    try testExpect(H, 1, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890", 0x3903c5437fc4e726);
}

test "xxhash3 smhasher" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const Test = struct {
        fn do() !void {
            try expectEqual(verify.smhasher(XxHash3.hash), 0x9a636405);
        }
    };
    try Test.do();
    @setEvalBranchQuota(75000);
    comptime try Test.do();
}

test "xxhash3 iterative api" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

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
