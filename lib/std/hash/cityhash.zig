const std = @import("std");
const builtin = @import("builtin");

pub const CityHash32 = struct {
    const Self = @This();

    // Magic numbers for 32-bit hashing.  Copied from Murmur3.
    const c1: u32 = 0xcc9e2d51;
    const c2: u32 = 0x1b873593;

    fn fetch32(ptr: [*]const u8) u32 {
        var v: u32 = undefined;
        @memcpy(@ptrCast([*]u8, &v), ptr, 4);
        if (builtin.endian == .Big)
            return @byteSwap(u32, v);
        return v;
    }

    // A 32-bit to 32-bit integer hash copied from Murmur3.
    fn fmix(h: u32) u32 {
        var h1: u32 = h;
        h1 ^= h1 >> 16;
        h1 *%= 0x85ebca6b;
        h1 ^= h1 >> 13;
        h1 *%= 0xc2b2ae35;
        h1 ^= h1 >> 16;
        return h1;
    }

    // Rotate right helper
    fn rotr32(x: u32, comptime r: u32) u32 {
        return (x >> r) | (x << (32 - r));
    }

    // Helper from Murmur3 for combining two 32-bit values.
    fn mur(a: u32, h: u32) u32 {
        var a1: u32 = a;
        var h1: u32 = h;
        a1 *%= c1;
        a1 = rotr32(a1, 17);
        a1 *%= c2;
        h1 ^= a1;
        h1 = rotr32(h1, 19);
        return h1 *% 5 +% 0xe6546b64;
    }

    fn hash32Len0To4(str: []const u8) u32 {
        const len: u32 = @truncate(u32, str.len);
        var b: u32 = 0;
        var c: u32 = 9;
        for (str) |v| {
            b = b *% c1 +% @bitCast(u32, @intCast(i32, @bitCast(i8, v)));
            c ^= b;
        }
        return fmix(mur(b, mur(len, c)));
    }

    fn hash32Len5To12(str: []const u8) u32 {
        var a: u32 = @truncate(u32, str.len);
        var b: u32 = a *% 5;
        var c: u32 = 9;
        const d: u32 = b;

        a +%= fetch32(str.ptr);
        b +%= fetch32(str.ptr + str.len - 4);
        c +%= fetch32(str.ptr + ((str.len >> 1) & 4));

        return fmix(mur(c, mur(b, mur(a, d))));
    }

    fn hash32Len13To24(str: []const u8) u32 {
        const len: u32 = @truncate(u32, str.len);
        const a: u32 = fetch32(str.ptr + (str.len >> 1) - 4);
        const b: u32 = fetch32(str.ptr + 4);
        const c: u32 = fetch32(str.ptr + str.len - 8);
        const d: u32 = fetch32(str.ptr + (str.len >> 1));
        const e: u32 = fetch32(str.ptr);
        const f: u32 = fetch32(str.ptr + str.len - 4);

        return fmix(mur(f, mur(e, mur(d, mur(c, mur(b, mur(a, len)))))));
    }

    pub fn hash(str: []const u8) u32 {
        if (str.len <= 24) {
            if (str.len <= 4) {
                return hash32Len0To4(str);
            } else {
                if (str.len <= 12)
                    return hash32Len5To12(str);
                return hash32Len13To24(str);
            }
        }

        const len: u32 = @truncate(u32, str.len);
        var h: u32 = len;
        var g: u32 = c1 *% len;
        var f: u32 = g;

        const a0: u32 = rotr32(fetch32(str.ptr + str.len - 4) *% c1, 17) *% c2;
        const a1: u32 = rotr32(fetch32(str.ptr + str.len - 8) *% c1, 17) *% c2;
        const a2: u32 = rotr32(fetch32(str.ptr + str.len - 16) *% c1, 17) *% c2;
        const a3: u32 = rotr32(fetch32(str.ptr + str.len - 12) *% c1, 17) *% c2;
        const a4: u32 = rotr32(fetch32(str.ptr + str.len - 20) *% c1, 17) *% c2;

        h ^= a0;
        h = rotr32(h, 19);
        h = h *% 5 +% 0xe6546b64;
        h ^= a2;
        h = rotr32(h, 19);
        h = h *% 5 +% 0xe6546b64;
        g ^= a1;
        g = rotr32(g, 19);
        g = g *% 5 +% 0xe6546b64;
        g ^= a3;
        g = rotr32(g, 19);
        g = g *% 5 +% 0xe6546b64;
        f +%= a4;
        f = rotr32(f, 19);
        f = f *% 5 +% 0xe6546b64;
        var iters = (str.len - 1) / 20;
        var ptr = str.ptr;
        while (iters != 0) : (iters -= 1) {
            const b0: u32 = rotr32(fetch32(ptr) *% c1, 17) *% c2;
            const b1: u32 = fetch32(ptr + 4);
            const b2: u32 = rotr32(fetch32(ptr + 8) *% c1, 17) *% c2;
            const b3: u32 = rotr32(fetch32(ptr + 12) *% c1, 17) *% c2;
            const b4: u32 = fetch32(ptr + 16);

            h ^= b0;
            h = rotr32(h, 18);
            h = h *% 5 +% 0xe6546b64;
            f +%= b1;
            f = rotr32(f, 19);
            f = f *% c1;
            g +%= b2;
            g = rotr32(g, 18);
            g = g *% 5 +% 0xe6546b64;
            h ^= b3 +% b1;
            h = rotr32(h, 19);
            h = h *% 5 +% 0xe6546b64;
            g ^= b4;
            g = @byteSwap(u32, g) *% 5;
            h +%= b4 *% 5;
            h = @byteSwap(u32, h);
            f +%= b0;
            const t: u32 = h;
            h = f;
            f = g;
            g = t;
            ptr += 20;
        }
        g = rotr32(g, 11) *% c1;
        g = rotr32(g, 17) *% c1;
        f = rotr32(f, 11) *% c1;
        f = rotr32(f, 17) *% c1;
        h = rotr32(h +% g, 19);
        h = h *% 5 +% 0xe6546b64;
        h = rotr32(h, 17) *% c1;
        h = rotr32(h +% f, 19);
        h = h *% 5 +% 0xe6546b64;
        h = rotr32(h, 17) *% c1;
        return h;
    }
};

