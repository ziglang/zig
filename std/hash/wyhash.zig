const std = @import("std");
const mem = std.mem;

const primes = [_]u64{
    0xa0761d6478bd642f,
    0xe7037ed1a0b428db,
    0x8ebc6af09c88c6e3,
    0x589965cc75374cc3,
    0x1d8e4e27c47d124f,
};

fn read_bytes(comptime bytes: u8, data: []const u8) u64 {
    return mem.readVarInt(u64, data[0..bytes], .Little);
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

pub const Wyhash = struct {
    seed: u64,
    msg_len: usize,

    pub fn init(seed: u64) Wyhash {
        return Wyhash{
            .seed = seed,
            .msg_len = 0,
        };
    }

    fn round(self: *Wyhash, b: []const u8) void {
        std.debug.assert(b.len == 32);

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

    fn partial(self: *Wyhash, b: []const u8) void {
        const rem_key = b;
        const rem_len = b.len;

        var seed = self.seed;
        seed = switch (@intCast(u5, rem_len)) {
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
        self.seed = seed;
    }

    pub fn update(self: *Wyhash, b: []const u8) void {
        var off: usize = 0;

        // Full middle blocks.
        while (off + 32 <= b.len) : (off += 32) {
            @inlineCall(self.round, b[off .. off + 32]);
        }

        self.partial(b[off..]);
        self.msg_len += b.len;
    }

    pub fn final(self: *Wyhash) u64 {
        return mum(self.seed ^ self.msg_len, primes[4]);
    }

    pub fn hash(seed: u64, input: []const u8) u64 {
        var c = Wyhash.init(seed);
        @inlineCall(c.update, input);
        return @inlineCall(c.final);
    }
};

test "test vectors" {
    const expectEqual = std.testing.expectEqual;
    const hash = Wyhash.hash;

    expectEqual(hash(0, ""), 0x0);
    expectEqual(hash(1, "a"), 0xbed235177f41d328);
    expectEqual(hash(2, "abc"), 0xbe348debe59b27c3);
    expectEqual(hash(3, "message digest"), 0x37320f657213a290);
    expectEqual(hash(4, "abcdefghijklmnopqrstuvwxyz"), 0xd0b270e1d8a7019c);
    expectEqual(hash(5, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"), 0x602a1894d3bbfe7f);
    expectEqual(hash(6, "12345678901234567890123456789012345678901234567890123456789012345678901234567890"), 0x829e9c148b75970e);
}
