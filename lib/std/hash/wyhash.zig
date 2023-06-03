const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

const primes = [_]u64{
    0xa0761d6478bd642f,
    0xe7037ed1a0b428db,
    0x8ebc6af09c88c6e3,
    0x589965cc75374cc3,
    0x1d8e4e27c47d124f,
};

// Wyhash version which does not store internal state for handling partial buffers.
// This is needed so that we can maximize the speed for the short key case, which will
// use the non-iterative api which the public Wyhash exposes.
const WyhashStateless = struct {
    seed: u64,
    msg_len: usize,

    pub fn init(seed: u64) WyhashStateless {
        return WyhashStateless{
            .seed = seed,
            .msg_len = 0,
        };
    }

    fn round(self: *WyhashStateless, b: []const u8) void {
        assert(b.len == 32);

        self.seed = mix0(
            read_bytes(8, b[0..]),
            read_bytes(8, b[8..]),
            self.seed,
        ) ^ mix1(
            read_bytes(8, b[16..]),
            read_bytes(8, b[24..]),
            self.seed,
        );
    }

    pub fn update(self: *WyhashStateless, b: []const u8) void {
        assert(b.len % 32 == 0);

        var off: usize = 0;
        while (off < b.len) : (off += 32) {
            @call(.always_inline, round, .{ self, b[off..][0..32] });
        }

        self.msg_len += b.len;
    }

    pub fn final(self: *WyhashStateless, b: []const u8) u64 {
        assert(b.len < 32);

        const seed = self.seed;
        const rem_len = @intCast(u5, b.len);
        const rem_key = b[0..rem_len];

        self.seed = switch (rem_len) {
            0 => seed,
            1 => mix0(read_bytes(1, rem_key), primes[4], seed),
            2 => mix0(read_bytes(2, rem_key), primes[4], seed),
            3 => mix0((read_bytes(2, rem_key) << 8) | read_bytes(1, rem_key[2..]), primes[4], seed),
            4 => mix0(read_bytes(4, rem_key), primes[4], seed),
            5 => mix0((read_bytes(4, rem_key) << 8) | read_bytes(1, rem_key[4..]), primes[4], seed),
            6 => mix0((read_bytes(4, rem_key) << 16) | read_bytes(2, rem_key[4..]), primes[4], seed),
            7 => mix0((read_bytes(4, rem_key) << 24) | (read_bytes(2, rem_key[4..]) << 8) | read_bytes(1, rem_key[6..]), primes[4], seed),
            8 => mix0(read_8bytes_swapped(rem_key), primes[4], seed),
            9 => mix0(read_8bytes_swapped(rem_key), read_bytes(1, rem_key[8..]), seed),
            10 => mix0(read_8bytes_swapped(rem_key), read_bytes(2, rem_key[8..]), seed),
            11 => mix0(read_8bytes_swapped(rem_key), (read_bytes(2, rem_key[8..]) << 8) | read_bytes(1, rem_key[10..]), seed),
            12 => mix0(read_8bytes_swapped(rem_key), read_bytes(4, rem_key[8..]), seed),
            13 => mix0(read_8bytes_swapped(rem_key), (read_bytes(4, rem_key[8..]) << 8) | read_bytes(1, rem_key[12..]), seed),
            14 => mix0(read_8bytes_swapped(rem_key), (read_bytes(4, rem_key[8..]) << 16) | read_bytes(2, rem_key[12..]), seed),
            15 => mix0(read_8bytes_swapped(rem_key), (read_bytes(4, rem_key[8..]) << 24) | (read_bytes(2, rem_key[12..]) << 8) | read_bytes(1, rem_key[14..]), seed),
            16 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed),
            17 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1(read_bytes(1, rem_key[16..]), primes[4], seed),
            18 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1(read_bytes(2, rem_key[16..]), primes[4], seed),
            19 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1((read_bytes(2, rem_key[16..]) << 8) | read_bytes(1, rem_key[18..]), primes[4], seed),
            20 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1(read_bytes(4, rem_key[16..]), primes[4], seed),
            21 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1((read_bytes(4, rem_key[16..]) << 8) | read_bytes(1, rem_key[20..]), primes[4], seed),
            22 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1((read_bytes(4, rem_key[16..]) << 16) | read_bytes(2, rem_key[20..]), primes[4], seed),
            23 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1((read_bytes(4, rem_key[16..]) << 24) | (read_bytes(2, rem_key[20..]) << 8) | read_bytes(1, rem_key[22..]), primes[4], seed),
            24 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1(read_8bytes_swapped(rem_key[16..]), primes[4], seed),
            25 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1(read_8bytes_swapped(rem_key[16..]), read_bytes(1, rem_key[24..]), seed),
            26 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1(read_8bytes_swapped(rem_key[16..]), read_bytes(2, rem_key[24..]), seed),
            27 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1(read_8bytes_swapped(rem_key[16..]), (read_bytes(2, rem_key[24..]) << 8) | read_bytes(1, rem_key[26..]), seed),
            28 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1(read_8bytes_swapped(rem_key[16..]), read_bytes(4, rem_key[24..]), seed),
            29 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1(read_8bytes_swapped(rem_key[16..]), (read_bytes(4, rem_key[24..]) << 8) | read_bytes(1, rem_key[28..]), seed),
            30 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1(read_8bytes_swapped(rem_key[16..]), (read_bytes(4, rem_key[24..]) << 16) | read_bytes(2, rem_key[28..]), seed),
            31 => mix0(read_8bytes_swapped(rem_key), read_8bytes_swapped(rem_key[8..]), seed) ^ mix1(read_8bytes_swapped(rem_key[16..]), (read_bytes(4, rem_key[24..]) << 24) | (read_bytes(2, rem_key[28..]) << 8) | read_bytes(1, rem_key[30..]), seed),
        };

        self.msg_len += b.len;
        return mum(self.seed ^ self.msg_len, primes[4]);
    }

    fn read_bytes(comptime bytes: u8, data: []const u8) u64 {
        const T = std.meta.Int(.unsigned, 8 * bytes);
        return mem.readIntLittle(T, data[0..bytes]);
    }

    fn read_8bytes_swapped(data: []const u8) u64 {
        return (read_bytes(4, data) << 32 | read_bytes(4, data[4..]));
    }

    fn mum(a: u64, b: u64) u64 {
        var r = std.math.mulWide(u64, a, b);
        r = (r >> 64) ^ r;
        return @truncate(u64, r);
    }

    fn mix0(a: u64, b: u64, seed: u64) u64 {
        return mum(a ^ seed ^ primes[0], b ^ seed ^ primes[1]);
    }

    fn mix1(a: u64, b: u64, seed: u64) u64 {
        return mum(a ^ seed ^ primes[2], b ^ seed ^ primes[3]);
    }
};

