const std = @import("std");
const mem = std.mem;
const maxInt = std.math.maxInt;
const OutputTooLongError = std.crypto.errors.OutputTooLongError;
const WeakParametersError = std.crypto.errors.WeakParametersError;

// RFC 2898 Section 5.2
//
// FromSpec:
//
// PBKDF2 applies a pseudorandom function (see Appendix B.1 for an
// example) to derive keys. The length of the derived key is essentially
// unbounded. (However, the maximum effective search space for the
// derived key may be limited by the structure of the underlying
// pseudorandom function. See Appendix B.1 for further discussion.)
// PBKDF2 is recommended for new applications.
//
// PBKDF2 (P, S, c, dk_len)
//
// Options:        PRF        underlying pseudorandom function (h_len
//                            denotes the length in octets of the
//                            pseudorandom function output)
//
// Input:          P          password, an octet string
//                 S          salt, an octet string
//                 c          iteration count, a positive integer
//                 dk_len      intended length in octets of the derived
//                            key, a positive integer, at most
//                            (2^32 - 1) * h_len
//
// Output:         DK         derived key, a dk_len-octet string

// Based on Apple's CommonKeyDerivation, based originally on code by Damien Bergamini.

/// Apply PBKDF2 to generate a key from a password.
///
/// PBKDF2 is defined in RFC 2898, and is a recommendation of NIST SP 800-132.
///
/// dk: Slice of appropriate size for generated key. Generally 16 or 32 bytes in length.
///             May be uninitialized. All bytes will be overwritten.
///             Maximum size is `maxInt(u32) * Hash.digest_length`
///             It is a programming error to pass buffer longer than the maximum size.
///
/// password: Arbitrary sequence of bytes of any length, including empty.
///
/// salt: Arbitrary sequence of bytes of any length, including empty. A common length is 8 bytes.
///
/// rounds: Iteration count. Must be greater than 0. Common values range from 1,000 to 100,000.
///         Larger iteration counts improve security by increasing the time required to compute
///         the dk. It is common to tune this parameter to achieve approximately 100ms.
///
/// Prf: Pseudo-random function to use. A common choice is `std.crypto.auth.hmac.sha2.HmacSha256`.
pub fn pbkdf2(dk: []u8, password: []const u8, salt: []const u8, rounds: u32, comptime Prf: type) (WeakParametersError || OutputTooLongError)!void {
    if (rounds < 1) return error.WeakParameters;

    const dk_len = dk.len;
    const h_len = Prf.mac_length;
    comptime std.debug.assert(h_len >= 1);

    // FromSpec:
    //
    //   1. If dk_len > maxInt(u32) * h_len, output "derived key too long" and
    //      stop.
    //
    if (dk_len / h_len >= maxInt(u32)) {
        // Counter starts at 1 and is 32 bit, so if we have to return more blocks, we would overflow
        return error.OutputTooLong;
    }

    // FromSpec:
    //
    //   2. Let l be the number of h_len-long blocks of bytes in the derived key,
    //      rounding up, and let r be the number of bytes in the last
    //      block
    //

    const blocks_count = @as(u32, @intCast(std.math.divCeil(usize, dk_len, h_len) catch unreachable));
    var r = dk_len % h_len;
    if (r == 0) {
        r = h_len;
    }

    // FromSpec:
    //
    //   3. For each block of the derived key apply the function F defined
    //      below to the password P, the salt S, the iteration count c, and
    //      the block index to compute the block:
    //
    //                T_1 = F (P, S, c, 1) ,
    //                T_2 = F (P, S, c, 2) ,
    //                ...
    //                T_l = F (P, S, c, l) ,
    //
    //      where the function F is defined as the exclusive-or sum of the
    //      first c iterates of the underlying pseudorandom function PRF
    //      applied to the password P and the concatenation of the salt S
    //      and the block index i:
    //
    //                F (P, S, c, i) = U_1 \xor U_2 \xor ... \xor U_c
    //
    //  where
    //
    //            U_1 = PRF (P, S || INT (i)) ,
    //            U_2 = PRF (P, U_1) ,
    //            ...
    //            U_c = PRF (P, U_{c-1}) .
    //
    //  Here, INT (i) is a four-octet encoding of the integer i, most
    //  significant octet first.
    //
    //  4. Concatenate the blocks and extract the first dk_len octets to
    //  produce a derived key DK:
    //
    //            DK = T_1 || T_2 ||  ...  || T_l<0..r-1>

    var block: u32 = 0;
    while (block < blocks_count) : (block += 1) {
        var prev_block: [h_len]u8 = undefined;
        var new_block: [h_len]u8 = undefined;

        // U_1 = PRF (P, S || INT (i))
        const block_index = mem.toBytes(mem.nativeToBig(u32, block + 1)); // Block index starts at 0001
        var ctx = Prf.init(password);
        ctx.update(salt);
        ctx.update(block_index[0..]);
        ctx.final(prev_block[0..]);

        // Choose portion of DK to write into (T_n) and initialize
        const offset = block * h_len;
        const block_len = if (block != blocks_count - 1) h_len else r;
        const dk_block: []u8 = dk[offset..][0..block_len];
        @memcpy(dk_block, prev_block[0..dk_block.len]);

        var i: u32 = 1;
        while (i < rounds) : (i += 1) {
            // U_c = PRF (P, U_{c-1})
            Prf.create(&new_block, prev_block[0..], password);
            prev_block = new_block;

            // F (P, S, c, i) = U_1 \xor U_2 \xor ... \xor U_c
            for (dk_block, 0..) |_, j| {
                dk_block[j] ^= new_block[j];
            }
        }
    }
}

