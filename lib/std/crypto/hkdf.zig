const std = @import("../std.zig");
const assert = std.debug.assert;
const hmac = std.crypto.auth.hmac;
const mem = std.mem;

/// HKDF-SHA256
pub const HkdfSha256 = Hkdf(hmac.sha2.HmacSha256);

/// HKDF-SHA512
pub const HkdfSha512 = Hkdf(hmac.sha2.HmacSha512);

/// The Hkdf construction takes some source of initial keying material and
/// derives one or more uniform keys from it.
pub fn Hkdf(comptime Hmac: type) type {
    return struct {
        /// Length of a master key, in bytes.
        pub const prk_length = Hmac.mac_length;

        /// Return a master key from a salt and initial keying material.
        pub fn extract(salt: []const u8, ikm: []const u8) [prk_length]u8 {
            var prk: [prk_length]u8 = undefined;
            Hmac.create(&prk, ikm, salt);
            return prk;
        }

        /// Initialize the creation of a master key from a salt
        /// and keying material that can be added later, possibly in chunks.
        /// Example:
        /// ```
        /// var prk: [hkdf.prk_length]u8 = undefined;
        /// var hkdf = HkdfSha256.extractInit(salt);
        /// hkdf.update(ikm1);
        /// hkdf.update(ikm2);
        /// hkdf.final(&prk);
        /// ```
        pub fn extractInit(salt: []const u8) Hmac {
            return Hmac.init(salt);
        }

        /// Derive a subkey from a master key `prk` and a subkey description `ctx`.
        pub fn expand(out: []u8, ctx: []const u8, prk: [prk_length]u8) void {
            assert(out.len <= prk_length * 255); // output size is too large for the Hkdf construction
            var i: usize = 0;
            var counter = [1]u8{1};
            while (i + prk_length <= out.len) : (i += prk_length) {
                var st = Hmac.init(&prk);
                if (i != 0) {
                    st.update(out[i - prk_length ..][0..prk_length]);
                }
                st.update(ctx);
                st.update(&counter);
                st.final(out[i..][0..prk_length]);
                counter[0] +%= 1;
                assert(counter[0] != 1);
            }
            const left = out.len % prk_length;
            if (left > 0) {
                var st = Hmac.init(&prk);
                if (i != 0) {
                    st.update(out[i - prk_length ..][0..prk_length]);
                }
                st.update(ctx);
                st.update(&counter);
                var tmp: [prk_length]u8 = undefined;
                st.final(tmp[0..prk_length]);
                @memcpy(out[i..][0..left], tmp[0..left]);
            }
        }
    };
}

const htest = @import("test.zig");

test "Hkdf" {
    const ikm = [_]u8{0x0b} ** 22;
    const salt = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c };
    const context = [_]u8{ 0xf0, 0xf1, 0xf2, 0xf3, 0xf4, 0xf5, 0xf6, 0xf7, 0xf8, 0xf9 };
    const kdf = HkdfSha256;
    const prk = kdf.extract(&salt, &ikm);
    try htest.assertEqual("077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5", &prk);
    var out: [42]u8 = undefined;
    kdf.expand(&out, &context, prk);
    try htest.assertEqual("3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865", &out);

    var hkdf = kdf.extractInit(&salt);
    hkdf.update(&ikm);
    var prk2: [kdf.prk_length]u8 = undefined;
    hkdf.final(&prk2);
    try htest.assertEqual("077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5", &prk2);
}
