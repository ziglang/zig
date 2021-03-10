// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

const std = @import("std");
const crypto = std.crypto;
const math = std.math;
const meta = std.meta;
const mem = std.mem;

const scrypt = @import("scrypt.zig");

pub const Error = error{
    ParseError,
    InvalidAlgorithm,
};

pub const McfEncoding = struct {
    const Self = @This();
    const map64 = "./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

    fn encodedLen(comptime len: usize) usize {
        return (len * 4 + 2) / 3;
    }

    fn intEncode(dst: []u8, src: anytype) void {
        var n = src;
        for (dst) |*x, i| {
            x.* = map64[@truncate(u6, n)];
            n = math.shr(@TypeOf(src), n, 6);
        }
    }

    fn sliceEncode(comptime len: usize, dst: *[encodedLen(len)]u8, src: [len]u8) void {
        var i: usize = 0;
        while (i < src.len / 3) : (i += 1) {
            intEncode(dst[i * 4 ..][0..4], mem.readIntSliceLittle(u24, src[i * 3 ..]));
        }
        const leftover = src[i * 3 ..];
        var v: u24 = 0;
        for (leftover) |x, j| {
            v |= @as(u24, x) << @intCast(u5, j * 8);
        }
        intEncode(dst[i * 4 ..], v);
    }

    fn intDecode(comptime T: type, src: *const [(meta.bitCount(T) + 5) / 6]u8) !T {
        var v: T = 0;
        for (src) |x, i| {
            const vi = mem.indexOfScalar(u8, map64, x) orelse return Error.ParseError;
            v |= @intCast(T, vi) << @intCast(math.Log2Int(T), i * 6);
        }
        return v;
    }

    fn parseParams(encoded: *const [14]u8) !scrypt.Params {
        if (!mem.eql(u8, "$7$", encoded[0..3])) {
            return Error.InvalidAlgorithm;
        }
        return scrypt.Params{
            .log_n = try intDecode(u6, encoded[3..4]),
            .r = @as(u32, try intDecode(u30, encoded[4..9])),
            .p = @as(u32, try intDecode(u30, encoded[9..14])),
        };
    }

    pub fn verify(allocator: *mem.Allocator, str: []const u8, password: []const u8) !void {
        if (str.len < 58) {
            return Error.ParseError;
        }
        const params = try Self.parseParams(str[0..14]);
        var salt = str[14..];
        salt = salt[0 .. mem.indexOfScalar(u8, salt, '$') orelse return Error.ParseError];

        var dk: [32]u8 = undefined;
        try scrypt.kdf(allocator, &dk, password, salt, params);

        var encoded_dk: [encodedLen(dk.len)]u8 = undefined;
        const expected_encoded_dk = str[14 + salt.len + 1 ..][0..43];
        Self.sliceEncode(32, &encoded_dk, dk);
        const passed = crypto.utils.timingSafeEql([43]u8, encoded_dk, expected_encoded_dk.*);
        crypto.utils.secureZero(u8, &encoded_dk);
        if (!passed) {
            return error.VerificationError;
        }
    }

    pub const pwhash_str_length: usize = 101;

    pub fn create(
        allocator: *mem.Allocator,
        params: scrypt.Params,
        password: []const u8,
    ) ![pwhash_str_length]u8 {
        var salt_bin: [32]u8 = undefined;
        crypto.random.bytes(&salt_bin);
        var salt: [encodedLen(salt_bin.len)]u8 = undefined;
        Self.sliceEncode(32, &salt, salt_bin);

        var dk: [32]u8 = undefined;
        try scrypt.kdf(allocator, &dk, password, &salt, params);

        var encoded_dk: [encodedLen(dk.len)]u8 = undefined;
        Self.sliceEncode(32, &encoded_dk, dk);
        var str: [pwhash_str_length]u8 = undefined;
        mem.copy(u8, str[0..3], "$7$");
        Self.intEncode(str[3..4], params.log_n);
        Self.intEncode(str[4..9], params.r);
        Self.intEncode(str[9..14], params.p);
        mem.copy(u8, str[14..57], &salt);
        str[57] = '$';
        Self.sliceEncode(32, str[58..], dk);
        return str;
    }
};

test "password hashing (crypt format)" {
    const str = "$7$A6....1....TrXs5Zk6s8sWHpQgWDIXTR8kUU3s6Jc3s.DtdS8M2i4$a4ik5hGDN7foMuHOW.cp.CtX01UyCeO0.JAG.AHPpx5";
    const password = "Y0!?iQa9M%5ekffW(`";
    try McfEncoding.verify(std.testing.allocator, str, password);

    const params = scrypt.Params.fromLimits(524288, 16777216);
    const str2 = try McfEncoding.create(std.testing.allocator, params, password);
    try McfEncoding.verify(std.testing.allocator, &str2, password);
}
