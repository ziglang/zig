const std = @import("std");
const fmt = std.fmt;
const testing = std.testing;

const P384 = @import("../p384.zig").P384;

test "p384 ECDH key exchange" {
    const dha = P384.scalar.random(.little);
    const dhb = P384.scalar.random(.little);
    const dhA = try P384.basePoint.mul(dha, .little);
    const dhB = try P384.basePoint.mul(dhb, .little);
    const shareda = try dhA.mul(dhb, .little);
    const sharedb = try dhB.mul(dha, .little);
    try testing.expect(shareda.equivalent(sharedb));
}

test "p384 point from affine coordinates" {
    const xh = "aa87ca22be8b05378eb1c71ef320ad746e1d3b628ba79b9859f741e082542a385502f25dbf55296c3a545e3872760ab7";
    const yh = "3617de4a96262c6f5d9e98bf9292dc29f8f41dbd289a147ce9da3113b5f0b8c00a60b1ce1d7e819d7a431d7c90ea0e5f";
    var xs: [48]u8 = undefined;
    _ = try fmt.hexToBytes(&xs, xh);
    var ys: [48]u8 = undefined;
    _ = try fmt.hexToBytes(&ys, yh);
    var p = try P384.fromSerializedAffineCoordinates(xs, ys, .big);
    try testing.expect(p.equivalent(P384.basePoint));
}

test "p384 test vectors" {
    const expected = [_][]const u8{
        "000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7",
        "08D999057BA3D2D969260045C55B97F089025959A6F434D651D207D19FB96E9E4FE0E86EBE0E64F85B96A9C75295DF61",
        "077A41D4606FFA1464793C7E5FDC7D98CB9D3910202DCD06BEA4F240D3566DA6B408BBAE5026580D02D7E5C70500C831",
        "138251CD52AC9298C1C8AAD977321DEB97E709BD0B4CA0ACA55DC8AD51DCFC9D1589A1597E3A5120E1EFD631C63E1835",
        "11DE24A2C251C777573CAC5EA025E467F208E51DBFF98FC54F6661CBE56583B037882F4A1CA297E60ABCDBC3836D84BC",
        "627BE1ACD064D2B2226FE0D26F2D15D3C33EBCBB7F0F5DA51CBD41F26257383021317D7202FF30E50937F0854E35C5DF",
        "283C1D7365CE4788F29F8EBF234EDFFEAD6FE997FBEA5FFA2D58CC9DFA7B1C508B05526F55B9EBB2040F05B48FB6D0E1",
        "1692778EA596E0BE75114297A6FA383445BF227FBE58190A900C3C73256F11FB5A3258D6F403D5ECE6E9B269D822C87D",
        "8F0A39A4049BCB3EF1BF29B8B025B78F2216F7291E6FD3BAC6CB1EE285FB6E21C388528BFEE2B9535C55E4461079118B",
        "A669C5563BD67EEC678D29D6EF4FDE864F372D90B79B9E88931D5C29291238CCED8E85AB507BF91AA9CB2D13186658FB",
    };
    var p = P384.identityElement;
    for (expected) |xh| {
        const x = p.affineCoordinates().x;
        p = p.add(P384.basePoint);
        var xs: [48]u8 = undefined;
        _ = try fmt.hexToBytes(&xs, xh);
        try testing.expectEqualSlices(u8, &x.toBytes(.big), &xs);
    }
}

test "p384 test vectors - doubling" {
    const expected = [_][]const u8{
        "AA87CA22BE8B05378EB1C71EF320AD746E1D3B628BA79B9859F741E082542A385502F25DBF55296C3A545E3872760AB7",
        "08D999057BA3D2D969260045C55B97F089025959A6F434D651D207D19FB96E9E4FE0E86EBE0E64F85B96A9C75295DF61",
        "138251CD52AC9298C1C8AAD977321DEB97E709BD0B4CA0ACA55DC8AD51DCFC9D1589A1597E3A5120E1EFD631C63E1835",
        "1692778EA596E0BE75114297A6FA383445BF227FBE58190A900C3C73256F11FB5A3258D6F403D5ECE6E9B269D822C87D",
    };
    var p = P384.basePoint;
    for (expected) |xh| {
        const x = p.affineCoordinates().x;
        p = p.dbl();
        var xs: [48]u8 = undefined;
        _ = try fmt.hexToBytes(&xs, xh);
        try testing.expectEqualSlices(u8, &x.toBytes(.big), &xs);
    }
}

