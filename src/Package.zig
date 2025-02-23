const std = @import("std");
const assert = std.debug.assert;

pub const Module = @import("Package/Module.zig");
pub const Fetch = @import("Package/Fetch.zig");
pub const build_zig_basename = "build.zig";
pub const Manifest = @import("Package/Manifest.zig");

pub const multihash_len = 1 + 1 + Hash.Algo.digest_length;
pub const multihash_hex_digest_len = 2 * multihash_len;
pub const MultiHashHexDigest = [multihash_hex_digest_len]u8;

/// A user-readable, file system safe hash that identifies an exact package
/// snapshot, including file contents.
///
/// This data structure can be used to store the legacy hash format too. Legacy
/// hash format is scheduled to be removed after 0.14.0 is tagged.
pub const Hash = struct {
    /// Maximum size of a package hash. Unused bytes at the end are
    /// filled with zeroes.
    bytes: [max_len]u8,

    pub const Algo = std.crypto.hash.sha2.Sha256;
    pub const Digest = [Algo.digest_length]u8;

    pub const max_len = 32 + 1 + 32 + 1 + 12;

    pub fn fromSlice(s: []const u8) Hash {
        assert(s.len <= max_len);
        var result: Hash = undefined;
        @memcpy(result.bytes[0..s.len], s);
        @memset(result.bytes[s.len..], 0);
        return result;
    }

    pub fn toSlice(ph: *const Hash) []const u8 {
        var end: usize = ph.bytes.len;
        while (true) {
            end -= 1;
            if (ph.bytes[end] != 0) return ph.bytes[0 .. end + 1];
        }
    }

    pub fn eql(a: *const Hash, b: *const Hash) bool {
        return std.mem.eql(u8, &a.bytes, &b.bytes);
    }

    /// Distinguishes whether the legacy multihash format is being stored here.
    pub fn isOld(h: *const Hash) bool {
        if (h.bytes.len < 2) return false;
        const their_multihash_func = std.fmt.parseInt(u8, h.bytes[0..2], 16) catch return false;
        if (@as(MultihashFunction, @enumFromInt(their_multihash_func)) != multihash_function) return false;
        if (h.toSlice().len != multihash_hex_digest_len) return false;
        return std.mem.indexOfScalar(u8, &h.bytes, '-') == null;
    }

    test isOld {
        const h: Hash = .fromSlice("1220138f4aba0c01e66b68ed9e1e1e74614c06e4743d88bc58af4f1c3dd0aae5fea7");
        try std.testing.expect(h.isOld());
    }

    /// Produces "$name-$semver-$sizedhash".
    /// * name is the name field from build.zig.zon, truncated at 32 bytes and must
    ///   be a valid zig identifier
    /// * semver is the version field from build.zig.zon, truncated at 32 bytes
    /// * sizedhash is the following 9-byte array, base64 encoded using -_ to make
    ///   it filesystem safe:
    ///   - (4 bytes) LE u32 total decompressed size in bytes
    ///   - (5 bytes) truncated SHA-256 of hashed files of the package
    ///
    /// example: "nasm-2.16.1-2-BWdcABvF_jM1"
    pub fn init(digest: Digest, name: []const u8, ver: []const u8, size: u32) Hash {
        var result: Hash = undefined;
        var buf: std.ArrayListUnmanaged(u8) = .initBuffer(&result.bytes);
        buf.appendSliceAssumeCapacity(name[0..@min(name.len, 32)]);
        buf.appendAssumeCapacity('-');
        buf.appendSliceAssumeCapacity(ver[0..@min(ver.len, 32)]);
        buf.appendAssumeCapacity('-');
        var sizedhash: [9]u8 = undefined;
        std.mem.writeInt(u32, sizedhash[0..4], size, .little);
        sizedhash[4..].* = digest[0..5].*;
        _ = std.base64.url_safe_no_pad.Encoder.encode(buf.addManyAsArrayAssumeCapacity(12), &sizedhash);
        @memset(buf.unusedCapacitySlice(), 0);
        return result;
    }

    /// Produces "$hashiname-N-$sizedhash". For packages that lack "build.zig.zon" metadata.
    /// * hashiname is [5..][0..24] bytes of the SHA-256, urlsafe-base64-encoded, for a total of 32 bytes encoded
    /// * the semver section is replaced with a hardcoded N which stands for
    ///   "naked". It acts as a version number so that any future updates to the
    ///   hash format can tell this hash format apart. Note that "N" is an
    ///   invalid semver.
    /// * sizedhash is the same as in `init`.
    ///
    /// The hash is broken up this way so that "sizedhash" can be calculated
    /// exactly the same way in both cases, and so that "name" and "hashiname" can
    /// be used interchangeably in both cases.
    pub fn initNaked(digest: Digest, size: u32) Hash {
        var name: [32]u8 = undefined;
        _ = std.base64.url_safe_no_pad.Encoder.encode(&name, digest[5..][0..24]);
        return init(digest, &name, "N", size);
    }
};

pub const MultihashFunction = enum(u16) {
    identity = 0x00,
    sha1 = 0x11,
    @"sha2-256" = 0x12,
    @"sha2-512" = 0x13,
    @"sha3-512" = 0x14,
    @"sha3-384" = 0x15,
    @"sha3-256" = 0x16,
    @"sha3-224" = 0x17,
    @"sha2-384" = 0x20,
    @"sha2-256-trunc254-padded" = 0x1012,
    @"sha2-224" = 0x1013,
    @"sha2-512-224" = 0x1014,
    @"sha2-512-256" = 0x1015,
    @"blake2b-256" = 0xb220,
    _,
};

pub const multihash_function: MultihashFunction = switch (Hash.Algo) {
    std.crypto.hash.sha2.Sha256 => .@"sha2-256",
    else => @compileError("unreachable"),
};

pub fn multiHashHexDigest(digest: Hash.Digest) MultiHashHexDigest {
    const hex_charset = std.fmt.hex_charset;

    var result: MultiHashHexDigest = undefined;

    result[0] = hex_charset[@intFromEnum(multihash_function) >> 4];
    result[1] = hex_charset[@intFromEnum(multihash_function) & 15];

    result[2] = hex_charset[Hash.Algo.digest_length >> 4];
    result[3] = hex_charset[Hash.Algo.digest_length & 15];

    for (digest, 0..) |byte, i| {
        result[4 + i * 2] = hex_charset[byte >> 4];
        result[5 + i * 2] = hex_charset[byte & 15];
    }
    return result;
}

comptime {
    // We avoid unnecessary uleb128 code in hexDigest by asserting here the
    // values are small enough to be contained in the one-byte encoding.
    assert(@intFromEnum(multihash_function) < 127);
    assert(Hash.Algo.digest_length < 127);
}

test Hash {
    const example_digest: Hash.Digest = .{
        0xc7, 0xf5, 0x71, 0xb7, 0xb4, 0xe7, 0x6f, 0x3c, 0xdb, 0x87, 0x7a, 0x7f, 0xdd, 0xf9, 0x77, 0x87,
        0x9d, 0xd3, 0x86, 0xfa, 0x73, 0x57, 0x9a, 0xf7, 0x9d, 0x1e, 0xdb, 0x8f, 0x3a, 0xd9, 0xbd, 0x9f,
    };
    const result: Hash = .init(example_digest, "nasm", "2.16.1-2", 10 * 1024 * 1024);
    try std.testing.expectEqualStrings("nasm-2.16.1-2-AACgAMf1cbe0", result.toSlice());
}

test {
    _ = Fetch;
}