/// Fast non-cryptographic 64bit hash function.
/// See https://github.com/wangyi-fudan/wyhash
pub const Wyhash = struct {
    state: WyhashStateless,

    buf: [32]u8,
    buf_len: usize,

    pub fn init(seed: u64) Wyhash {
        return Wyhash{
            .state = WyhashStateless.init(seed),
            .buf = undefined,
            .buf_len = 0,
        };
    }

    pub fn update(self: *Wyhash, b: []const u8) void {
        var off: usize = 0;

        if (self.buf_len != 0 and self.buf_len + b.len >= 32) {
            off += 32 - self.buf_len;
            @memcpy(self.buf[self.buf_len..][0..off], b[0..off]);
            self.state.update(self.buf[0..]);
            self.buf_len = 0;
        }

        const remain_len = b.len - off;
        const aligned_len = remain_len - (remain_len % 32);
        self.state.update(b[off .. off + aligned_len]);

        const src = b[off + aligned_len ..];
        @memcpy(self.buf[self.buf_len..][0..src.len], src);
        self.buf_len += @intCast(u8, b[off + aligned_len ..].len);
    }

    pub fn final(self: *Wyhash) u64 {
        const rem_key = self.buf[0..self.buf_len];

        return self.state.final(rem_key);
    }

    /// `input` is a slice or array.
    pub fn hash(seed: u64, input: anytype) u64 {
        var in: []const u8 = input;
        var last = [2]u64{ 0, 0 };
        const starting_len: u64 = input.len;
        var state = seed ^ mix(seed ^ primes[0], primes[1]);

        if (in.len <= 16) {
            if (in.len >= 4) {
                const end = (in.len >> 3) << 2;
                last[0] = (@as(u64, read(u32, in)) << 32) | read(u32, in[end..]);
                last[1] = (@as(u64, read(u32, in[in.len - 4 ..])) << 32) | read(u32, in[in.len - 4 - end ..]);
            } else if (in.len > 0) {
                last[0] = (@as(u64, in[0]) << 16) | (@as(u64, in[in.len >> 1]) << 8) | in[in.len - 1];
            }
        } else {
            large: {
                if (in.len <= 48) break :large;
                var split = [_]u64{ state, state, state };
                while (true) {
                    for (&split, 0..) |*lane, i| {
                        const a = read(u64, in[(i * 2) * 8 ..]) ^ primes[i + 1];
                        const b = read(u64, in[((i * 2) + 1) * 8 ..]) ^ lane.*;
                        lane.* = mix(a, b);
                    }
                    in = in[48..];
                    if (in.len > 48) continue;
                    state = split[0] ^ (split[1] ^ split[2]);
                    break :large;
                }
            }
            while (in.len > 16) {
                state = mix(read(u64, in) ^ primes[1], read(u64, in[8..]) ^ state);
                in = in[16..];
            }
            last[0] = read(u64, (in.ptr + in.len - 16)[0..8]);
            last[1] = read(u64, (in.ptr + in.len - 8)[0..8]);
        }

        last[0] ^= primes[1];
        last[1] ^= state;
        mum(&last);
        return mix(last[0] ^ primes[0] ^ starting_len, last[1] ^ primes[1]);
    }

    inline fn mum(pair: *[2]u64) void {
        const x = @as(u128, pair[0]) *% pair[1];
        pair[0] = @truncate(u64, x);
        pair[1] = @truncate(u64, x >> 64);
    }

    inline fn mix(a: u64, b: u64) u64 {
        var pair = [_]u64{ a, b };
        mum(&pair);
        return pair[0] ^ pair[1];
    }

    inline fn read(comptime I: type, in: []const u8) I {
        return std.mem.readIntLittle(I, in[0..@sizeOf(I)]);
    }
};

