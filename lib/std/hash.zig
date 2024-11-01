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

/// Deprecated in favor of `int`.
pub fn uint32(input: u32) u32 {
    return int(input);
}

/// Applies a bit-mangling transformation to an unsigned integer type `T`.
/// Optimized per type: for `u16` and `u32`, Skeeto's xorshift-multiply; for `u64`, Maiga's mx3.
/// Falls back on an avalanche pattern for other integer types, ensuring high entropy.
pub fn int(input: anytype) @TypeOf(input) {
    const info = @typeInfo(@TypeOf(input)).int;
    if (info.signedness == .signed) {
        const Unsigned = @Type(.{ .int = .{ .signedness = .unsigned, .bits = info.bits } });
        const casted: Unsigned = @bitCast(input);
        return @bitCast(int(casted));
    } else if (info.bits < 4) {
        return @truncate(int(@as(u4, input)));
    }
    var x = input;
    switch (info.bits) {
        16 => {
            // https://github.com/skeeto/hash-prospector
            // 3-round xorshift-multiply (-Xn3)
            // bias = 0.0045976709018820602
            x = (x ^ (x >> 7)) *% 0x2993;
            x = (x ^ (x >> 5)) *% 0xe877;
            x = (x ^ (x >> 9)) *% 0x0235;
            x = x ^ (x >> 10);
        },
        32 => {
            // https://github.com/skeeto/hash-prospector
            x = (x ^ (x >> 17)) *% 0xed5ad4bb;
            x = (x ^ (x >> 11)) *% 0xac4c1b51;
            x = (x ^ (x >> 15)) *% 0x31848bab;
            x = x ^ (x >> 14);
        },
        64 => {
            // https://github.com/jonmaiga/mx3
            // https://github.com/jonmaiga/mx3/blob/48924ee743d724aea2cafd2b4249ef8df57fa8b9/mx3.h#L17
            const c = 0xbea225f9eb34556d;
            x = (x ^ (x >> 32)) *% c;
            x = (x ^ (x >> 29)) *% c;
            x = (x ^ (x >> 32)) *% c;
            x = x ^ (x >> 29);
        },
        else => {
            // This construction provides robust avalanche properties, but it is not optimal for any given size.
            const hsize = info.bits >> 1;
            const c = comptime blk: {
                const max = (1 << info.bits) - 1;
                var mul = 1;
                while (mul * 3 < max) mul *= 3;
                break :blk ((mul ^ (mul >> hsize)) | 1);
            };
            inline for (0..2) |_| {
                x = (x ^ (x >> hsize + 1)) *% c;
                x = (x ^ (x >> hsize - 1)) *% c;
            }
            x ^= (x >> hsize);
        },
    }
    return x;
}

test int {
    const expectEqual = @import("std").testing.expectEqual;
    try expectEqual(0xC, int(@as(u4, 1)));
    try expectEqual(0x4F, int(@as(u8, 1)));
    try expectEqual(0x4F, int(@as(i8, 1)));
    try expectEqual(0x2880, int(@as(u16, 1)));
    try expectEqual(0x42741D6, int(@as(u32, 1)));
    try expectEqual(0x71894DE00D9981F, int(@as(u64, 1)));
    try expectEqual(0x50BC2BB18910C3DE0BAA2CE0D0C5B83E, int(@as(u128, 1)));
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
