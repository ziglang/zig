// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std");
const fmt = std.fmt;
const testing = std.testing;

const P256 = @import("p256.zig").P256;

test "p256 ECDH key exchange" {
    const dha = P256.scalar.random(.Little);
    const dhb = P256.scalar.random(.Little);
    const dhA = try P256.basePoint.mul(dha, .Little);
    const dhB = try P256.basePoint.mul(dhb, .Little);
    const shareda = try dhA.mul(dhb, .Little);
    const sharedb = try dhB.mul(dha, .Little);
    try testing.expect(shareda.equivalent(sharedb));
}

test "p256 point from affine coordinates" {
    const xh = "6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296";
    const yh = "4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5";
    var xs: [32]u8 = undefined;
    _ = try fmt.hexToBytes(&xs, xh);
    var ys: [32]u8 = undefined;
    _ = try fmt.hexToBytes(&ys, yh);
    var p = try P256.fromSerializedAffineCoordinates(xs, ys, .Big);
    try testing.expect(p.equivalent(P256.basePoint));
}

test "p256 test vectors" {
    const expected = [_][]const u8{
        "0000000000000000000000000000000000000000000000000000000000000000",
        "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296",
        "7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978",
        "5ecbe4d1a6330a44c8f7ef951d4bf165e6c6b721efada985fb41661bc6e7fd6c",
        "e2534a3532d08fbba02dde659ee62bd0031fe2db785596ef509302446b030852",
        "51590b7a515140d2d784c85608668fdfef8c82fd1f5be52421554a0dc3d033ed",
        "b01a172a76a4602c92d3242cb897dde3024c740debb215b4c6b0aae93c2291a9",
        "8e533b6fa0bf7b4625bb30667c01fb607ef9f8b8a80fef5b300628703187b2a3",
        "62d9779dbee9b0534042742d3ab54cadc1d238980fce97dbb4dd9dc1db6fb393",
        "ea68d7b6fedf0b71878938d51d71f8729e0acb8c2c6df8b3d79e8a4b90949ee0",
    };
    var p = P256.identityElement;
    for (expected) |xh| {
        const x = p.affineCoordinates().x;
        p = p.add(P256.basePoint);
        var xs: [32]u8 = undefined;
        _ = try fmt.hexToBytes(&xs, xh);
        try testing.expectEqualSlices(u8, &x.toBytes(.Big), &xs);
    }
}

test "p256 test vectors - doubling" {
    const expected = [_][]const u8{
        "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296",
        "7cf27b188d034f7e8a52380304b51ac3c08969e277f21b35a60b48fc47669978",
        "e2534a3532d08fbba02dde659ee62bd0031fe2db785596ef509302446b030852",
        "62d9779dbee9b0534042742d3ab54cadc1d238980fce97dbb4dd9dc1db6fb393",
    };
    var p = P256.basePoint;
    for (expected) |xh| {
        const x = p.affineCoordinates().x;
        p = p.dbl();
        var xs: [32]u8 = undefined;
        _ = try fmt.hexToBytes(&xs, xh);
        try testing.expectEqualSlices(u8, &x.toBytes(.Big), &xs);
    }
}

test "p256 compressed sec1 encoding/decoding" {
    const p = P256.random();
    const s = p.toCompressedSec1();
    const q = try P256.fromSec1(&s);
    try testing.expect(p.equivalent(q));
}

test "p256 uncompressed sec1 encoding/decoding" {
    const p = P256.random();
    const s = p.toUncompressedSec1();
    const q = try P256.fromSec1(&s);
    try testing.expect(p.equivalent(q));
}

test "p256 public key is the neutral element" {
    const n = P256.scalar.Scalar.zero.toBytes(.Little);
    const p = P256.random();
    try testing.expectError(error.IdentityElement, p.mul(n, .Little));
}

test "p256 public key is the neutral element (public verification)" {
    const n = P256.scalar.Scalar.zero.toBytes(.Little);
    const p = P256.random();
    try testing.expectError(error.IdentityElement, p.mulPublic(n, .Little));
}

test "p256 field element non-canonical encoding" {
    const s = [_]u8{0xff} ** 32;
    try testing.expectError(error.NonCanonical, P256.Fe.fromBytes(s, .Little));
}

test "p256 neutral element decoding" {
    try testing.expectError(error.InvalidEncoding, P256.fromAffineCoordinates(.{ .x = P256.Fe.zero, .y = P256.Fe.zero }));
    const p = try P256.fromAffineCoordinates(.{ .x = P256.Fe.zero, .y = P256.Fe.one });
    try testing.expectError(error.IdentityElement, p.rejectIdentity());
}

test "p256 double base multiplication" {
    const p1 = P256.basePoint;
    const p2 = P256.basePoint.dbl();
    const s1 = [_]u8{0x01} ** 32;
    const s2 = [_]u8{0x02} ** 32;
    const pr1 = try P256.mulDoubleBasePublic(p1, s1, p2, s2, .Little);
    const pr2 = (try p1.mul(s1, .Little)).add(try p2.mul(s2, .Little));
    try testing.expect(pr1.equivalent(pr2));
}
