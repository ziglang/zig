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
const meta = std.meta;

const phc = @import("phc_encoding.zig");

/// Algorithm for PhcEncoding
pub const phc_alg_id = "scrypt";

const HmacSha256 = crypto.auth.hmac.sha2.HmacSha256;
const max_size = math.maxInt(usize);
const max_int = max_size >> 1;
const PhcParser = phc.Parser(Params);
const PhcHasher = phc.Hasher(PhcParser, Params, kdf, phc_alg_id, 32, 32);

const ScryptError = error{
    InvalidParams,
    InvalidDerivedKeyLen,
};

pub const Error = ScryptError || mem.Allocator.Error;

pub const CryptHasherError = error{
    ParseError,
    InvalidAlgorithm,
    VerificationError,
};

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

fn blockMix(tmp: *align(16) [16]u32, in: []align(16) const u32, out: []align(16) u32, r: u30) void {
    blockCopy(tmp, in[(2 * r - 1) * 16 ..], 1);
    var i: usize = 0;
    while (i < 2 * r) : (i += 2) {
        salsaXor(tmp, in[i * 16 ..], out[i * 8 ..]);
        salsaXor(tmp, in[i * 16 + 16 ..], out[i * 8 + r * 16 ..]);
    }
}

fn integerify(b: []align(16) const u32, r: u30) u64 {
    const j = (2 * r - 1) * 16;
    return @as(u64, b[j]) | @as(u64, b[j + 1]) << 32;
}

fn smix(b: []align(16) u8, r: u30, n: usize, v: []align(16) u32, xy: []align(16) u32) void {
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
        // 32bit downcast
        var j = @intCast(usize, integerify(x, r) & (n - 1));
        blockXor(x, v[j * (32 * r) ..], 2 * r);
        blockMix(&tmp, x, y, r);

        // 32bit downcast
        j = @intCast(usize, integerify(y, r) & (n - 1));
        blockXor(y, v[j * (32 * r) ..], 2 * r);
        blockMix(&tmp, y, x, r);
    }

    for (x) |v1, j| {
        mem.writeIntLittle(u32, b[4 * j ..][0..4], v1);
    }
}

pub const Params = struct {
    const Self = @This();

    log_n: u6,
    r: u30,
    p: u30,

    /// Baseline parameters for interactive logins
    pub const interactive = Self.fromLimits(524288, 16777216);

    /// Baseline parameters for offline usage
    pub const sensitive = Self.fromLimits(33554432, 1073741824);

    /// Create Params from ops and mem limits
    pub fn fromLimits(ops_limit: u64, mem_limit: usize) Self {
        const ops = math.max(32768, ops_limit);
        const r: u30 = 8;
        if (ops < mem_limit / 32) {
            const max_n = ops / (r * 4);
            return Self{ .r = r, .p = 1, .log_n = @intCast(u6, math.log2(max_n)) };
        } else {
            const max_n = mem_limit / (@intCast(usize, r) * 128);
            const log_n = @intCast(u6, math.log2(max_n));
            const max_rp = math.min(0x3fffffff, (ops / 4) / (@as(u64, 1) << log_n));
            return Self{ .r = r, .p = @intCast(u30, max_rp / @as(u64, r)), .log_n = log_n };
        }
    }

    /// Public interface for PhcEncoding
    pub fn fromPhcEncoding(it: *phc.ParamsIterator) phc.Error!Self {
        var ln: ?u6 = null;
        var r: ?u30 = null;
        var p: ?u30 = null;
        while (try it.next()) |param| {
            if (mem.eql(u8, param.key, "ln")) {
                ln = try param.decimal(u6);
            } else if (mem.eql(u8, param.key, "r")) {
                r = try param.decimal(u30);
            } else if (mem.eql(u8, param.key, "p")) {
                p = try param.decimal(u30);
            } else {
                return error.ParseError;
            }
        }
        return Self{
            .log_n = ln orelse return error.ParseError,
            .r = r orelse return error.ParseError,
            .p = p orelse return error.ParseError,
        };
    }

    /// Public interface for PhcEncoding
    pub fn toPhcEncoding(
        self: Self,
        allocator: *mem.Allocator,
        out: []?phc.Param,
    ) mem.Allocator.Error!void {
        const ln = try fmt.allocPrint(allocator, "{d}", .{self.log_n});
        errdefer allocator.free(ln);
        const r = try fmt.allocPrint(allocator, "{d}", .{self.r});
        errdefer allocator.free(r);
        const p = try fmt.allocPrint(allocator, "{d}", .{self.p});
        out[0] = phc.Param.new("ln", ln);
        out[1] = phc.Param.new("r", r);
        out[2] = phc.Param.new("p", p);
    }
};

