const adler = @import("adler.zig");
pub const Adler32 = adler.Adler32;

// pub for polynomials + generic crc32 construction
pub const crc = @import("crc.zig");
pub const Crc32 = crc.Crc32;

const fnv = @import("fnv.zig");
pub const Fnv1a_32 = fnv.Fnv1a_32;
pub const Fnv1a_64 = fnv.Fnv1a_64;
pub const Fnv1a_128 = fnv.Fnv1a_128;

const siphash = @import("siphash.zig");
pub const SipHash64 = siphash.SipHash64;
pub const SipHash128 = siphash.SipHash128;

test "hash" {
    _ = @import("adler.zig");
    _ = @import("crc.zig");
    _ = @import("fnv.zig");
    _ = @import("siphash.zig");
}