pub const CityHash64 = struct {
    const Self = @This();

    // Some primes between 2^63 and 2^64 for various uses.
    const k0: u64 = 0xc3a5c85c97cb3127;
    const k1: u64 = 0xb492b66fbe98f273;
    const k2: u64 = 0x9ae16a3b2f90404f;

    fn fetch32(ptr: [*]const u8) u32 {
        var v: u32 = undefined;
        @memcpy(@ptrCast([*]u8, &v), ptr, 4);
        if (builtin.endian == .Big)
            return @byteSwap(u32, v);
        return v;
    }

    fn fetch64(ptr: [*]const u8) u64 {
        var v: u64 = undefined;
        @memcpy(@ptrCast([*]u8, &v), ptr, 8);
        if (builtin.endian == .Big)
            return @byteSwap(u64, v);
        return v;
    }

    // Rotate right helper
    fn rotr64(x: u64, comptime r: u64) u64 {
        return (x >> r) | (x << (64 - r));
    }

    fn shiftmix(v: u64) u64 {
        return v ^ (v >> 47);
    }

    fn hashLen16(u: u64, v: u64) u64 {
        return @call(.{ .modifier = .always_inline }, hash128To64, .{ u, v });
    }

    fn hashLen16Mul(low: u64, high: u64, mul: u64) u64 {
        var a: u64 = (low ^ high) *% mul;
        a ^= (a >> 47);
        var b: u64 = (high ^ a) *% mul;
        b ^= (b >> 47);
        b *%= mul;
        return b;
    }

    fn hash128To64(low: u64, high: u64) u64 {
        return @call(.{ .modifier = .always_inline }, hashLen16Mul, .{ low, high, 0x9ddfea08eb382d69 });
    }

    fn hashLen0To16(str: []const u8) u64 {
        const len: u64 = @as(u64, str.len);
        if (len >= 8) {
            const mul: u64 = k2 +% len *% 2;
            const a: u64 = fetch64(str.ptr) +% k2;
            const b: u64 = fetch64(str.ptr + str.len - 8);
            const c: u64 = rotr64(b, 37) *% mul +% a;
            const d: u64 = (rotr64(a, 25) +% b) *% mul;
            return hashLen16Mul(c, d, mul);
        }
        if (len >= 4) {
            const mul: u64 = k2 +% len *% 2;
            const a: u64 = fetch32(str.ptr);
            return hashLen16Mul(len +% (a << 3), fetch32(str.ptr + str.len - 4), mul);
        }
        if (len > 0) {
            const a: u8 = str[0];
            const b: u8 = str[str.len >> 1];
            const c: u8 = str[str.len - 1];
            const y: u32 = @intCast(u32, a) +% (@intCast(u32, b) << 8);
            const z: u32 = @truncate(u32, str.len) +% (@intCast(u32, c) << 2);
            return shiftmix(@intCast(u64, y) *% k2 ^ @intCast(u64, z) *% k0) *% k2;
        }
        return k2;
    }

    fn hashLen17To32(str: []const u8) u64 {
        const len: u64 = @as(u64, str.len);
        const mul: u64 = k2 +% len *% 2;
        const a: u64 = fetch64(str.ptr) *% k1;
        const b: u64 = fetch64(str.ptr + 8);
        const c: u64 = fetch64(str.ptr + str.len - 8) *% mul;
        const d: u64 = fetch64(str.ptr + str.len - 16) *% k2;

        return hashLen16Mul(rotr64(a +% b, 43) +% rotr64(c, 30) +% d, a +% rotr64(b +% k2, 18) +% c, mul);
    }

    fn hashLen33To64(str: []const u8) u64 {
        const len: u64 = @as(u64, str.len);
        const mul: u64 = k2 +% len *% 2;
        const a: u64 = fetch64(str.ptr) *% k2;
        const b: u64 = fetch64(str.ptr + 8);
        const c: u64 = fetch64(str.ptr + str.len - 24);
        const d: u64 = fetch64(str.ptr + str.len - 32);
        const e: u64 = fetch64(str.ptr + 16) *% k2;
        const f: u64 = fetch64(str.ptr + 24) *% 9;
        const g: u64 = fetch64(str.ptr + str.len - 8);
        const h: u64 = fetch64(str.ptr + str.len - 16) *% mul;

        const u: u64 = rotr64(a +% g, 43) +% (rotr64(b, 30) +% c) *% 9;
        const v: u64 = ((a +% g) ^ d) +% f +% 1;
        const w: u64 = @byteSwap(u64, (u +% v) *% mul) +% h;
        const x: u64 = rotr64(e +% f, 42) +% c;
        const y: u64 = (@byteSwap(u64, (v +% w) *% mul) +% g) *% mul;
        const z: u64 = e +% f +% c;
        const a1: u64 = @byteSwap(u64, (x +% z) *% mul +% y) +% b;
        const b1: u64 = shiftmix((z +% a1) *% mul +% d +% h) *% mul;
        return b1 +% x;
    }

    const WeakPair = struct {
        first: u64,
        second: u64,
    };

    fn weakHashLen32WithSeedsHelper(w: u64, x: u64, y: u64, z: u64, a: u64, b: u64) WeakPair {
        var a1: u64 = a;
        var b1: u64 = b;
        a1 +%= w;
        b1 = rotr64(b1 +% a1 +% z, 21);
        var c: u64 = a1;
        a1 +%= x;
        a1 +%= y;
        b1 +%= rotr64(a1, 44);
        return WeakPair{ .first = a1 +% z, .second = b1 +% c };
    }

    fn weakHashLen32WithSeeds(ptr: [*]const u8, a: u64, b: u64) WeakPair {
        return @call(.{ .modifier = .always_inline }, weakHashLen32WithSeedsHelper, .{
            fetch64(ptr),
            fetch64(ptr + 8),
            fetch64(ptr + 16),
            fetch64(ptr + 24),
            a,
            b,
        });
    }

    pub fn hash(str: []const u8) u64 {
        if (str.len <= 32) {
            if (str.len <= 16) {
                return hashLen0To16(str);
            } else {
                return hashLen17To32(str);
            }
        } else if (str.len <= 64) {
            return hashLen33To64(str);
        }

        var len: u64 = @as(u64, str.len);

        var x: u64 = fetch64(str.ptr + str.len - 40);
        var y: u64 = fetch64(str.ptr + str.len - 16) +% fetch64(str.ptr + str.len - 56);
        var z: u64 = hashLen16(fetch64(str.ptr + str.len - 48) +% len, fetch64(str.ptr + str.len - 24));
        var v: WeakPair = weakHashLen32WithSeeds(str.ptr + str.len - 64, len, z);
        var w: WeakPair = weakHashLen32WithSeeds(str.ptr + str.len - 32, y +% k1, x);

        x = x *% k1 +% fetch64(str.ptr);
        len = (len - 1) & ~@intCast(u64, 63);

        var ptr: [*]const u8 = str.ptr;
        while (true) {
            x = rotr64(x +% y +% v.first +% fetch64(ptr + 8), 37) *% k1;
            y = rotr64(y +% v.second +% fetch64(ptr + 48), 42) *% k1;
            x ^= w.second;
            y +%= v.first +% fetch64(ptr + 40);
            z = rotr64(z +% w.first, 33) *% k1;
            v = weakHashLen32WithSeeds(ptr, v.second *% k1, x +% w.first);
            w = weakHashLen32WithSeeds(ptr + 32, z +% w.second, y +% fetch64(ptr + 16));
            const t: u64 = z;
            z = x;
            x = t;

            ptr += 64;
            len -= 64;
            if (len == 0)
                break;
        }

        return hashLen16(hashLen16(v.first, w.first) +% shiftmix(y) *% k1 +% z, hashLen16(v.second, w.second) +% x);
    }

    pub fn hashWithSeed(str: []const u8, seed: u64) u64 {
        return @call(.{ .modifier = .always_inline }, Self.hashWithSeeds, .{ str, k2, seed });
    }

    pub fn hashWithSeeds(str: []const u8, seed0: u64, seed1: u64) u64 {
        return hashLen16(hash(str) -% seed0, seed1);
    }
};

