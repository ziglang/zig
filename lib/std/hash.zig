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

pub const RapidHash = @import("hash/RapidHash.zig");

const xxhash = @import("hash/xxhash.zig");
pub const XxHash3 = xxhash.XxHash3;
pub const XxHash64 = xxhash.XxHash64;
pub const XxHash32 = xxhash.XxHash32;

/// Integer-to-integer hashing for bit widths <= 256.
pub fn int(input: anytype) @TypeOf(input) {
    // This function is only intended for integer types
    const info = @typeInfo(@TypeOf(input)).int;
    const bits = info.bits;
    // Convert input to unsigned integer (easier to deal with)
    const Uint = @Type(.{ .int = .{ .bits = bits, .signedness = .unsigned } });
    const u_input: Uint = @bitCast(input);
    if (bits > 256) @compileError("bit widths > 256 are unsupported, use std.hash.autoHash functionality.");
    // For bit widths that don't have a dedicated function, use a heuristic
    // construction with a multiplier suited to diffusion -
    // a mod 2^bits where a^2 - 46 * a + 1 = 0 mod 2^(bits + 4),
    // on Mathematica: bits = 256; BaseForm[Solve[1 - 46 a + a^2 == 0, a, Modulus -> 2^(bits + 4)][[-1]][[1]][[2]], 16]
    const mult: Uint = @truncate(0xfac2e27ed2036860a062b5f264d80a512b00aa459b448bf1eca24d41c96f59e5b);
    // The bit width of the input integer determines how to hash it
    const output = switch (bits) {
        0...2 => u_input *% mult,
        16 => uint16(u_input),
        32 => uint32(u_input),
        64 => uint64(u_input),
        else => blk: {
            var x: Uint = u_input;
            inline for (0..4) |_| {
                x ^= x >> (bits / 2);
                x *%= mult;
            }
            break :blk x;
        },
    };
    return @bitCast(output);
}

/// Source: https://github.com/skeeto/hash-prospector
fn uint16(input: u16) u16 {
    var x: u16 = input;
    x = (x ^ (x >> 7)) *% 0x2993;
    x = (x ^ (x >> 5)) *% 0xe877;
    x = (x ^ (x >> 9)) *% 0x0235;
    x = x ^ (x >> 10);
    return x;
}

/// DEPRECATED: use std.hash.int()
/// Source: https://github.com/skeeto/hash-prospector
pub fn uint32(input: u32) u32 {
    var x: u32 = input;
    x = (x ^ (x >> 17)) *% 0xed5ad4bb;
    x = (x ^ (x >> 11)) *% 0xac4c1b51;
    x = (x ^ (x >> 15)) *% 0x31848bab;
    x = x ^ (x >> 14);
    return x;
}

/// Source: https://github.com/jonmaiga/mx3
fn uint64(input: u64) u64 {
    var x: u64 = input;
    const c = 0xbea225f9eb34556d;
    x = (x ^ (x >> 32)) *% c;
    x = (x ^ (x >> 29)) *% c;
    x = (x ^ (x >> 32)) *% c;
    x = x ^ (x >> 29);
    return x;
}

test int {
    const expectEqual = @import("std").testing.expectEqual;
    try expectEqual(0x1, int(@as(u1, 1)));
    try expectEqual(0x3, int(@as(u2, 1)));
    try expectEqual(0x4, int(@as(u3, 1)));
    try expectEqual(0xD6, int(@as(u8, 1)));
    try expectEqual(0x2880, int(@as(u16, 1)));
    try expectEqual(0x2880, int(@as(i16, 1)));
    try expectEqual(0x838380, int(@as(u24, 1)));
    try expectEqual(0x42741D6, int(@as(u32, 1)));
    try expectEqual(0x42741D6, int(@as(i32, 1)));
    try expectEqual(0x71894DE00D9981F, int(@as(u64, 1)));
    try expectEqual(0x71894DE00D9981F, int(@as(i64, 1)));
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
