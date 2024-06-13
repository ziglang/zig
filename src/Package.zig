const std = @import("std");
const assert = std.debug.assert;

pub const Module = @import("Package/Module.zig");
pub const Fetch = @import("Package/Fetch.zig");
pub const build_zig_basename = std.zig.build_file_basename;

pub const multihash_len = 1 + 1 + Hash.Algo.digest_length;
pub const multihash_hex_digest_len = 2 * multihash_len;
pub const MultiHashHexDigest = [multihash_hex_digest_len]u8;
pub const multiHashHexDigest = std.zig.Package.multiHashHexDigest;

pub const Manifest = std.zig.Package.Manifest;
pub const Fingerprint = std.zig.Package.Fingerprint;
pub const Hash = std.zig.Package.Hash;

test {
    _ = Fetch;
}
