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

test "hash" {
    _ = adler;
    _ = auto_hash;
    _ = crc;
    _ = fnv;
    _ = murmur;
    _ = cityhash;
    _ = wyhash;
}
