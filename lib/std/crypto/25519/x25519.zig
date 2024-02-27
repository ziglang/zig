const std = @import("std");
const crypto = std.crypto;
const mem = std.mem;
const fmt = std.fmt;

const Sha512 = crypto.hash.sha2.Sha512;

const EncodingError = crypto.errors.EncodingError;
const IdentityElementError = crypto.errors.IdentityElementError;
const WeakPublicKeyError = crypto.errors.WeakPublicKeyError;

/// X25519 DH function.
pub const X25519 = struct {
    /// The underlying elliptic curve.
    pub const Curve = @import("curve25519.zig").Curve25519;
    /// Length (in bytes) of a secret key.
    pub const secret_length = 32;
    /// Length (in bytes) of a public key.
    pub const public_length = 32;
    /// Length (in bytes) of the output of the DH function.
    pub const shared_length = 32;
    /// Seed (for key pair creation) length in bytes.
    pub const seed_length = 32;

    /// An X25519 key pair.
    pub const KeyPair = struct {
        /// Public part.
        public_key: [public_length]u8,
        /// Secret part.
        secret_key: [secret_length]u8,

        /// Create a new key pair using an optional seed.
        pub fn create(seed: ?[seed_length]u8) IdentityElementError!KeyPair {
            const sk = seed orelse sk: {
                var random_seed: [seed_length]u8 = undefined;
                crypto.random.bytes(&random_seed);
                break :sk random_seed;
            };
            var kp: KeyPair = undefined;
            kp.secret_key = sk;
            kp.public_key = try X25519.recoverPublicKey(sk);
            return kp;
        }

        /// Create a key pair from an Ed25519 key pair
        pub fn fromEd25519(ed25519_key_pair: crypto.sign.Ed25519.KeyPair) (IdentityElementError || EncodingError)!KeyPair {
            const seed = ed25519_key_pair.secret_key.seed();
            var az: [Sha512.digest_length]u8 = undefined;
            Sha512.hash(&seed, &az, .{});
            var sk = az[0..32].*;
            Curve.scalar.clamp(&sk);
            const pk = try publicKeyFromEd25519(ed25519_key_pair.public_key);
            return KeyPair{
                .public_key = pk,
                .secret_key = sk,
            };
        }
    };

    /// Compute the public key for a given private key.
    pub fn recoverPublicKey(secret_key: [secret_length]u8) IdentityElementError![public_length]u8 {
        const q = try Curve.basePoint.clampedMul(secret_key);
        return q.toBytes();
    }

    /// Compute the X25519 equivalent to an Ed25519 public eky.
    pub fn publicKeyFromEd25519(ed25519_public_key: crypto.sign.Ed25519.PublicKey) (IdentityElementError || EncodingError)![public_length]u8 {
        const pk_ed = try crypto.ecc.Edwards25519.fromBytes(ed25519_public_key.bytes);
        const pk = try Curve.fromEdwards25519(pk_ed);
        return pk.toBytes();
    }

    /// Compute the scalar product of a public key and a secret scalar.
    /// Note that the output should not be used as a shared secret without
    /// hashing it first.
    pub fn scalarmult(secret_key: [secret_length]u8, public_key: [public_length]u8) IdentityElementError![shared_length]u8 {
        const q = try Curve.fromBytes(public_key).clampedMul(secret_key);
        return q.toBytes();
    }
};

const htest = @import("../test.zig");

test "public key calculation from secret key" {
    var sk: [32]u8 = undefined;
    var pk_expected: [32]u8 = undefined;
    _ = try fmt.hexToBytes(sk[0..], "8052030376d47112be7f73ed7a019293dd12ad910b654455798b4667d73de166");
    _ = try fmt.hexToBytes(pk_expected[0..], "f1814f0e8ff1043d8a44d25babff3cedcae6c22c3edaa48f857ae70de2baae50");
    const pk_calculated = try X25519.recoverPublicKey(sk);
    try std.testing.expectEqual(pk_calculated, pk_expected);
}

test "rfc7748 vector1" {
    const secret_key = [32]u8{ 0xa5, 0x46, 0xe3, 0x6b, 0xf0, 0x52, 0x7c, 0x9d, 0x3b, 0x16, 0x15, 0x4b, 0x82, 0x46, 0x5e, 0xdd, 0x62, 0x14, 0x4c, 0x0a, 0xc1, 0xfc, 0x5a, 0x18, 0x50, 0x6a, 0x22, 0x44, 0xba, 0x44, 0x9a, 0xc4 };
    const public_key = [32]u8{ 0xe6, 0xdb, 0x68, 0x67, 0x58, 0x30, 0x30, 0xdb, 0x35, 0x94, 0xc1, 0xa4, 0x24, 0xb1, 0x5f, 0x7c, 0x72, 0x66, 0x24, 0xec, 0x26, 0xb3, 0x35, 0x3b, 0x10, 0xa9, 0x03, 0xa6, 0xd0, 0xab, 0x1c, 0x4c };

    const expected_output = [32]u8{ 0xc3, 0xda, 0x55, 0x37, 0x9d, 0xe9, 0xc6, 0x90, 0x8e, 0x94, 0xea, 0x4d, 0xf2, 0x8d, 0x08, 0x4f, 0x32, 0xec, 0xcf, 0x03, 0x49, 0x1c, 0x71, 0xf7, 0x54, 0xb4, 0x07, 0x55, 0x77, 0xa2, 0x85, 0x52 };

    const output = try X25519.scalarmult(secret_key, public_key);
    try std.testing.expectEqual(output, expected_output);
}

