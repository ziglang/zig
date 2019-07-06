const std = @import("std");
const builtin = @import("builtin");

const default_seed: u32 = 0xc70f6907;

pub const Murmur2_32 = struct {
    const Self = @This();

    pub fn hash(str: []const u8) u32 {
        return @inlineCall(Self.hashWithSeed, str, default_seed);
    }

    pub fn hashWithSeed(str: []const u8, seed: u32) u32 {
        const m: u32 = 0x5bd1e995;
        const len = @intCast(u32, str.len);
        var h1: u32 = seed ^ len;
        for (@ptrCast([*]allowzero align(1) const u32, str.ptr)[0..(len >> 2)]) |v| {
            var k1: u32 = v;
            if (builtin.endian == builtin.Endian.Big)
                k1 = @byteSwap(u32, k1);
            k1 *%= m;
            k1 ^= k1 >> 24;
            k1 *%= m;
            h1 *%= m;
            h1 ^= k1;
        }
        const offset = len & 0xfffffffc;
        const rest = len & 3;
        if (rest >= 3) {
            h1 ^= @intCast(u32, str[offset + 2]) << 16;
        }
        if (rest >= 2) {
            h1 ^= @intCast(u32, str[offset + 1]) << 8;
        }
        if (rest >= 1) {
            h1 ^= @intCast(u32, str[offset + 0]);
            h1 *%= m;
        }
        h1 ^= h1 >> 13;
        h1 *%= m;
        h1 ^= h1 >> 15;
        return h1;
    }

    pub fn hashUint32(v: u32) u32 {
        return @inlineCall(Self.hashUint32WithSeed, v, default_seed);
    }

    pub fn hashUint32WithSeed(v: u32, seed: u32) u32 {
        const m: u32 = 0x5bd1e995;
        const len: u32 = 4;
        var h1: u32 = seed ^ len;
        var k1: u32 = undefined;
        k1 = v *% m;
        k1 ^= k1 >> 24;
        k1 *%= m;
        h1 *%= m;
        h1 ^= k1;
        h1 ^= h1 >> 13;
        h1 *%= m;
        h1 ^= h1 >> 15;
        return h1;
    }

    pub fn hashUint64(v: u64) u32 {
        return @inlineCall(Self.hashUint64WithSeed, v, default_seed);
    }

    pub fn hashUint64WithSeed(v: u64, seed: u32) u32 {
        const m: u32 = 0x5bd1e995;
        const len: u32 = 4;
        var h1: u32 = seed ^ len;
        var k1: u32 = undefined;
        k1 = @intCast(u32, v) *% m;
        k1 ^= k1 >> 24;
        k1 *%= m;
        h1 *%= m;
        h1 ^= k1;
        k1 = @intCast(u32, v >> 32) *% m;
        k1 ^= k1 >> 24;
        k1 *%= m;
        h1 *%= m;
        h1 ^= k1;
        h1 ^= h1 >> 13;
        h1 *%= m;
        h1 ^= h1 >> 15;
        return h1;
    }
};

pub const Murmur2_64 = struct {
    const Self = @This();

    pub fn hash(str: []const u8) u64 {
        return @inlineCall(Self.hashWithSeed, str, default_seed);
    }

    pub fn hashWithSeed(str: []const u8, seed: u64) u64 {
        const m: u64 = 0xc6a4a7935bd1e995;
        const len = @intCast(u64, str.len);
        var h1: u64 = seed ^ (len *% m);
        for (@ptrCast([*]allowzero align(1) const u64, str.ptr)[0..(len >> 3)]) |v| {
            var k1: u64 = v;
            if (builtin.endian == builtin.Endian.Big)
                k1 = @byteSwap(u64, k1);
            k1 *%= m;
            k1 ^= k1 >> 47;
            k1 *%= m;
            h1 ^= k1;
            h1 *%= m;
        }
        const rest = len & 7;
        const offset = len - rest;
        if (rest > 0) {
            var k1: u64 = 0;
            @memcpy(@ptrCast([*]u8, &k1), @ptrCast([*]const u8, &str[offset]), rest);
            if (builtin.endian == builtin.Endian.Big)
                k1 = @byteSwap(u64, k1);
            h1 ^= k1;
            h1 *%= m;
        }
        h1 ^= h1 >> 47;
        h1 *%= m;
        h1 ^= h1 >> 47;
        return h1;
    }

    pub fn hashUint32(v: u32) u64 {
        return @inlineCall(Self.hashUint32WithSeed, v, default_seed);
    }

    pub fn hashUint32WithSeed(v: u32, seed: u32) u64 {
        const m: u64 = 0xc6a4a7935bd1e995;
        const len: u64 = 4;
        var h1: u64 = seed ^ (len *% m);
        var k1: u64 = undefined;
        k1 = v *% m;
        k1 ^= k1 >> 47;
        k1 *%= m;
        h1 ^= k1;
        h1 *%= m;
        h1 ^= h1 >> 47;
        h1 *%= m;
        h1 ^= h1 >> 47;
        return h1;
    }

    pub fn hashUint64(v: u64) u64 {
        return @inlineCall(Self.hashUint64WithSeed, v, default_seed);
    }

    pub fn hashUint64WithSeed(v: u64, seed: u32) u64 {
        const m: u64 = 0xc6a4a7935bd1e995;
        const len: u64 = 8;
        var h1: u64 = seed ^ (len *% m);
        var k1: u64 = undefined;
        k1 = @intCast(u32, v) *% m;
        k1 ^= k1 >> 47;
        k1 *%= m;
        h1 ^= k1;
        h1 *%= m;
        k1 = @intCast(u32, v >> 32) *% m;
        k1 ^= k1 >> 47;
        k1 *%= m;
        h1 ^= k1;
        h1 *%= m;
        h1 ^= h1 >> 47;
        h1 *%= m;
        h1 ^= h1 >> 47;
        return h1;
    }
};