const htest = @import("test.zig");
const HmacSha1 = std.crypto.auth.hmac.HmacSha1;

// RFC 6070 PBKDF2 HMAC-SHA1 Test Vectors

test "RFC 6070 one iteration" {
    const p = "password";
    const s = "salt";
    const c = 1;
    const dk_len = 20;

    var dk: [dk_len]u8 = undefined;

    try pbkdf2(&dk, p, s, c, HmacSha1);

    const expected = "0c60c80f961f0e71f3a9b524af6012062fe037a6";

    try htest.assertEqual(expected, dk[0..]);
}

test "RFC 6070 two iterations" {
    const p = "password";
    const s = "salt";
    const c = 2;
    const dk_len = 20;

    var dk: [dk_len]u8 = undefined;

    try pbkdf2(&dk, p, s, c, HmacSha1);

    const expected = "ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957";

    try htest.assertEqual(expected, dk[0..]);
}

test "RFC 6070 4096 iterations" {
    const p = "password";
    const s = "salt";
    const c = 4096;
    const dk_len = 20;

    var dk: [dk_len]u8 = undefined;

    try pbkdf2(&dk, p, s, c, HmacSha1);

    const expected = "4b007901b765489abead49d926f721d065a429c1";

    try htest.assertEqual(expected, dk[0..]);
}

test "RFC 6070 16,777,216 iterations" {
    // These iteration tests are slow so we always skip them. Results have been verified.
    if (true) {
        return error.SkipZigTest;
    }

    const p = "password";
    const s = "salt";
    const c = 16777216;
    const dk_len = 20;

    var dk = [_]u8{0} ** dk_len;

    try pbkdf2(&dk, p, s, c, HmacSha1);

    const expected = "eefe3d61cd4da4e4e9945b3d6ba2158c2634e984";

    try htest.assertEqual(expected, dk[0..]);
}

test "RFC 6070 multi-block salt and password" {
    const p = "passwordPASSWORDpassword";
    const s = "saltSALTsaltSALTsaltSALTsaltSALTsalt";
    const c = 4096;
    const dk_len = 25;

    var dk: [dk_len]u8 = undefined;

    try pbkdf2(&dk, p, s, c, HmacSha1);

    const expected = "3d2eec4fe41c849b80c8d83662c0e44a8b291a964cf2f07038";

    try htest.assertEqual(expected, dk[0..]);
}

test "RFC 6070 embedded NUL" {
    const p = "pass\x00word";
    const s = "sa\x00lt";
    const c = 4096;
    const dk_len = 16;

    var dk: [dk_len]u8 = undefined;

    try pbkdf2(&dk, p, s, c, HmacSha1);

    const expected = "56fa6aa75548099dcc37d7f03425e0c3";

    try htest.assertEqual(expected, dk[0..]);
}

test "Very large dk_len" {
    // This test allocates 8GB of memory and is expected to take several hours to run.
    if (true) {
        return error.SkipZigTest;
    }
    const p = "password";
    const s = "salt";
    const c = 1;
    const dk_len = 1 << 33;

    var dk = try std.testing.allocator.alloc(u8, dk_len);
    defer {
        std.testing.allocator.free(dk);
    }

    // Just verify this doesn't crash with an overflow
    try pbkdf2(dk, p, s, c, HmacSha1);
}
