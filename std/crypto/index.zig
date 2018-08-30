pub const Md5 = @import("md5.zig").Md5;
pub const Sha1 = @import("sha1.zig").Sha1;

const sha2 = @import("sha2.zig");
pub const Sha224 = sha2.Sha224;
pub const Sha256 = sha2.Sha256;
pub const Sha384 = sha2.Sha384;
pub const Sha512 = sha2.Sha512;

const sha3 = @import("sha3.zig");
pub const Sha3_224 = sha3.Sha3_224;
pub const Sha3_256 = sha3.Sha3_256;
pub const Sha3_384 = sha3.Sha3_384;
pub const Sha3_512 = sha3.Sha3_512;

const blake2 = @import("blake2.zig");
pub const Blake2s224 = blake2.Blake2s224;
pub const Blake2s256 = blake2.Blake2s256;
pub const Blake2b384 = blake2.Blake2b384;
pub const Blake2b512 = blake2.Blake2b512;

const hmac = @import("hmac.zig");
pub const HmacMd5 = hmac.HmacMd5;
pub const HmacSha1 = hmac.Sha1;
pub const HmacSha256 = hmac.Sha256;

const import_chaCha20 = @import("chacha20.zig");
pub const chaCha20IETF = import_chaCha20.chaCha20IETF;
pub const chaCha20With64BitNonce = import_chaCha20.chaCha20With64BitNonce;

const poly1305 = @import("poly1305.zig");
const x25519 = @import("x25519.zig");

test "crypto" {
    _ = @import("md5.zig");
    _ = @import("sha1.zig");
    _ = @import("sha2.zig");
    _ = @import("sha3.zig");
    _ = @import("blake2.zig");
    _ = @import("hmac.zig");
    _ = @import("chacha20.zig");
    _ = @import("poly1305.zig");
    _ = @import("x25519.zig");
}