test "p384 compressed sec1 encoding/decoding" {
    const p = P384.random();
    const s0 = p.toUncompressedSec1();
    const s = p.toCompressedSec1();
    try testing.expectEqualSlices(u8, s0[1..49], s[1..49]);
    const q = try P384.fromSec1(&s);
    try testing.expect(p.equivalent(q));
}

test "p384 uncompressed sec1 encoding/decoding" {
    const p = P384.random();
    const s = p.toUncompressedSec1();
    const q = try P384.fromSec1(&s);
    try testing.expect(p.equivalent(q));
}

test "p384 public key is the neutral element" {
    const n = P384.scalar.Scalar.zero.toBytes(.little);
    const p = P384.random();
    try testing.expectError(error.IdentityElement, p.mul(n, .little));
}

test "p384 public key is the neutral element (public verification)" {
    const n = P384.scalar.Scalar.zero.toBytes(.little);
    const p = P384.random();
    try testing.expectError(error.IdentityElement, p.mulPublic(n, .little));
}

test "p384 field element non-canonical encoding" {
    const s = [_]u8{0xff} ** 48;
    try testing.expectError(error.NonCanonical, P384.Fe.fromBytes(s, .little));
}

test "p384 neutral element decoding" {
    try testing.expectError(error.InvalidEncoding, P384.fromAffineCoordinates(.{ .x = P384.Fe.zero, .y = P384.Fe.zero }));
    const p = try P384.fromAffineCoordinates(.{ .x = P384.Fe.zero, .y = P384.Fe.one });
    try testing.expectError(error.IdentityElement, p.rejectIdentity());
}

test "p384 double base multiplication" {
    const p1 = P384.basePoint;
    const p2 = P384.basePoint.dbl();
    const s1 = [_]u8{0x01} ** 48;
    const s2 = [_]u8{0x02} ** 48;
    const pr1 = try P384.mulDoubleBasePublic(p1, s1, p2, s2, .little);
    const pr2 = (try p1.mul(s1, .little)).add(try p2.mul(s2, .little));
    try testing.expect(pr1.equivalent(pr2));
}

test "p384 double base multiplication with large scalars" {
    const p1 = P384.basePoint;
    const p2 = P384.basePoint.dbl();
    const s1 = [_]u8{0xee} ** 48;
    const s2 = [_]u8{0xdd} ** 48;
    const pr1 = try P384.mulDoubleBasePublic(p1, s1, p2, s2, .little);
    const pr2 = (try p1.mul(s1, .little)).add(try p2.mul(s2, .little));
    try testing.expect(pr1.equivalent(pr2));
}

test "p384 scalar inverse" {
    const expected = "a3cc705f33b5679a66e76ce66e68055c927c5dba531b2837b18fe86119511091b54d733f26b2e7a0f6fa2e7ea21ca806";
    var out: [48]u8 = undefined;
    _ = try std.fmt.hexToBytes(&out, expected);

    const scalar = try P384.scalar.Scalar.fromBytes(.{
        0x94, 0xa1, 0xbb, 0xb1, 0x4b, 0x90, 0x6a, 0x61, 0xa2, 0x80, 0xf2, 0x45, 0xf9, 0xe9, 0x3c, 0x7f,
        0x3b, 0x4a, 0x62, 0x47, 0x82, 0x4f, 0x5d, 0x33, 0xb9, 0x67, 0x07, 0x87, 0x64, 0x2a, 0x68, 0xde,
        0x38, 0x36, 0xe8, 0x0f, 0xa2, 0x84, 0x6b, 0x4e, 0xf3, 0x9a, 0x02, 0x31, 0x24, 0x41, 0x22, 0xca,
    }, .big);
    const inverse = scalar.invert();
    const inverse2 = inverse.invert();
    try testing.expectEqualSlices(u8, &out, &inverse.toBytes(.big));
    try testing.expect(inverse2.equivalent(scalar));

    const sq = scalar.sq();
    const sqr = try sq.sqrt();
    try testing.expect(sqr.equivalent(scalar));
}

test "p384 scalar parity" {
    try std.testing.expect(P384.scalar.Scalar.zero.isOdd() == false);
    try std.testing.expect(P384.scalar.Scalar.one.isOdd());
    try std.testing.expect(P384.scalar.Scalar.one.dbl().isOdd() == false);
}