fn SMHasherTest(comptime hash_fn: anytype, comptime hashbits: u32) u32 {
    const hashbytes = hashbits / 8;
    var key: [256]u8 = undefined;
    var hashes: [hashbytes * 256]u8 = undefined;
    var final: [hashbytes]u8 = undefined;

    @memset(@ptrCast([*]u8, &key[0]), 0, @sizeOf(@TypeOf(key)));
    @memset(@ptrCast([*]u8, &hashes[0]), 0, @sizeOf(@TypeOf(hashes)));
    @memset(@ptrCast([*]u8, &final[0]), 0, @sizeOf(@TypeOf(final)));

    var i: u32 = 0;
    while (i < 256) : (i += 1) {
        key[i] = @intCast(u8, i);

        var h = hash_fn(key[0..i], 256 - i);
        if (builtin.endian == .Big)
            h = @byteSwap(@TypeOf(h), h);
        @memcpy(@ptrCast([*]u8, &hashes[i * hashbytes]), @ptrCast([*]u8, &h), hashbytes);
    }

    return @truncate(u32, hash_fn(&hashes, 0));
}

fn CityHash32hashIgnoreSeed(str: []const u8, seed: u32) u32 {
    return CityHash32.hash(str);
}

test "cityhash32" {
    // Note: SMHasher doesn't provide a 32bit version of the algorithm.
    // Note: The implementation was verified against the Google Abseil version.
    std.testing.expectEqual(SMHasherTest(CityHash32hashIgnoreSeed, 32), 0x68254F81);
}

test "cityhash64" {
    // Note: This is not compliant with the SMHasher implementation of CityHash64!
    // Note: The implementation was verified against the Google Abseil version.
    std.testing.expectEqual(SMHasherTest(CityHash64.hashWithSeed, 64), 0x5FABC5C5);
}