pub const Murmur3_32 = struct {
    const Self = @This();

    fn rotl32(x: u32, comptime r: u32) u32 {
        return (x << r) | (x >> (32 - r));
    }

    pub fn hash(str: []const u8) u32 {
        return @inlineCall(Self.hashWithSeed, str, default_seed);
    }

    pub fn hashWithSeed(str: []const u8, seed: u32) u32 {
        const c1: u32 = 0xcc9e2d51;
        const c2: u32 = 0x1b873593;
        const len = @intCast(u32, str.len);
        var h1: u32 = seed;
        for (@ptrCast([*]allowzero align(1) const u32, str.ptr)[0..(len >> 2)]) |v| {
            var k1: u32 = v;
            if (builtin.endian == builtin.Endian.Big)
                k1 = @byteSwap(u32, k1);
            k1 *%= c1;
            k1 = rotl32(k1, 15);
            k1 *%= c2;
            h1 ^= k1;
            h1 = rotl32(h1, 13);
            h1 *%= 5;
            h1 +%= 0xe6546b64;
        }
        {
            var k1: u32 = 0;
            const offset = len & 0xfffffffc;
            const rest = len & 3;
            if (rest == 3) {
                k1 ^= @intCast(u32, str[offset + 2]) << 16;
            }
            if (rest >= 2) {
                k1 ^= @intCast(u32, str[offset + 1]) << 8;
            }
            if (rest >= 1) {
                k1 ^= @intCast(u32, str[offset + 0]);
                k1 *%= c1;
                k1 = rotl32(k1, 15);
                k1 *%= c2;
                h1 ^= k1;
            }
        }
        h1 ^= len;
        h1 ^= h1 >> 16;
        h1 *%= 0x85ebca6b;
        h1 ^= h1 >> 13;
        h1 *%= 0xc2b2ae35;
        h1 ^= h1 >> 16;
        return h1;
    }

    pub fn hashUint32(v: u32) u32 {
        return @inlineCall(Self.hashUint32WithSeed, v, default_seed);
    }

    pub fn hashUint32WithSeed(v: u32, seed: u32) u32 {
        const c1: u32 = 0xcc9e2d51;
        const c2: u32 = 0x1b873593;
        const len: u32 = 4;
        var h1: u32 = seed;
        var k1: u32 = undefined;
        k1 = v *% c1;
        k1 = rotl32(k1, 15);
        k1 *%= c2;
        h1 ^= k1;
        h1 = rotl32(h1, 13);
        h1 *%= 5;
        h1 +%= 0xe6546b64;
        h1 ^= len;
        h1 ^= h1 >> 16;
        h1 *%= 0x85ebca6b;
        h1 ^= h1 >> 13;
        h1 *%= 0xc2b2ae35;
        h1 ^= h1 >> 16;
        return h1;
    }

    pub fn hashUint64(v: u64) u32 {
        return @inlineCall(Self.hashUint64WithSeed, v, default_seed);
    }

    pub fn hashUint64WithSeed(v: u64, seed: u32) u32 {
        const c1: u32 = 0xcc9e2d51;
        const c2: u32 = 0x1b873593;
        const len: u32 = 8;
        var h1: u32 = seed;
        var k1: u32 = undefined;
        k1 = @intCast(u32, v) *% c1;
        k1 = rotl32(k1, 15);
        k1 *%= c2;
        h1 ^= k1;
        h1 = rotl32(h1, 13);
        h1 *%= 5;
        h1 +%= 0xe6546b64;
        k1 = @intCast(u32, v >> 32) *% c1;
        k1 = rotl32(k1, 15);
        k1 *%= c2;
        h1 ^= k1;
        h1 = rotl32(h1, 13);
        h1 *%= 5;
        h1 +%= 0xe6546b64;
        h1 ^= len;
        h1 ^= h1 >> 16;
        h1 *%= 0x85ebca6b;
        h1 ^= h1 >> 13;
        h1 *%= 0xc2b2ae35;
        h1 ^= h1 >> 16;
        return h1;
    }
};

fn SMHasherTest(comptime hash_fn: var, comptime hashbits: u32) u32 {
    const hashbytes = hashbits / 8;
    var key: [256]u8 = undefined;
    var hashes: [hashbytes * 256]u8 = undefined;
    var final: [hashbytes]u8 = undefined;

    @memset(@ptrCast([*]u8, &key[0]), 0, @sizeOf(@typeOf(key)));
    @memset(@ptrCast([*]u8, &hashes[0]), 0, @sizeOf(@typeOf(hashes)));
    @memset(@ptrCast([*]u8, &final[0]), 0, @sizeOf(@typeOf(final)));

    var i: u32 = 0;
    while (i < 256) : (i += 1) {
        key[i] = @intCast(u8, i);

        var h = hash_fn(key[0..i], 256 - i);
        if (builtin.endian == builtin.Endian.Big)
            h = @byteSwap(@typeOf(h), h);
        @memcpy(@ptrCast([*]u8, &hashes[i * hashbytes]), @ptrCast([*]u8, &h), hashbytes);
    }

    return @intCast(u32, hash_fn(hashes, 0) & 0xffffffff);
}

test "murmur2_32" {
    std.testing.expectEqual(SMHasherTest(Murmur2_32.hashWithSeed, 32), 0x27864C1E);
}

test "murmur2_64" {
    std.testing.expectEqual(SMHasherTest(Murmur2_64.hashWithSeed, 64), 0x1F0D3804);
}

test "murmur3_32" {
    std.testing.expectEqual(SMHasherTest(Murmur3_32.hashWithSeed, 32), 0xB0F57EE3);
}