/// Apply SCRYPT to generate a key from a password.
///
/// SCRYPT is defined in RFC 7914.
///
/// allocator: *mem.Allocator.
///
/// derived_key: Slice of appropriate size for generated key. Generally 16 or 32 bytes in length.
///              May be uninitialized. All bytes will be overwritten.
///              Maximum size is `derived_key.len / 32 == 0xffff_ffff`.
///
/// password: Arbitrary sequence of bytes of any length.
///
/// salt: Arbitrary sequence of bytes of any length.
///
/// params: Params.
pub fn kdf(
    allocator: *mem.Allocator,
    derived_key: []u8,
    password: []const u8,
    salt: []const u8,
    params: Params,
) !void {
    if (derived_key.len == 0 or derived_key.len / 32 > 0xffff_ffff) {
        return Error.InvalidDerivedKeyLen;
    }
    if (params.log_n == 0 or params.r == 0 or params.p == 0) {
        return Error.InvalidParams;
    }
    // 32bit check
    const n64 = @as(u64, 1) << params.log_n;
    if (n64 > max_size) {
        return Error.InvalidParams;
    }
    const n = @intCast(usize, n64);
    if (@as(u64, params.r) * @as(u64, params.p) >= 1 << 30 or
        params.r > max_int / 128 / @as(u64, params.p) or
        params.r > max_int / 256 or
        n > max_int / 128 / @as(u64, params.r))
    {
        return Error.InvalidParams;
    }

    var xy = try allocator.alignedAlloc(u32, 16, 64 * params.r);
    defer allocator.free(xy);
    var v = try allocator.alignedAlloc(u32, 16, 32 * n * params.r);
    defer allocator.free(v);
    var dk = try allocator.alignedAlloc(u8, 16, params.p * 128 * params.r);
    defer allocator.free(dk);

    try crypto.pwhash.pbkdf2(dk, password, salt, 1, HmacSha256);
    var i: u32 = 0;
    while (i < params.p) : (i += 1) {
        smix(dk[i * 128 * params.r ..], params.r, n, v, xy);
    }
    try crypto.pwhash.pbkdf2(derived_key, password, dk, 1, HmacSha256);
}

