const std = @import("std");
const fmt = std.fmt;
const testing = std.testing;

const Secp256k1 = @import("../secp256k1.zig").Secp256k1;

test "secp256k1 ECDH key exchange" {
    const dha = Secp256k1.scalar.random(.little);
    const dhb = Secp256k1.scalar.random(.little);
    const dhA = try Secp256k1.basePoint.mul(dha, .little);
    const dhB = try Secp256k1.basePoint.mul(dhb, .little);
    const shareda = try dhA.mul(dhb, .little);
    const sharedb = try dhB.mul(dha, .little);
    try testing.expect(shareda.equivalent(sharedb));
}

test "secp256k1 ECDH key exchange including public multiplication" {
    const dha = Secp256k1.scalar.random(.little);
    const dhb = Secp256k1.scalar.random(.little);
    const dhA = try Secp256k1.basePoint.mul(dha, .little);
    const dhB = try Secp256k1.basePoint.mulPublic(dhb, .little);
    const shareda = try dhA.mul(dhb, .little);
    const sharedb = try dhB.mulPublic(dha, .little);
    try testing.expect(shareda.equivalent(sharedb));
}

test "secp256k1 point from affine coordinates" {
    const xh = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798";
    const yh = "483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8";
    var xs: [32]u8 = undefined;
    _ = try fmt.hexToBytes(&xs, xh);
    var ys: [32]u8 = undefined;
    _ = try fmt.hexToBytes(&ys, yh);
    var p = try Secp256k1.fromSerializedAffineCoordinates(xs, ys, .big);
    try testing.expect(p.equivalent(Secp256k1.basePoint));
}

test "secp256k1 test vectors" {
    const expected = [_][]const u8{
        "0000000000000000000000000000000000000000000000000000000000000000",
        "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
        "c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5",
        "f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9",
        "e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd13",
        "2f8bde4d1a07209355b4a7250a5c5128e88b84bddc619ab7cba8d569b240efe4",
        "fff97bd5755eeea420453a14355235d382f6472f8568a18b2f057a1460297556",
        "5cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc",
        "2f01e5e15cca351daff3843fb70f3c2f0a1bdd05e5af888a67784ef3e10a2a01",
        "acd484e2f0c7f65309ad178a9f559abde09796974c57e714c35f110dfc27ccbe",
    };
    var p = Secp256k1.identityElement;
    for (expected) |xh| {
        const x = p.affineCoordinates().x;
        p = p.add(Secp256k1.basePoint);
        var xs: [32]u8 = undefined;
        _ = try fmt.hexToBytes(&xs, xh);
        try testing.expectEqualSlices(u8, &x.toBytes(.big), &xs);
    }
}

test "secp256k1 test vectors - doubling" {
    const expected = [_][]const u8{
        "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798",
        "c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5",
        "e493dbf1c10d80f3581e4904930b1404cc6c13900ee0758474fa94abe8c4cd13",
        "2f01e5e15cca351daff3843fb70f3c2f0a1bdd05e5af888a67784ef3e10a2a01",
        "e60fce93b59e9ec53011aabc21c23e97b2a31369b87a5ae9c44ee89e2a6dec0a",
    };
    var p = Secp256k1.basePoint;
    for (expected) |xh| {
        const x = p.affineCoordinates().x;
        p = p.dbl();
        var xs: [32]u8 = undefined;
        _ = try fmt.hexToBytes(&xs, xh);
        try testing.expectEqualSlices(u8, &x.toBytes(.big), &xs);
    }
}

test "secp256k1 compressed sec1 encoding/decoding" {
    const p = Secp256k1.random();
    const s = p.toCompressedSec1();
    const q = try Secp256k1.fromSec1(&s);
    try testing.expect(p.equivalent(q));
}

test "secp256k1 uncompressed sec1 encoding/decoding" {
    const p = Secp256k1.random();
    const s = p.toUncompressedSec1();
    const q = try Secp256k1.fromSec1(&s);
    try testing.expect(p.equivalent(q));
}

test "secp256k1 public key is the neutral element" {
    const n = Secp256k1.scalar.Scalar.zero.toBytes(.little);
    const p = Secp256k1.random();
    try testing.expectError(error.IdentityElement, p.mul(n, .little));
}

test "secp256k1 public key is the neutral element (public verification)" {
    const n = Secp256k1.scalar.Scalar.zero.toBytes(.little);
    const p = Secp256k1.random();
    try testing.expectError(error.IdentityElement, p.mulPublic(n, .little));
}

test "secp256k1 field element non-canonical encoding" {
    const s = [_]u8{0xff} ** 32;
    try testing.expectError(error.NonCanonical, Secp256k1.Fe.fromBytes(s, .little));
}

test "secp256k1 neutral element decoding" {
    try testing.expectError(error.InvalidEncoding, Secp256k1.fromAffineCoordinates(.{ .x = Secp256k1.Fe.zero, .y = Secp256k1.Fe.zero }));
    const p = try Secp256k1.fromAffineCoordinates(.{ .x = Secp256k1.Fe.zero, .y = Secp256k1.Fe.one });
    try testing.expectError(error.IdentityElement, p.rejectIdentity());
}

test "secp256k1 double base multiplication" {
    const p1 = Secp256k1.basePoint;
    const p2 = Secp256k1.basePoint.dbl();
    const s1 = [_]u8{0x01} ** 32;
    const s2 = [_]u8{0x02} ** 32;
    const pr1 = try Secp256k1.mulDoubleBasePublic(p1, s1, p2, s2, .little);
    const pr2 = (try p1.mul(s1, .little)).add(try p2.mul(s2, .little));
    try testing.expect(pr1.equivalent(pr2));
}

test "secp256k1 scalar inverse" {
    const expected = "08d0684a0fe8ea978b68a29e4b4ffdbd19eeb59db25301cf23ecbe568e1f9822";
    var out: [32]u8 = undefined;
    _ = try std.fmt.hexToBytes(&out, expected);

    const scalar = try Secp256k1.scalar.Scalar.fromBytes(.{
        0x94, 0xa1, 0xbb, 0xb1, 0x4b, 0x90, 0x6a, 0x61, 0xa2, 0x80, 0xf2, 0x45, 0xf9, 0xe9, 0x3c, 0x7f,
        0x3b, 0x4a, 0x62, 0x47, 0x82, 0x4f, 0x5d, 0x33, 0xb9, 0x67, 0x07, 0x87, 0x64, 0x2a, 0x68, 0xde,
    }, .big);
    const inverse = scalar.invert();
    try std.testing.expectEqualSlices(u8, &out, &inverse.toBytes(.big));
}

test "secp256k1 scalar parity" {
    try std.testing.expect(Secp256k1.scalar.Scalar.zero.isOdd() == false);
    try std.testing.expect(Secp256k1.scalar.Scalar.one.isOdd());
    try std.testing.expect(Secp256k1.scalar.Scalar.one.dbl().isOdd() == false);
}
