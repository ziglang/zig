// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

// https://tools.ietf.org/html/rfc7914
// https://github.com/golang/crypto/blob/master/scrypt/scrypt.go

const std = @import("std");
const crypto = std.crypto;
const fmt = std.fmt;
const math = std.math;
const mem = std.mem;

const HmacSha256 = crypto.auth.hmac.sha2.HmacSha256;

const phc = @import("../phc_encoding.zig");

const max_int = math.maxInt(u64) >> 1;
pub const phc_alg_id = "scrypt";

fn blockCopy(dst: []align(16) u32, src: []align(16) const u32, n: usize) void {
    mem.copy(u32, dst, src[0 .. n * 16]);
}

fn blockXor(dst: []align(16) u32, src: []align(16) const u32, n: usize) void {
    for (src[0 .. n * 16]) |v, i| {
        dst[i] ^= v;
    }
}

const QuarterRound = struct { a: usize, b: usize, c: usize, d: u6 };

fn Rp(a: usize, b: usize, c: usize, d: u6) QuarterRound {
    return QuarterRound{ .a = a, .b = b, .c = c, .d = d };
}

fn salsa8core(b: *align(16) [16]u32) void {
    const arx_steps = comptime [_]QuarterRound{
        Rp(4, 0, 12, 7),   Rp(8, 4, 0, 9),    Rp(12, 8, 4, 13),   Rp(0, 12, 8, 18),
        Rp(9, 5, 1, 7),    Rp(13, 9, 5, 9),   Rp(1, 13, 9, 13),   Rp(5, 1, 13, 18),
        Rp(14, 10, 6, 7),  Rp(2, 14, 10, 9),  Rp(6, 2, 14, 13),   Rp(10, 6, 2, 18),
        Rp(3, 15, 11, 7),  Rp(7, 3, 15, 9),   Rp(11, 7, 3, 13),   Rp(15, 11, 7, 18),
        Rp(1, 0, 3, 7),    Rp(2, 1, 0, 9),    Rp(3, 2, 1, 13),    Rp(0, 3, 2, 18),
        Rp(6, 5, 4, 7),    Rp(7, 6, 5, 9),    Rp(4, 7, 6, 13),    Rp(5, 4, 7, 18),
        Rp(11, 10, 9, 7),  Rp(8, 11, 10, 9),  Rp(9, 8, 11, 13),   Rp(10, 9, 8, 18),
        Rp(12, 15, 14, 7), Rp(13, 12, 15, 9), Rp(14, 13, 12, 13), Rp(15, 14, 13, 18),
    };
    var x = b.*;
    var j: usize = 0;
    while (j < 8) : (j += 2) {
        inline for (arx_steps) |r| {
            x[r.a] ^= math.rotl(u32, x[r.b] +% x[r.c], r.d);
        }
    }
    j = 0;
    while (j < 16) : (j += 1) {
        b[j] +%= x[j];
    }
}

fn salsaXor(tmp: *align(16) [16]u32, in: []align(16) const u32, out: []align(16) u32) void {
    blockXor(tmp, in, 1);
    salsa8core(tmp);
    blockCopy(out, tmp, 1);
}

fn blockMix(tmp: *align(16) [16]u32, in: []align(16) const u32, out: []align(16) u32, r: u32) void {
    blockCopy(tmp, in[(2 * r - 1) * 16 ..], 1);
    var i: usize = 0;
    while (i < 2 * r) : (i += 2) {
        salsaXor(tmp, in[i * 16 ..], out[i * 8 ..]);
        salsaXor(tmp, in[i * 16 + 16 ..], out[i * 8 + r * 16 ..]);
    }
}

fn integerify(b: []align(16) const u32, r: u32) u64 {
    const j = (2 * r - 1) * 16;
    return @as(u64, b[j]) | @as(u64, b[j + 1]) << 32;
}

fn smix(b: []align(16) u8, r: u32, n: usize, v: []align(16) u32, xy: []align(16) u32) void {
    var x = xy[0 .. 32 * r];
    var y = xy[32 * r ..];

    for (x) |*v1, j| {
        v1.* = mem.readIntSliceLittle(u32, b[4 * j ..]);
    }

    var tmp: [16]u32 align(16) = undefined;
    var i: usize = 0;
    while (i < n) : (i += 2) {
        blockCopy(v[i * (32 * r) ..], x, 2 * r);
        blockMix(&tmp, x, y, r);

        blockCopy(v[(i + 1) * (32 * r) ..], y, 2 * r);
        blockMix(&tmp, y, x, r);
    }

    i = 0;
    while (i < n) : (i += 2) {
        var j = integerify(x, r) & (n - 1);
        blockXor(x, v[j * (32 * r) ..], 2 * r);
        blockMix(&tmp, x, y, r);

        j = integerify(y, r) & (n - 1);
        blockXor(y, v[j * (32 * r) ..], 2 * r);
        blockMix(&tmp, y, x, r);
    }

    for (x) |v1, j| {
        mem.writeIntLittle(u32, b[4 * j ..][0..4], v1);
    }
}

