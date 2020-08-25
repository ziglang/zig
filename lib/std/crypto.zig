// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2020 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

/// Hash functions.
pub const hash = struct {
    pub const Md5 = @import("crypto/md5.zig").Md5;
    pub const Sha1 = @import("crypto/sha1.zig").Sha1;
    pub const sha2 = @import("crypto/sha2.zig");
    pub const sha3 = @import("crypto/sha3.zig");
    pub const blake2 = @import("crypto/blake2.zig");
    pub const Blake3 = @import("crypto/blake3.zig").Blake3;
    pub const Gimli = @import("crypto/gimli.zig").Hash;
};

/// Authentication (MAC) functions.
pub const auth = struct {
    pub const hmac = @import("crypto/hmac.zig");
    pub const siphash = @import("crypto/siphash.zig");
};

/// Authenticated Encryption with Associated Data
pub const aead = struct {
    const chacha20 = @import("crypto/chacha20.zig");

    pub const Gimli = @import("crypto/gimli.zig").Aead;
    pub const ChaCha20Poly1305 = chacha20.Chacha20Poly1305;
    pub const XChaCha20Poly1305 = chacha20.XChacha20Poly1305;
};

/// MAC functions requiring single-use secret keys.
pub const onetimeauth = struct {
    pub const Poly1305 = @import("crypto/poly1305.zig").Poly1305;
};

/// Core functions, that should rarely be used directly by applications.
pub const core = struct {
    pub const aes = @import("crypto/aes.zig");
    pub const Gimli = @import("crypto/gimli.zig").State;
};

/// Elliptic-curve arithmetic.
pub const ecc = struct {
    pub const Curve25519 = @import("crypto/25519/curve25519.zig").Curve25519;
    pub const Edwards25519 = @import("crypto/25519/edwards25519.zig").Edwards25519;
    pub const Ristretto255 = @import("crypto/25519/ristretto255.zig").Ristretto255;
};

/// Diffie-Hellman key exchange functions.
pub const dh = struct {
    pub const X25519 = @import("crypto/25519/x25519.zig").X25519;
};

/// Digital signature functions.
pub const sign = struct {
    pub const Ed25519 = @import("crypto/25519/ed25519.zig").Ed25519;
};

/// Stream ciphers. These do not provide any kind of authentication.
/// Most applications should be using AEAD constructions instead of stream ciphers directly.
pub const stream = struct {
    pub const ChaCha20IETF = @import("crypto/chacha20.zig").ChaCha20IETF;
    pub const XChaCha20IETF = @import("crypto/chacha20.zig").XChaCha20IETF;
    pub const ChaCha20With64BitNonce = @import("crypto/chacha20.zig").ChaCha20With64BitNonce;
};

const std = @import("std.zig");
pub const randomBytes = std.os.getrandom;

test "crypto" {
    _ = @import("crypto/aes.zig");
    _ = @import("crypto/blake2.zig");
    _ = @import("crypto/blake3.zig");
    _ = @import("crypto/chacha20.zig");
    _ = @import("crypto/gimli.zig");
    _ = @import("crypto/hmac.zig");
    _ = @import("crypto/md5.zig");
    _ = @import("crypto/poly1305.zig");
    _ = @import("crypto/sha1.zig");
    _ = @import("crypto/sha2.zig");
    _ = @import("crypto/sha3.zig");
    _ = @import("crypto/siphash.zig");
    _ = @import("crypto/25519/curve25519.zig");
    _ = @import("crypto/25519/ed25519.zig");
    _ = @import("crypto/25519/edwards25519.zig");
    _ = @import("crypto/25519/field.zig");
    _ = @import("crypto/25519/scalar.zig");
    _ = @import("crypto/25519/x25519.zig");
    _ = @import("crypto/25519/ristretto255.zig");
}

test "issue #4532: no index out of bounds" {
    const types = [_]type{
        hash.Md5,
        hash.Sha1,
        hash.sha2.Sha224,
        hash.sha2.Sha256,
        hash.sha2.Sha384,
        hash.sha2.Sha512,
        hash.sha3.Sha3_224,
        hash.sha3.Sha3_256,
        hash.sha3.Sha3_384,
        hash.sha3.Sha3_512,
        hash.blake2.Blake2s224,
        hash.blake2.Blake2s256,
        hash.blake2.Blake2b384,
        hash.blake2.Blake2b512,
        hash.Gimli,
    };

    inline for (types) |Hasher| {
        var block = [_]u8{'#'} ** Hasher.block_length;
        var out1: [Hasher.digest_length]u8 = undefined;
        var out2: [Hasher.digest_length]u8 = undefined;
        const h0 = Hasher.init(.{});
        var h = h0;
        h.update(block[0..]);
        h.final(out1[0..]);
        h = h0;
        h.update(block[0..1]);
        h.update(block[1..]);
        h.final(out2[0..]);

        std.testing.expectEqual(out1, out2);
    }
}
