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

/// This is handy if you have a u32 and want a u32 and don't want to take a
/// detour through many layers of abstraction elsewhere in the std.hash
/// namespace.
/// Copied from https://nullprogram.com/blog/2018/07/31/
pub fn uint32(input: u32) u32 {
    var x: u32 = input;
    x ^= x >> 16;
    x *%= 0x7feb352d;
    x ^= x >> 15;
    x *%= 0x846ca68b;
    x ^= x >> 16;
    return x;
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