fn CustomB64Codec(comptime map: [64]u8) type {
    return struct {
        const map64 = map;

        fn encodedLen(len: usize) usize {
            return (len * 4 + 2) / 3;
        }

        fn decodedLen(len: usize) usize {
            return len / 4 * 3 + (len % 4) * 3 / 4;
        }

        fn intEncode(dst: []u8, src: anytype) void {
            var n = src;
            for (dst) |*x, i| {
                x.* = map64[@truncate(u6, n)];
                n = math.shr(@TypeOf(src), n, 6);
            }
        }

        fn intDecode(comptime T: type, src: *const [(meta.bitCount(T) + 5) / 6]u8) CryptHasherError!T {
            var v: T = 0;
            for (src) |x, i| {
                const vi = mem.indexOfScalar(u8, &map64, x) orelse return error.ParseError;
                v |= @intCast(T, vi) << @intCast(math.Log2Int(T), i * 6);
            }
            return v;
        }

        fn sliceEncode(comptime len: usize, dst: *[encodedLen(len)]u8, src: *const [len]u8) void {
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

        fn sliceDecode(comptime len: usize, dst: *[decodedLen(len)]u8, src: *const [len]u8) !void {
            var i: usize = 0;
            while (i < src.len / 4) : (i += 1) {
                mem.writeIntSliceLittle(u24, dst[i * 3 ..], try intDecode(u24, src[i * 4 ..][0..4]));
            }
            const leftover = src[i * 4 ..];
            var v: u24 = 0;
            for (leftover) |_, j| {
                v |= @as(u24, try intDecode(u6, leftover[j..][0..1])) << @intCast(u5, j * 6);
            }
            for (dst[i * 3 ..]) |*x, j| {
                x.* = @truncate(u8, v >> @intCast(u5, j * 8));
            }
        }
    };
}

// https://en.wikipedia.org/wiki/Crypt_(C)
// https://gitlab.com/jas/scrypt-unix-crypt/blob/master/unix-scrypt.txt
pub const CryptHasher = struct {
    const Codec = CustomB64Codec("./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".*);
    const prefix = "$7$";

    fn parseParams(encoded: *const [14]u8) CryptHasherError!Params {
        if (!mem.eql(u8, prefix, encoded[0..3])) {
            return error.InvalidAlgorithm;
        }
        return Params{
            .log_n = try Codec.intDecode(u6, encoded[3..4]),
            .r = try Codec.intDecode(u30, encoded[4..9]),
            .p = try Codec.intDecode(u30, encoded[9..14]),
        };
    }

    /// Verify password against crypt encoded string
    pub fn verify(allocator: *mem.Allocator, str: []const u8, password: []const u8) !void {
        if (str.len < 58) {
            return error.ParseError;
        }
        const params = try parseParams(str[0..14]);
        var salt = str[14..];
        salt = salt[0 .. mem.indexOfScalar(u8, salt, '$') orelse return error.ParseError];
        const str_dk = str[14 + salt.len + 1 ..];
        if (str_dk.len < 43) {
            return error.ParseError;
        }
        const expected_encoded_dk = str_dk[0..43];

        var dk: [32]u8 = undefined;
        try kdf(allocator, &dk, password, salt, params);

        var encoded_dk: [Codec.encodedLen(dk.len)]u8 = undefined;
        Codec.sliceEncode(32, &encoded_dk, &dk);

        const passed = crypto.utils.timingSafeEql([43]u8, encoded_dk[0..].*, expected_encoded_dk[0..].*);
        crypto.utils.secureZero(u8, &encoded_dk);
        if (!passed) {
            return CryptHasherError.VerificationError;
        }
    }

    /// Length (in bytes) of a password hash
    pub const pwhash_str_length: usize = 101;

    /// Derive key from password and return crypt encoded string
    pub fn create(
        allocator: *mem.Allocator,
        password: []const u8,
        params: Params,
    ) ![pwhash_str_length]u8 {
        var salt_bin: [32]u8 = undefined;
        crypto.random.bytes(&salt_bin);
        var salt: [Codec.encodedLen(salt_bin.len)]u8 = undefined;
        Codec.sliceEncode(32, &salt, &salt_bin);

        var dk: [32]u8 = undefined;
        try kdf(allocator, &dk, password, &salt, params);

        var encoded_dk: [Codec.encodedLen(dk.len)]u8 = undefined;
        Codec.sliceEncode(32, &encoded_dk, &dk);

        var buf: [pwhash_str_length]u8 = undefined;
        mem.copy(u8, buf[0..3], prefix);
        Codec.intEncode(buf[3..4], params.log_n);
        Codec.intEncode(buf[4..9], params.r);
        Codec.intEncode(buf[9..14], params.p);
        mem.copy(u8, buf[14..57], salt[0..]);
        buf[57] = '$';
        mem.copy(u8, buf[58..], encoded_dk[0..]);
        return buf;
    }
};

pub const Options = struct {
    kdf_params: Params,
    encoding: crypto.pwhash.Encoding,
};

/// Compute a hash of a password using the scrypt key derivation function.
/// The function returns a string that includes all the parameters required for verification.
///
/// You have to free result after use.
pub fn strHash(allocator: *mem.Allocator, password: []const u8, options: Options) ![]u8 {
    switch (options.encoding) {
        .phc => return PhcHasher.create(allocator, password, options.kdf_params),
        .crypt => {
            const s = try CryptHasher.create(allocator, password, options.kdf_params);
            return allocator.dupe(u8, &s);
        },
    }
}

/// Verify that a previously computed hash is valid for a given password.
pub fn strVerify(
    allocator: *mem.Allocator,
    str: []const u8,
    password: []const u8,
) !void {
    if (mem.startsWith(u8, str, CryptHasher.prefix)) {
        return CryptHasher.verify(allocator, str, password);
    } else {
        return PhcHasher.verify(allocator, str, password);
    }
}

test "kdf" {
    const password = "testpass";
    const salt = "saltsalt";

    var v: [32]u8 = undefined;
    try kdf(std.testing.allocator, &v, password, salt, Params{ .log_n = 15, .r = 8, .p = 1 });

    const hex = "1e0f97c3f6609024022fbe698da29c2fe53ef1087a8e396dc6d5d2a041e886de";
    var bytes: [hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytes, hex);

    std.testing.expectEqualSlices(u8, &bytes, &v);
}

test "kdf rfc 1" {
    const password = "";
    const salt = "";

    var v: [64]u8 = undefined;
    try kdf(std.testing.allocator, &v, password, salt, Params{ .log_n = 4, .r = 1, .p = 1 });

    const hex = "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906";
    var bytes: [hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytes, hex);

    std.testing.expectEqualSlices(u8, &bytes, &v);
}

test "kdf rfc 2" {
    const password = "password";
    const salt = "NaCl";

    var v: [64]u8 = undefined;
    try kdf(std.testing.allocator, &v, password, salt, Params{ .log_n = 10, .r = 8, .p = 16 });

    const hex = "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b3731622eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640";
    var bytes: [hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytes, hex);

    std.testing.expectEqualSlices(u8, &bytes, &v);
}

test "kdf rfc 3" {
    const password = "pleaseletmein";
    const salt = "SodiumChloride";

    var v: [64]u8 = undefined;
    try kdf(std.testing.allocator, &v, password, salt, Params{ .log_n = 14, .r = 8, .p = 1 });

    const hex = "7023bdcb3afd7348461c06cd81fd38ebfda8fbba904f8e3ea9b543f6545da1f2d5432955613f0fcf62d49705242a9af9e61e85dc0d651e40dfcf017b45575887";
    var bytes: [hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytes, hex);

    std.testing.expectEqualSlices(u8, &bytes, &v);
}

test "kdf rfc 4" {
    // skip slow test
    if (true) {
        return error.SkipZigTest;
    }

    const password = "pleaseletmein";
    const salt = "SodiumChloride";

    var v: [64]u8 = undefined;
    try kdf(std.testing.allocator, &v, password, salt, Params{ .log_n = 20, .r = 8, .p = 1 });

    const hex = "2101cb9b6a511aaeaddbbe09cf70f881ec568d574a2ffd4dabe5ee9820adaa478e56fd8f4ba5d09ffa1c6d927c40f4c337304049e8a952fbcbf45c6fa77a41a4";
    var bytes: [hex.len / 2]u8 = undefined;
    _ = try std.fmt.hexToBytes(&bytes, hex);

    std.testing.expectEqualSlices(u8, &bytes, &v);
}

test "password hashing (crypt format)" {
    const str = "$7$A6....1....TrXs5Zk6s8sWHpQgWDIXTR8kUU3s6Jc3s.DtdS8M2i4$a4ik5hGDN7foMuHOW.cp.CtX01UyCeO0.JAG.AHPpx5";
    const password = "Y0!?iQa9M%5ekffW(`";
    try CryptHasher.verify(std.testing.allocator, str, password);

    const params = Params.interactive;
    const str2 = try CryptHasher.create(std.testing.allocator, password, params);
    try CryptHasher.verify(std.testing.allocator, &str2, password);
}

test "strHash && strVerify" {
    const alloc = std.testing.allocator;
    const password = "testpass";

    const s = try strHash(
        alloc,
        password,
        Options{ .kdf_params = Params.interactive, .encoding = .crypt },
    );
    defer alloc.free(s);
    try strVerify(alloc, s, password);

    const s1 = try strHash(
        alloc,
        password,
        Options{ .kdf_params = Params.interactive, .encoding = .phc },
    );
    defer alloc.free(s1);
    try strVerify(alloc, s1, password);
}

test "unix-scrypt" {
    // https://gitlab.com/jas/scrypt-unix-crypt/blob/master/unix-scrypt.txt
    const str = "$7$C6..../....SodiumChloride$kBGj9fHznVYFQMEn/qDCfrDevf9YDtcDdKvEqHJLV8D";
    const password = "pleaseletmein";

    try strVerify(std.testing.allocator, str, password);
}