const Error1 = error{
    InvalidParams,
    InvalidDerivedKeyLen,
};

// +Pbkdf2Error
pub const Error = Error1 || mem.Allocator.Error;

pub const Params = struct {
    const Self = @This();

    log_n: u6 = 15,
    r: u32 = 8,
    p: u32 = 1,

    pub fn init(log_n: u6, r: u32, p: u32) Self {
        return Self{ .log_n = log_n, .r = r, .p = p };
    }

    pub fn fromLimits(ops_limit: u64, mem_limit: usize) Self {
        const ops = math.max(32768, ops_limit);
        const r: u32 = 8;
        if (ops < mem_limit / 32) {
            const max_n = ops / (r * 4);
            return Self{ .r = r, .p = 1, .log_n = @intCast(u6, math.log2(max_n)) };
        } else {
            const max_n = mem_limit / (@intCast(usize, r) * 128);
            const log_n = @intCast(u6, math.log2(max_n));
            const max_rp = math.min(0x3fffffff, (ops / 4) / (@as(u64, 1) << log_n));
            return Self{ .r = r, .p = @intCast(u32, max_rp / @as(u64, r)), .log_n = log_n };
        }
    }

    pub fn fromPhcString(s: []const u8) phc.Error!Self {
        var res = Self{};
        var it = phc.ParamsIterator.init(s, 3);
        while (try it.next()) |param| {
            if (mem.eql(u8, param.key, "ln")) {
                res.log_n = try param.decimal(u6);
            } else if (mem.eql(u8, param.key, "r")) {
                res.r = try param.decimal(u32);
            } else if (mem.eql(u8, param.key, "p")) {
                res.p = try param.decimal(u32);
            } else {
                return error.ParseError;
            }
        }
        return res;
    }

    pub fn toPhcString(self: Self, allocator: *mem.Allocator) mem.Allocator.Error![]const u8 {
        const buf = try fmt.allocPrint(
            allocator,
            "ln={d},r={d},p={d}",
            .{ self.log_n, self.r, self.p },
        );
        return buf;
    }
};

// TODO return Error

/// Apply SCRYPT to generate a key from a password.
///
/// SCRYPT is defined in RFC 7914.
///
/// allocator: *mem.Allocator.
///
/// derived_key: Slice of appropriate size for generated key. Generally 16 or 32 bytes in length.
///              May be uninitialized. All bytes will be overwritten.
///              Maximum size is `derived_key.len / 32 == 0xffff_ffff`.
///              It is a programming error to pass buffer longer than the maximum size.
///
/// password: Arbitrary sequence of bytes of any length.
///
/// salt: Arbitrary sequence of bytes of any length.
///
/// params: Optional Params. Defaults may change in future.
pub fn kdf(
    allocator: *mem.Allocator,
    derived_key: []u8,
    password: []const u8,
    salt: []const u8,
    params: ?Params,
) !void {
    if (derived_key.len == 0 or derived_key.len / 32 > 0xffff_ffff) {
        return error.InvalidDerivedKeyLen;
    }
    const param = params orelse Params{};
    const n = @as(usize, 1) << param.log_n;
    if (n <= 1 or n & (n - 1) != 0) {
        return error.InvalidParams;
    }
    if (@as(u64, param.r) * @as(u64, param.p) >= 1 << 30 or
        param.r > max_int / 128 / @as(u64, param.p) or
        param.r > max_int / 256 or
        n > max_int / 128 / @as(u64, param.r))
    {
        return error.InvalidParams;
    }

    var xy = try allocator.alignedAlloc(u32, 16, 64 * param.r);
    defer allocator.free(xy);
    var v = try allocator.alignedAlloc(u32, 16, 32 * n * param.r);
    defer allocator.free(v);
    var dk = try allocator.alignedAlloc(u8, 16, param.p * 128 * param.r);
    defer allocator.free(dk);

    try crypto.pwhash.pbkdf2(dk, password, salt, 1, HmacSha256);
    var i: u32 = 0;
    while (i < param.p) : (i += 1) {
        smix(dk[i * 128 * param.r ..], param.r, n, v, xy);
    }
    try crypto.pwhash.pbkdf2(derived_key, password, dk, 1, HmacSha256);
}

test "kdf" {
    const password = "testpass";
    const salt = "saltsalt";

    var v: [32]u8 = undefined;
    try kdf(std.testing.allocator, &v, password, salt, null);

    const hex = "1e0f97c3f6609024022fbe698da29c2fe53ef1087a8e396dc6d5d2a041e886de";
    var bytes: [hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytes, hex);
    std.testing.expectEqualSlices(u8, &bytes, &v);
}