const expectEqual = std.testing.expectEqual;

test "test vectors" {
    if (true) return error.SkipZigTest; // TODO get these passing
    const hash = Wyhash.hash;

    try expectEqual(@as(u64, 0x42bc986dc5eec4d3), hash(0, ""));
    try expectEqual(@as(u64, 0x84508dc903c31551), hash(1, "a"));
    try expectEqual(@as(u64, 0x0bc54887cfc9ecb1), hash(2, "abc"));
    try expectEqual(@as(u64, 0x6e2ff3298208a67c), hash(3, "message digest"));
    try expectEqual(@as(u64, 0x9a64e42e897195b9), hash(4, "abcdefghijklmnopqrstuvwxyz"));
    try expectEqual(@as(u64, 0x9199383239c32554), hash(5, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"));
    try expectEqual(@as(u64, 0x7c1ccf6bba30f5a5), hash(6, "1234567890123456789012345678901234567890123456789012345678901234567890"));
}

test "test vectors streaming" {
    if (true) return error.SkipZigTest; // TODO get these passing
    var wh = Wyhash.init(5);
    for ("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") |e| {
        wh.update(mem.asBytes(&e));
    }
    try expectEqual(@as(u64, 0x602a1894d3bbfe7f), wh.final());

    const pattern = "1234567890";
    const count = 8;
    const result: u64 = 0x829e9c148b75970e;
    try expectEqual(result, Wyhash.hash(6, pattern ** 8));

    wh = Wyhash.init(6);
    var i: u32 = 0;
    while (i < count) : (i += 1) {
        wh.update(pattern);
    }
    try expectEqual(result, wh.final());
}

test "iterative non-divisible update" {
    if (true) return error.SkipZigTest; // TODO get these passing
    var buf: [8192]u8 = undefined;
    for (&buf, 0..) |*e, i| {
        e.* = @truncate(u8, i);
    }

    const seed = 0x128dad08f;

    var end: usize = 32;
    while (end < buf.len) : (end += 32) {
        const non_iterative_hash = Wyhash.hash(seed, buf[0..end]);

        var wy = Wyhash.init(seed);
        var i: usize = 0;
        while (i < end) : (i += 33) {
            wy.update(buf[i..std.math.min(i + 33, end)]);
        }
        const iterative_hash = wy.final();

        try std.testing.expectEqual(iterative_hash, non_iterative_hash);
    }
}