test "rfc7748 vector2" {
    const secret_key = [32]u8{ 0x4b, 0x66, 0xe9, 0xd4, 0xd1, 0xb4, 0x67, 0x3c, 0x5a, 0xd2, 0x26, 0x91, 0x95, 0x7d, 0x6a, 0xf5, 0xc1, 0x1b, 0x64, 0x21, 0xe0, 0xea, 0x01, 0xd4, 0x2c, 0xa4, 0x16, 0x9e, 0x79, 0x18, 0xba, 0x0d };
    const public_key = [32]u8{ 0xe5, 0x21, 0x0f, 0x12, 0x78, 0x68, 0x11, 0xd3, 0xf4, 0xb7, 0x95, 0x9d, 0x05, 0x38, 0xae, 0x2c, 0x31, 0xdb, 0xe7, 0x10, 0x6f, 0xc0, 0x3c, 0x3e, 0xfc, 0x4c, 0xd5, 0x49, 0xc7, 0x15, 0xa4, 0x93 };

    const expected_output = [32]u8{ 0x95, 0xcb, 0xde, 0x94, 0x76, 0xe8, 0x90, 0x7d, 0x7a, 0xad, 0xe4, 0x5c, 0xb4, 0xb8, 0x73, 0xf8, 0x8b, 0x59, 0x5a, 0x68, 0x79, 0x9f, 0xa1, 0x52, 0xe6, 0xf8, 0xf7, 0x64, 0x7a, 0xac, 0x79, 0x57 };

    const output = try X25519.scalarmult(secret_key, public_key);
    try std.testing.expectEqual(output, expected_output);
}

test "rfc7748 one iteration" {
    const initial_value = [32]u8{ 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const expected_output = [32]u8{ 0x42, 0x2c, 0x8e, 0x7a, 0x62, 0x27, 0xd7, 0xbc, 0xa1, 0x35, 0x0b, 0x3e, 0x2b, 0xb7, 0x27, 0x9f, 0x78, 0x97, 0xb8, 0x7b, 0xb6, 0x85, 0x4b, 0x78, 0x3c, 0x60, 0xe8, 0x03, 0x11, 0xae, 0x30, 0x79 };

    var k: [32]u8 = initial_value;
    var u: [32]u8 = initial_value;

    var i: usize = 0;
    while (i < 1) : (i += 1) {
        const output = try X25519.scalarmult(k, u);
        u = k;
        k = output;
    }

    try std.testing.expectEqual(k, expected_output);
}

test "rfc7748 1,000 iterations" {
    // These iteration tests are slow so we always skip them. Results have been verified.
    if (true) {
        return error.SkipZigTest;
    }

    const initial_value = [32]u8{ 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const expected_output = [32]u8{ 0x68, 0x4c, 0xf5, 0x9b, 0xa8, 0x33, 0x09, 0x55, 0x28, 0x00, 0xef, 0x56, 0x6f, 0x2f, 0x4d, 0x3c, 0x1c, 0x38, 0x87, 0xc4, 0x93, 0x60, 0xe3, 0x87, 0x5f, 0x2e, 0xb9, 0x4d, 0x99, 0x53, 0x2c, 0x51 };

    var k: [32]u8 = initial_value.*;
    var u: [32]u8 = initial_value.*;

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const output = try X25519.scalarmult(&k, &u);
        u = k;
        k = output;
    }

    try std.testing.expectEqual(k, expected_output);
}

test "rfc7748 1,000,000 iterations" {
    if (true) {
        return error.SkipZigTest;
    }

    const initial_value = [32]u8{ 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    const expected_output = [32]u8{ 0x7c, 0x39, 0x11, 0xe0, 0xab, 0x25, 0x86, 0xfd, 0x86, 0x44, 0x97, 0x29, 0x7e, 0x57, 0x5e, 0x6f, 0x3b, 0xc6, 0x01, 0xc0, 0x88, 0x3c, 0x30, 0xdf, 0x5f, 0x4d, 0xd2, 0xd2, 0x4f, 0x66, 0x54, 0x24 };

    var k: [32]u8 = initial_value.*;
    var u: [32]u8 = initial_value.*;

    var i: usize = 0;
    while (i < 1000000) : (i += 1) {
        const output = try X25519.scalarmult(&k, &u);
        u = k;
        k = output;
    }

    try std.testing.expectEqual(k[0..], expected_output);
}

test "edwards25519 -> curve25519 map" {
    const ed_kp = try crypto.sign.Ed25519.KeyPair.create([_]u8{0x42} ** 32);
    const mont_kp = try X25519.KeyPair.fromEd25519(ed_kp);
    try htest.assertEqual("90e7595fc89e52fdfddce9c6a43d74dbf6047025ee0462d2d172e8b6a2841d6e", &mont_kp.secret_key);
    try htest.assertEqual("cc4f2cdb695dd766f34118eb67b98652fed1d8bc49c330b119bbfa8a64989378", &mont_kp.public_key);
}
