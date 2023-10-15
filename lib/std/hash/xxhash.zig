const std = @import("std");
const builtin = @import("builtin");
const mem = std.mem;
const expectEqual = std.testing.expectEqual;

const rotl = std.math.rotl;

pub const XxHash3 = struct {
    const Block = @Vector(8, u64);
    const default_secret: [@sizeOf(Block) * 3]u8 = @bitCast([_]u64{
        0xbe4ba423396cfeb8, 0x1cad21f72c81017c, 0xdb979083e96dd4de, 0x1f67b3b7a4a44072,
        0x78e5c0cc4ee679cb, 0x2172ffcc7dd05a82, 0x8e2443f7744608b8, 0x4c263a81e69035e0,
        0xcb00c391bb52283c, 0xa32e531b8b65d088, 0x4ef90da297486471, 0xd8acdea946ef1938,
        0x3f349ce33f76faa8, 0x1d4f0bc7c7bbdcf9, 0x3159b4cd4be0518a, 0x647378d9c97e9fc8,
        0xc3ebd33483acc5ea, 0xeb6313faffa081c5, 0x49daf0b751dd0d17, 0x9e68d429265516d3,
        0xfca1477d58be162b, 0xce31d07ad1b8f88f, 0x280416958f3acb45, 0x7e404bbbcafbd7af,
    });

    const primes = [_]u64{
        0x9E3779B185EBCA87,
        0xC2B2AE3D27D4EB4F,
        0x165667B19E3779F9,
        0x85EBCA77C2B2AE63,
        0x27D4EB2F165667C5,
        0x165667919E3779F9,
        0x9FB21C651E98DF25,
    };

    inline fn swap(x: anytype) @TypeOf(x) {
        return if (builtin.cpu.arch.endian() == .Big) @byteSwap(x) else x;
    }

    inline fn read(comptime int: type, data: []const u8) int {
        return std.mem.readIntLittle(int, data[0..@sizeOf(int)]);
    }

    inline fn avalanche(mode: union(enum) { h3, h64, rrmxmx: u64 }, x0: u64) u64 {
        switch (mode) {
            .h3 => {
                const x1 = (x0 ^ (x0 >> 37)) *% primes[5];
                return x1 ^ (x1 >> 32);
            },
            .h64 => {
                const x1 = (x0 ^ (x0 >> 33)) *% primes[1];
                const x2 = (x1 ^ (x1 >> 29)) *% primes[2];

                return x2 ^ (x2 >> 32);
            },
            .rrmxmx => |len| {
                const x1 = (x0 ^ rotl(u64, x0, 49) ^ rotl(u64, x0, 24)) *% primes[6];
                const x2 = (x1 ^ ((x1 >> 35) +% len)) *% primes[6];
                return x2 ^ (x2 >> 28);
            },
        }
    }

    inline fn fold(a: u64, b: u64) u64 {
        const wide: [2]u64 = @bitCast(@as(u128, a) *% b);
        return wide[0] ^ wide[1];
    }

    inline fn mix16(input: []const u8, secret: []const u8, seed: u64) u64 {
        const blocks: [4]u64 = @bitCast([_][16]u8{ input[0..16].*, @bitCast(read(u128, secret[0..16])) });
        const lo = blocks[0] ^ (blocks[2] +% seed);
        const hi = blocks[1] ^ (blocks[3] -% seed);
        return fold(lo, hi);
    }

    const State = struct {
        block_count: u32 = 0,
        seed: u64,
        custom_secret: [192]u8 = undefined,
        accumulator: Block = @bitCast([_]u64{
            primes[1] >> 32,
            primes[0],
            primes[1],
            primes[2],
            primes[3],
            primes[3] >> 32,
            primes[4],
            primes[0] >> 32,
        }),

        inline fn init(seed: u64) State {
            var self = State{ .seed = seed };
            if (seed != 0) {
                const mix_seed: u128 = @bitCast([_]u64{ seed, @as(u64, 0) -% seed });
                const mix_block: Block = @bitCast(@as(@Vector(4, u128), @splat(mix_seed)));
                for (
                    std.mem.bytesAsSlice(Block, &self.custom_secret),
                    std.mem.bytesAsSlice(Block, &default_secret),
                ) |*dst, src| dst.* = src +% mix_block;
            }
            return self;
        }

        inline fn getSecret(self: *const State) *const [192]u8 {
            const secret_ptrs = [_]*const [192]u8{ &default_secret, &self.custom_secret };
            return secret_ptrs[@intFromBool(self.seed != 0)];
        }

        inline fn round(
            noalias self: *State,
            noalias input_block: *align(1) const Block,
            noalias secret_block: *align(1) const Block,
        ) void {
            const keyed = input_block.* ^ secret_block.*;
            const product = (keyed & @as(Block, @splat(0xffffffff))) *% (keyed >> @splat(32));
            const swapped = @shuffle(u64, input_block.*, undefined, [_]i32{ 1, 0, 3, 2, 5, 4, 7, 6 });
            self.accumulator +%= product +% swapped;
        }

        fn update(noalias self: *State, input_blocks: []align(1) const Block) void {
            const blocks_per_scramble = @divExact(1024, @sizeOf(Block));
            std.debug.assert(self.block_count <= blocks_per_scramble);
            const secret = self.getSecret();

            var blocks = input_blocks;
            while (blocks.len > 0) {
                const blocks_until_scramble = blocks_per_scramble - self.block_count;
                const scramble = blocks.len >= blocks_until_scramble;

                const round_sizes = [_]usize{ blocks.len, blocks_until_scramble };
                const round_size: u32 = @intCast(round_sizes[@intFromBool(scramble)]);
                defer blocks = blocks[round_size..];

                for (
                    blocks[0..round_size],
                    std.mem.bytesAsSlice(u64, secret[self.block_count * 8 ..])[0..round_size],
                ) |*block, *secret_block| {
                    @prefetch(@as([*]align(1) const Block, @ptrCast(block)) + @sizeOf(Block), .{});
                    self.round(block, @ptrCast(secret_block));
                }

                if (scramble) {
                    self.accumulator ^= self.accumulator >> @splat(47);
                    self.accumulator ^= @bitCast(secret[secret.len - @sizeOf(Block) .. secret.len].*);
                    self.accumulator *%= @as(Block, @splat(primes[0] >> 32));
                    self.block_count = 0;
                } else {
                    self.block_count += round_size;
                    return;
                }
            }
        }

        fn final(noalias self: *State, noalias last_block: *align(1) const Block, len: u64) u64 {
            const secret = self.getSecret();
            const last_secret_block = secret[secret.len - @sizeOf(Block) - 7 ..][0..@sizeOf(Block)];

            self.round(last_block, @ptrCast(last_secret_block));
            self.accumulator ^= @bitCast(secret[11 .. 11 + @sizeOf(Block)].*);

            var result = len *% primes[0];
            inline for (@as([4][2]u64, @bitCast(self.accumulator))) |pair| {
                result +%= fold(pair[0], pair[1]);
            }
            return avalanche(.h3, result);
        }
    };

    pub fn hash(seed: u64, input: anytype) u64 {
        validateType(@TypeOf(input));

        if (input.len <= 240) {
            return hashSmall(seed, input, &default_secret);
        } else {
            return hashLarge(seed, input);
        }
    }

    fn hashSmall(seed: u64, input: anytype, noalias secret: *const [192]u8) u64 {
        if (input.len == 0) {
            const flip: [2]u64 = @bitCast(secret[56..72].*);
            return avalanche(.h64, seed ^ (flip[0] ^ flip[1]));
        }

        if (input.len < 4) {
            const blk: u32 = @bitCast([_]u8{
                input[input.len - 1],
                @truncate(input.len),
                input[0],
                input[input.len / 2],
            });
            var flip: [2]u32 = @bitCast(secret[0..8].*);

            flip = switch (builtin.cpu.arch.endian()) {
                .Little => flip,
                .Big => blk: {
                    std.mem.swap(u32, &flip[0], &flip[1]);
                    break :blk flip;
                },
            };

            return avalanche(.h64, seed +% swap(blk) ^ (flip[0] ^ flip[1]));
        }

        if (input.len <= 8) {
            var blk: u64 = @bitCast([_][4]u8{
                input[input.len - 4 ..][0..4].*,
                input[0..4].*,
            });
            blk = swap(blk);
            const flip: [2]u64 = @bitCast(secret[8..24].*);
            const swapped = seed ^ (@as(u64, @byteSwap(@as(u32, @truncate(seed)))) << 32);
            const keyed = ((flip[0] ^ flip[1]) -% swapped) ^ blk;
            return avalanche(.{ .rrmxmx = input.len }, keyed);
        }

        if (input.len <= 16) {
            var blk: [2]u64 = .{
                read(u64, input[0..8]),
                read(u64, input[input.len - 8 ..][0..8]),
            };

            const flip: [4]u64 = @bitCast(secret[24..56].*);
            blk[0] ^= (flip[0] ^ flip[1]) +% seed;
            blk[1] ^= (flip[2] ^ flip[3]) -% seed;
            const keyed = fold(blk[0], blk[1]) +% blk[1] +% @byteSwap(blk[0]) +% input.len;
            return avalanche(.h3, keyed);
        }

        if (input.len <= 128) {
            var acc = primes[0] *% input.len;

            inline for (0..4) |i| {
                const s_offset = 96 - (i * 32);
                const i_offset = 48 - (i * 16);
                if (input.len > s_offset) {
                    acc +%= mix16(input[i_offset..], secret[s_offset..], seed);
                    acc +%= mix16(input[input.len - (i_offset + 16) ..], secret[s_offset + 16 ..], seed);
                }
            }
            return avalanche(.h3, acc);
        }

        std.debug.assert(input.len <= 240);
        {
            var acc0 = primes[0] *% input.len;
            for (0..8) |i| {
                acc0 +%= mix16(input[16 * i ..], secret[16 * i ..], seed);
            }

            var acc1 = mix16(input[input.len - 16 ..], secret[136 - 17 ..], seed);
            for (8..input.len / 16) |i| {
                acc1 +%= mix16(input[16 * i ..], secret[(16 * (i - 8)) + 3 ..], seed);
            }

            acc0 = avalanche(.h3, acc0) +% acc1;
            return avalanche(.h3, acc0);
        }
    }

    fn hashLarge(seed: u64, input: []const u8) u64 {
        @setCold(true);

        var state = State.init(seed);
        std.debug.assert(input.len > 240);

        const input_blocks = input[0 .. ((input.len - 1) / @sizeOf(Block)) * @sizeOf(Block)];
        state.update(std.mem.bytesAsSlice(Block, input_blocks));

        const last_block = input[input.len - @sizeOf(Block) ..][0..@sizeOf(Block)];
        return state.final(@ptrCast(last_block), input.len);
    }

    total_len: usize = 0,
    buffer_size: u32 = 0,
    state: State,
    buffer: [256]u8 = undefined,

    pub fn init(seed: u64) XxHash3 {
        return .{ .state = State.init(seed) };
    }

    pub fn update(self: *XxHash3, input: anytype) void {
        validateType(@TypeOf(input));

        self.total_len += input.len;
        std.debug.assert(self.buffer_size <= self.buffer.len);

        const remaining = self.buffer.len - self.buffer_size;
        if (input.len <= remaining) {
            @memcpy(self.buffer[self.buffer_size..][0..input.len], input);
            self.buffer_size += @intCast(input.len);
            return;
        }

        var leftover: []const u8 = input;
        if (self.buffer_size > 0) {
            @memcpy(self.buffer[self.buffer_size..][0..remaining], leftover[0..remaining]);
            leftover = leftover[remaining..];

            self.state.update(std.mem.bytesAsSlice(Block, &self.buffer));
            self.buffer_size = 0;
        }

        if (leftover.len > self.buffer.len) {
            const consume = ((leftover.len - 1) / @sizeOf(Block)) * @sizeOf(Block);
            self.state.update(std.mem.bytesAsSlice(Block, leftover[0..consume]));
            leftover = leftover[consume..];

            @memcpy(
                self.buffer[self.buffer.len - @sizeOf(Block) ..],
                (leftover.ptr - @sizeOf(Block))[0..@sizeOf(Block)],
            );
        }

        @memcpy(self.buffer[0..leftover.len], leftover);
        self.buffer_size = @intCast(leftover.len);
    }

    pub fn final(self: *XxHash3) u64 {
        if (self.total_len <= 240) {
            return hashSmall(self.state.seed, self.buffer[0..self.total_len], self.state.getSecret());
        }

        var state_copy = self.state;
        var last_block: [@sizeOf(Block)]u8 = undefined;
        std.debug.assert(self.buffer_size <= self.buffer.len);

        const last_block_ptr: *align(1) const Block = if (self.buffer_size >= @sizeOf(Block)) last_blk: {
            const consume = ((self.buffer_size - 1) / @sizeOf(Block)) * @sizeOf(Block);
            state_copy.update(std.mem.bytesAsSlice(Block, self.buffer[0..consume]));
            break :last_blk @ptrCast(&self.buffer[self.buffer_size - @sizeOf(Block)]);
        } else last_blk: {
            const leftover = @sizeOf(Block) - self.buffer_size;
            @memcpy(last_block[0..leftover], self.buffer[self.buffer.len - leftover ..][0..leftover]);
            @memcpy(last_block[leftover..][0..self.buffer_size], self.buffer[0..self.buffer_size]);
            break :last_blk @ptrCast(&last_block);
        };

        return state_copy.final(last_block_ptr, self.total_len);
    }
};

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

const verify = @import("verify.zig");

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

test "xxhash3" {
    const H = XxHash3;

    try testExpect(H, 0, "", 0x2d06800538d394c2);
    try testExpect(H, 0, "a", 0xe6c632b61e964e1f);
    try testExpect(H, 0, "abc", 0x78af5f94892f3950);
    try testExpect(H, 0, "message", 0x0b1ca9b8977554fa);
    try testExpect(H, 0, "message digest", 0x160d8e9329be94f9);
    try testExpect(H, 0, "abcdefghijklmnopqrstuvwxyz", 0x810f9ca067fbb90c);
    try testExpect(H, 0, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789", 0x643542bb51639cb2);
    try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890", 0x7f58aa2520c681f9);
    try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890", 0x8845e0b1b57330de);
    try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123123", 0xf031f373d63c5653);
    try testExpect(H, 0, "12345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890", 0xf1bf601f9d868dce);
}

test "xxhash3 smhasher" {
    const Test = struct {
        fn do() !void {
            const result = verify.smhasher(XxHash3.hash);
            std.debug.assert(result == 0x9a636405);
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
