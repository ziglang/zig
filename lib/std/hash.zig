const adler = @import("hash/adler.zig");
pub const Adler32 = adler.Adler32;

const auto_hash = @import("hash/auto_hash.zig");
pub const autoHash = auto_hash.autoHash;
pub const autoHashStrat = auto_hash.hash;
pub const Strategy = auto_hash.HashStrategy;

// pub for polynomials + generic crc32 construction
pub const crc = @import("hash/crc.zig");
pub const Crc32 = crc.Crc32;

const fnv = @import("hash/fnv.zig");
pub const Fnv1a_32 = fnv.Fnv1a_32;
pub const Fnv1a_64 = fnv.Fnv1a_64;
pub const Fnv1a_128 = fnv.Fnv1a_128;

const siphash = @import("crypto/siphash.zig");
pub const SipHash64 = siphash.SipHash64;
pub const SipHash128 = siphash.SipHash128;

pub const murmur = @import("hash/murmur.zig");
pub const Murmur2_32 = murmur.Murmur2_32;

pub const Murmur2_64 = murmur.Murmur2_64;
pub const Murmur3_32 = murmur.Murmur3_32;

pub const cityhash = @import("hash/cityhash.zig");
pub const CityHash32 = cityhash.CityHash32;
pub const CityHash64 = cityhash.CityHash64;

const wyhash = @import("hash/wyhash.zig");
pub const Wyhash = wyhash.Wyhash;

const xxhash = @import("hash/xxhash.zig");
pub const XxHash3 = xxhash.XxHash3;
pub const XxHash64 = xxhash.XxHash64;
pub const XxHash32 = xxhash.XxHash32;

/// Deprecated: use std.hash.int(comptime T, input T) T where T is an unsigned integer type.
/// This is handy if you have a u32 and want a u32 and don't want to take a
/// detour through many layers of abstraction elsewhere in the std.hash
/// namespace.
pub fn uint32(input: u32) u32 {
    return int(u32, input);
}

/// Applies a bit-mangling transformation to an unsigned integer type `T`.
/// Optimized per type: for `u16` and `u32`, Skeeto's xorshift-multiply; for `u64`, Maiga's mx3.
/// Falls back on an avalanche pattern for other unsigned types, ensuring high entropy.
/// Only unsigned types are accepted; signed types will raise a compile-time error.
pub fn int(comptime T: type, input: T) T {
    const tInfo = @typeInfo(T).int;
    if (tInfo.signedness != .unsigned) @compileError("type has to be unsigned integer");
    var x = input;
    switch (T) {
        u16 => {
            //https://github.com/skeeto/hash-prospector
            // 3-round xorshift-multiply (-Xn3)
            // bias = 0.0045976709018820602
            x = (x ^ (x >> 7)) *% 0x2993;
            x = (x ^ (x >> 5)) *% 0xe877;
            x = (x ^ (x >> 9)) *% 0x0235;
            x = x ^ (x >> 10);
        },
        u32 => {
            // https://github.com/skeeto/hash-prospector
            x = (x ^ (x >> 17)) *% 0xed5ad4bb;
            x = (x ^ (x >> 11)) *% 0xac4c1b51;
            x = (x ^ (x >> 15)) *% 0x31848bab;
            x = x ^ (x >> 14);
        },
        u64 => {
            // https://github.com/jonmaiga/mx3
            // https://github.com/jonmaiga/mx3/blob/48924ee743d724aea2cafd2b4249ef8df57fa8b9/mx3.h#L17
            const C = 0xbea225f9eb34556d;
            x = (x ^ (x >> 32)) *% C;
            x = (x ^ (x >> 29)) *% C;
            x = (x ^ (x >> 32)) *% C;
            x = x ^ (x >> 29);
        },
        else => {
            // this construction provides robust avalanche properties, but it is not optimal for any given size.
            const Tsize = @bitSizeOf(T);
            if (Tsize < 4) @compileError("not implemented.");
            const hsize = Tsize >> 1;
            const C = comptime blk: {
                const max = (1 << Tsize) - 1;
                var mul = 1;
                while (mul * 3 < max) mul *= 3;
                break :blk ((mul ^ (mul >> hsize)) | 1);
            };
            inline for (0..2) |_| {
                x = (x ^ (x >> hsize + 1)) *% C;
                x = (x ^ (x >> hsize - 1)) *% C;
            }
            x ^= (x >> hsize);
        },
    }
    return x;
}

test "bit manglers" {
    const expect = @import("std").testing.expect;
    try expect(int(u4, 1) == 0xC);
    try expect(int(u8, 1) == 0x4F);
    try expect(int(u16, 1) == 0x2880);
    try expect(int(u32, 1) == 0x42741D6);
    try expect(int(u64, 1) == 0x71894DE00D9981F);
    try expect(int(u128, 1) == 0x50BC2BB18910C3DE0BAA2CE0D0C5B83E);
}

test {
    _ = adler;
    _ = auto_hash;
    _ = crc;
    _ = fnv;
    _ = murmur;
    _ = cityhash;
    _ = wyhash;
    _ = xxhash;
}
