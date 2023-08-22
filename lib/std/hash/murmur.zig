const std = @import("std");
const builtin = @import("builtin");
const testing = std.testing;
const native_endian = builtin.target.cpu.arch.endian();

const default_seed: u32 = 0xc70f6907;

pub const Murmur2_32 = struct {
    const Self = @This();

    pub fn hash(str: []const u8) u32 {
        return @call(.always_inline, Self.hashWithSeed, .{ str, default_seed });
    }

    pub fn hashWithSeed(str: []const u8, seed: u32) u32 {
        const m: u32 = 0x5bd1e995;
        const len: u32 = @truncate(str.len);
        var h1: u32 = seed ^ len;
        for (@as([*]align(1) const u32, @ptrCast(str.ptr))[0..(len >> 2)]) |v| {
            var k1: u32 = v;
            if (native_endian == .Big)
                k1 = @byteSwap(k1);
            k1 *%= m;
            k1 ^= k1 >> 24;
            k1 *%= m;
            h1 *%= m;
            h1 ^= k1;
        }
        const offset = len & 0xfffffffc;
        const rest = len & 3;
        if (rest >= 3) {
            h1 ^= @as(u32, @intCast(str[offset + 2])) << 16;
        }
        if (rest >= 2) {
            h1 ^= @as(u32, @intCast(str[offset + 1])) << 8;
        }
        if (rest >= 1) {
            h1 ^= @as(u32, @intCast(str[offset + 0]));
            h1 *%= m;
        }
        h1 ^= h1 >> 13;
        h1 *%= m;
        h1 ^= h1 >> 15;
        return h1;
    }

    pub fn hashUint32(v: u32) u32 {
        return @call(.always_inline, Self.hashUint32WithSeed, .{ v, default_seed });
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
        return @call(.always_inline, Self.hashUint64WithSeed, .{ v, default_seed });
    }

    pub fn hashUint64WithSeed(v: u64, seed: u32) u32 {
        const m: u32 = 0x5bd1e995;
        const len: u32 = 8;
        var h1: u32 = seed ^ len;
        var k1: u32 = undefined;
        k1 = @as(u32, @truncate(v)) *% m;
        k1 ^= k1 >> 24;
        k1 *%= m;
        h1 *%= m;
        h1 ^= k1;
        k1 = @as(u32, @truncate(v >> 32)) *% m;
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
        return @call(.always_inline, Self.hashWithSeed, .{ str, default_seed });
    }

    pub fn hashWithSeed(str: []const u8, seed: u64) u64 {
        const m: u64 = 0xc6a4a7935bd1e995;
        var h1: u64 = seed ^ (@as(u64, str.len) *% m);
        for (@as([*]align(1) const u64, @ptrCast(str.ptr))[0 .. str.len / 8]) |v| {
            var k1: u64 = v;
            if (native_endian == .Big)
                k1 = @byteSwap(k1);
            k1 *%= m;
            k1 ^= k1 >> 47;
            k1 *%= m;
            h1 ^= k1;
            h1 *%= m;
        }
        const rest = str.len & 7;
        const offset = str.len - rest;
        if (rest > 0) {
            var k1: u64 = 0;
            @memcpy(@as([*]u8, @ptrCast(&k1))[0..rest], str[offset..]);
            if (native_endian == .Big)
                k1 = @byteSwap(k1);
            h1 ^= k1;
            h1 *%= m;
        }
        h1 ^= h1 >> 47;
        h1 *%= m;
        h1 ^= h1 >> 47;
        return h1;
    }

    pub fn hashUint32(v: u32) u64 {
        return @call(.always_inline, Self.hashUint32WithSeed, .{ v, default_seed });
    }

    pub fn hashUint32WithSeed(v: u32, seed: u64) u64 {
        const m: u64 = 0xc6a4a7935bd1e995;
        const len: u64 = 4;
        var h1: u64 = seed ^ (len *% m);
        var k1: u64 = v;
        h1 ^= k1;
        h1 *%= m;
        h1 ^= h1 >> 47;
        h1 *%= m;
        h1 ^= h1 >> 47;
        return h1;
    }

    pub fn hashUint64(v: u64) u64 {
        return @call(.always_inline, Self.hashUint64WithSeed, .{ v, default_seed });
    }

    pub fn hashUint64WithSeed(v: u64, seed: u64) u64 {
        const m: u64 = 0xc6a4a7935bd1e995;
        const len: u64 = 8;
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
};

pub const Murmur3_32 = struct {
    const Self = @This();

    fn rotl32(x: u32, comptime r: u32) u32 {
        return (x << r) | (x >> (32 - r));
    }

    pub fn hash(str: []const u8) u32 {
        return @call(.always_inline, Self.hashWithSeed, .{ str, default_seed });
    }

    pub fn hashWithSeed(str: []const u8, seed: u32) u32 {
        const c1: u32 = 0xcc9e2d51;
        const c2: u32 = 0x1b873593;
        const len: u32 = @truncate(str.len);
        var h1: u32 = seed;
        for (@as([*]align(1) const u32, @ptrCast(str.ptr))[0..(len >> 2)]) |v| {
            var k1: u32 = v;
            if (native_endian == .Big)
                k1 = @byteSwap(k1);
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
                k1 ^= @as(u32, @intCast(str[offset + 2])) << 16;
            }
            if (rest >= 2) {
                k1 ^= @as(u32, @intCast(str[offset + 1])) << 8;
            }
            if (rest >= 1) {
                k1 ^= @as(u32, @intCast(str[offset + 0]));
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
        return @call(.always_inline, Self.hashUint32WithSeed, .{ v, default_seed });
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
        return @call(.always_inline, Self.hashUint64WithSeed, .{ v, default_seed });
    }

    pub fn hashUint64WithSeed(v: u64, seed: u32) u32 {
        const c1: u32 = 0xcc9e2d51;
        const c2: u32 = 0x1b873593;
        const len: u32 = 8;
        var h1: u32 = seed;
        var k1: u32 = undefined;
        k1 = @as(u32, @truncate(v)) *% c1;
        k1 = rotl32(k1, 15);
        k1 *%= c2;
        h1 ^= k1;
        h1 = rotl32(h1, 13);
        h1 *%= 5;
        h1 +%= 0xe6546b64;
        k1 = @as(u32, @truncate(v >> 32)) *% c1;
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

fn SMHasherTest(comptime hash_fn: anytype, comptime hashbits: u32) u32 {
    const hashbytes = hashbits / 8;
    var key: [256]u8 = [1]u8{0} ** 256;
    var hashes: [hashbytes * 256]u8 = [1]u8{0} ** (hashbytes * 256);

    var i: u32 = 0;
    while (i < 256) : (i += 1) {
        key[i] = @as(u8, @truncate(i));

        var h = hash_fn(key[0..i], 256 - i);
        if (native_endian == .Big)
            h = @byteSwap(h);
        @memcpy(hashes[i * hashbytes ..][0..hashbytes], @as([*]u8, @ptrCast(&h)));
    }

    return @as(u32, @truncate(hash_fn(&hashes, 0)));
}

test "murmur2_32" {
    try testing.expectEqual(SMHasherTest(Murmur2_32.hashWithSeed, 32), 0x27864C1E);
    var v0: u32 = 0x12345678;
    var v1: u64 = 0x1234567812345678;
    var v0le: u32 = v0;
    var v1le: u64 = v1;
    if (native_endian == .Big) {
        v0le = @byteSwap(v0le);
        v1le = @byteSwap(v1le);
    }
    try testing.expectEqual(Murmur2_32.hash(@as([*]u8, @ptrCast(&v0le))[0..4]), Murmur2_32.hashUint32(v0));
    try testing.expectEqual(Murmur2_32.hash(@as([*]u8, @ptrCast(&v1le))[0..8]), Murmur2_32.hashUint64(v1));
}

test "murmur2_64" {
    try std.testing.expectEqual(SMHasherTest(Murmur2_64.hashWithSeed, 64), 0x1F0D3804);
    var v0: u32 = 0x12345678;
    var v1: u64 = 0x1234567812345678;
    var v0le: u32 = v0;
    var v1le: u64 = v1;
    if (native_endian == .Big) {
        v0le = @byteSwap(v0le);
        v1le = @byteSwap(v1le);
    }
    try testing.expectEqual(Murmur2_64.hash(@as([*]u8, @ptrCast(&v0le))[0..4]), Murmur2_64.hashUint32(v0));
    try testing.expectEqual(Murmur2_64.hash(@as([*]u8, @ptrCast(&v1le))[0..8]), Murmur2_64.hashUint64(v1));
}

test "murmur3_32" {
    try std.testing.expectEqual(SMHasherTest(Murmur3_32.hashWithSeed, 32), 0xB0F57EE3);
    var v0: u32 = 0x12345678;
    var v1: u64 = 0x1234567812345678;
    var v0le: u32 = v0;
    var v1le: u64 = v1;
    if (native_endian == .Big) {
        v0le = @byteSwap(v0le);
        v1le = @byteSwap(v1le);
    }
    try testing.expectEqual(Murmur3_32.hash(@as([*]u8, @ptrCast(&v0le))[0..4]), Murmur3_32.hashUint32(v0));
    try testing.expectEqual(Murmur3_32.hash(@as([*]u8, @ptrCast(&v1le))[0..8]), Murmur3_32.hashUint64(v1));
}
