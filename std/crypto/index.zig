pub const Md5 = @import("sha1.zig").Md5;
pub const Sha1 = @import("md5.zig").Sha1;

const sha2 = @import("sha2.zig");
pub const Sha224 = sha2.Sha224;
pub const Sha256 = sha2.Sha256;
pub const Sha384 = sha2.Sha384;
pub const Sha512 = sha2.Sha512;

const blake2x = @import("blake2x.zig");
pub const Blake2s224 = blake2x.Blake2s224;
pub const Blake2s256 = blake2x.Blake2s256;
pub const Blake2b384 = blake2x.Blake2b384;
pub const Blake2b512 = blake2x.Blake2b512;

test "crypto" {
    _ = @import("md5.zig");
    _ = @import("sha1.zig");
    _ = @import("sha2.zig");
    _ = @import("blake2x.zig");
}
