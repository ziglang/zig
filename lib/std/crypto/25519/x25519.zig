const std = @import("std");
const mem = std.mem;
const fmt = std.fmt;

/// X25519 DH function.
pub const X25519 = struct {
    /// The underlying elliptic curve.
    pub const Curve = @import("curve25519.zig").Curve25519;
    /// Length (in bytes) of a secret key.
    pub const secret_length = 32;
    /// Length (in bytes) of the output of the DH function.
    pub const minimum_key_length = 32;

    /// Compute the public key for a given private key.
    pub fn createPublicKey(public_key: []u8, private_key: []const u8) bool {
        std.debug.assert(private_key.len >= minimum_key_length);
        std.debug.assert(public_key.len >= minimum_key_length);
        var s: [32]u8 = undefined;
        mem.copy(u8, &s, private_key[0..32]);
        if (Curve.basePoint().clampedMul(s)) |q| {
            mem.copy(u8, public_key, q.toBytes()[0..]);
            return true;
        } else |_| {
            return false;
        }
    }

    /// Compute the scalar product of a public key and a secret scalar.
    /// Note that the output should not be used as a shared secret without
    /// hashing it first.
    pub fn create(out: []u8, private_key: []const u8, public_key: []const u8) bool {
        std.debug.assert(out.len >= secret_length);
        std.debug.assert(private_key.len >= minimum_key_length);
        std.debug.assert(public_key.len >= minimum_key_length);
        var s: [32]u8 = undefined;
        var b: [32]u8 = undefined;
        mem.copy(u8, &s, private_key[0..32]);
        mem.copy(u8, &b, public_key[0..32]);
        if (Curve.fromBytes(b).clampedMul(s)) |q| {
            mem.copy(u8, out, q.toBytes()[0..]);
            return true;
        } else |_| {
            return false;
        }
    }
};

test "x25519 public key calculation from secret key" {
    var sk: [32]u8 = undefined;
    var pk_expected: [32]u8 = undefined;
    var pk_calculated: [32]u8 = undefined;
    try fmt.hexToBytes(sk[0..], "8052030376d47112be7f73ed7a019293dd12ad910b654455798b4667d73de166");
    try fmt.hexToBytes(pk_expected[0..], "f1814f0e8ff1043d8a44d25babff3cedcae6c22c3edaa48f857ae70de2baae50");
    std.testing.expect(X25519.createPublicKey(pk_calculated[0..], &sk));
    std.testing.expect(std.mem.eql(u8, &pk_calculated, &pk_expected));
}

test "x25519 rfc7748 vector1" {
    const secret_key = "\xa5\x46\xe3\x6b\xf0\x52\x7c\x9d\x3b\x16\x15\x4b\x82\x46\x5e\xdd\x62\x14\x4c\x0a\xc1\xfc\x5a\x18\x50\x6a\x22\x44\xba\x44\x9a\xc4";
    const public_key = "\xe6\xdb\x68\x67\x58\x30\x30\xdb\x35\x94\xc1\xa4\x24\xb1\x5f\x7c\x72\x66\x24\xec\x26\xb3\x35\x3b\x10\xa9\x03\xa6\xd0\xab\x1c\x4c";

    const expected_output = "\xc3\xda\x55\x37\x9d\xe9\xc6\x90\x8e\x94\xea\x4d\xf2\x8d\x08\x4f\x32\xec\xcf\x03\x49\x1c\x71\xf7\x54\xb4\x07\x55\x77\xa2\x85\x52";

    var output: [32]u8 = undefined;

    std.testing.expect(X25519.create(output[0..], secret_key, public_key));
    std.testing.expect(std.mem.eql(u8, &output, expected_output));
}

test "x25519 rfc7748 vector2" {
    const secret_key = "\x4b\x66\xe9\xd4\xd1\xb4\x67\x3c\x5a\xd2\x26\x91\x95\x7d\x6a\xf5\xc1\x1b\x64\x21\xe0\xea\x01\xd4\x2c\xa4\x16\x9e\x79\x18\xba\x0d";
    const public_key = "\xe5\x21\x0f\x12\x78\x68\x11\xd3\xf4\xb7\x95\x9d\x05\x38\xae\x2c\x31\xdb\xe7\x10\x6f\xc0\x3c\x3e\xfc\x4c\xd5\x49\xc7\x15\xa4\x93";

    const expected_output = "\x95\xcb\xde\x94\x76\xe8\x90\x7d\x7a\xad\xe4\x5c\xb4\xb8\x73\xf8\x8b\x59\x5a\x68\x79\x9f\xa1\x52\xe6\xf8\xf7\x64\x7a\xac\x79\x57";

    var output: [32]u8 = undefined;

    std.testing.expect(X25519.create(output[0..], secret_key, public_key));
    std.testing.expect(std.mem.eql(u8, &output, expected_output));
}

test "x25519 rfc7748 one iteration" {
    const initial_value = "\x09\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00".*;
    const expected_output = "\x42\x2c\x8e\x7a\x62\x27\xd7\xbc\xa1\x35\x0b\x3e\x2b\xb7\x27\x9f\x78\x97\xb8\x7b\xb6\x85\x4b\x78\x3c\x60\xe8\x03\x11\xae\x30\x79";

    var k: [32]u8 = initial_value;
    var u: [32]u8 = initial_value;

    var i: usize = 0;
    while (i < 1) : (i += 1) {
        var output: [32]u8 = undefined;
        std.testing.expect(X25519.create(output[0..], &k, &u));

        std.mem.copy(u8, u[0..], k[0..]);
        std.mem.copy(u8, k[0..], output[0..]);
    }

    std.testing.expect(std.mem.eql(u8, k[0..], expected_output));
}

test "x25519 rfc7748 1,000 iterations" {
    // These iteration tests are slow so we always skip them. Results have been verified.
    if (true) {
        return error.SkipZigTest;
    }

    const initial_value = "\x09\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    const expected_output = "\x68\x4c\xf5\x9b\xa8\x33\x09\x55\x28\x00\xef\x56\x6f\x2f\x4d\x3c\x1c\x38\x87\xc4\x93\x60\xe3\x87\x5f\x2e\xb9\x4d\x99\x53\x2c\x51";

    var k: [32]u8 = initial_value.*;
    var u: [32]u8 = initial_value.*;

    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        var output: [32]u8 = undefined;
        std.testing.expect(X25519.create(output[0..], &k, &u));

        std.mem.copy(u8, u[0..], k[0..]);
        std.mem.copy(u8, k[0..], output[0..]);
    }

    std.testing.expect(std.mem.eql(u8, k[0..], expected_output));
}

test "x25519 rfc7748 1,000,000 iterations" {
    if (true) {
        return error.SkipZigTest;
    }

    const initial_value = "\x09\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00";
    const expected_output = "\x7c\x39\x11\xe0\xab\x25\x86\xfd\x86\x44\x97\x29\x7e\x57\x5e\x6f\x3b\xc6\x01\xc0\x88\x3c\x30\xdf\x5f\x4d\xd2\xd2\x4f\x66\x54\x24";

    var k: [32]u8 = initial_value.*;
    var u: [32]u8 = initial_value.*;

    var i: usize = 0;
    while (i < 1000000) : (i += 1) {
        var output: [32]u8 = undefined;
        std.testing.expect(X25519.create(output[0..], &k, &u));

        std.mem.copy(u8, u[0..], k[0..]);
        std.mem.copy(u8, k[0..], output[0..]);
    }

    std.testing.expect(std.mem.eql(u8, k[0..], expected_output));
}
