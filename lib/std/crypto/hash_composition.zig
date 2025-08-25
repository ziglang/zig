const std = @import("../std.zig");
const sha2 = std.crypto.hash.sha2;

/// The composition of two hash functions: H1 o H2, with the same API as regular hash functions.
///
/// The security level of a hash cascade doesn't exceed the security level of the weakest function.
///
/// However, Merkle–Damgård constructions such as SHA-256 are vulnerable to length-extension attacks,
/// where under some conditions, `H(x||e)` can be efficiently computed without knowing `x`.
/// The composition of two hash functions is a common defense against such attacks.
///
/// This is not necessary with modern hash functions, such as SHA-3, BLAKE2 and BLAKE3.
pub fn Composition(comptime H1: type, comptime H2: type) type {
    return struct {
        const Self = @This();

        H1: H1,
        H2: H2,

        /// The length of the hash output, in bytes.
        pub const digest_length = H1.digest_length;
        /// The block length, in bytes.
        pub const block_length = H1.block_length;

        /// Options for both hashes.
        pub const Options = struct {
            /// Options for H1.
            H1: H1.Options = .{},
            /// Options for H2.
            H2: H2.Options = .{},
        };

        /// Initialize the hash composition with the given options.
        pub fn init(options: Options) Self {
            return Self{ .H1 = H1.init(options.H1), .H2 = H2.init(options.H2) };
        }

        /// Compute H1(H2(b)).
        pub fn hash(b: []const u8, out: *[digest_length]u8, options: Options) void {
            var d = Self.init(options);
            d.update(b);
            d.final(out);
        }

        /// Add content to the hash.
        pub fn update(d: *Self, b: []const u8) void {
            d.H2.update(b);
        }

        /// Compute the final hash for the accumulated content: H1(H2(b)).
        pub fn final(d: *Self, out: *[digest_length]u8) void {
            var H2_digest: [H2.digest_length]u8 = undefined;
            d.H2.final(&H2_digest);
            d.H1.update(&H2_digest);
            d.H1.final(out);
        }
    };
}

/// SHA-256(SHA-256())
pub const Sha256oSha256 = Composition(sha2.Sha256, sha2.Sha256);
/// SHA-384(SHA-384())
pub const Sha384oSha384 = Composition(sha2.Sha384, sha2.Sha384);
/// SHA-512(SHA-512())
pub const Sha512oSha512 = Composition(sha2.Sha512, sha2.Sha512);

test "Hash composition" {
    const Sha256 = sha2.Sha256;
    const msg = "test";

    var out: [Sha256oSha256.digest_length]u8 = undefined;
    Sha256oSha256.hash(msg, &out, .{});

    var t: [Sha256.digest_length]u8 = undefined;
    Sha256.hash(msg, &t, .{});
    var out2: [Sha256.digest_length]u8 = undefined;
    Sha256.hash(&t, &out2, .{});

    try std.testing.expectEqualSlices(u8, &out, &out2);
}
