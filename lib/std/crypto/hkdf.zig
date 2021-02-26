// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

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
        /// Return a master key from a salt and initial keying material.
        pub fn extract(salt: []const u8, ikm: []const u8) [Hmac.mac_length]u8 {
            var prk: [Hmac.mac_length]u8 = undefined;
            Hmac.create(&prk, ikm, salt);
            return prk;
        }

        /// Derive a subkey from a master key `prk` and a subkey description `ctx`.
        pub fn expand(out: []u8, ctx: []const u8, prk: [Hmac.mac_length]u8) void {
            assert(out.len < Hmac.mac_length * 255); // output size is too large for the Hkdf construction
            var i: usize = 0;
            var counter = [1]u8{1};
            while (i + Hmac.mac_length <= out.len) : (i += Hmac.mac_length) {
                var st = Hmac.init(&prk);
                if (i != 0) {
                    st.update(out[i - Hmac.mac_length ..][0..Hmac.mac_length]);
                }
                st.update(ctx);
                st.update(&counter);
                st.final(out[i..][0..Hmac.mac_length]);
                counter[0] += 1;
            }
            const left = out.len % Hmac.mac_length;
            if (left > 0) {
                var st = Hmac.init(&prk);
                if (i != 0) {
                    st.update(out[i - Hmac.mac_length ..][0..Hmac.mac_length]);
                }
                st.update(ctx);
                st.update(&counter);
                var tmp: [Hmac.mac_length]u8 = undefined;
                st.final(tmp[0..Hmac.mac_length]);
                mem.copy(u8, out[i..][0..left], tmp[0..left]);
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
    htest.assertEqual("077709362c2e32df0ddc3f0dc47bba6390b6c73bb50f9c3122ec844ad7c2b3e5", &prk);
    var out: [42]u8 = undefined;
    kdf.expand(&out, &context, prk);
    htest.assertEqual("3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865", &out);
}
