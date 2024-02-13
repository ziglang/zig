// https://tools.ietf.org/html/rfc7914
// https://github.com/golang/crypto/blob/master/scrypt/scrypt.go
// https://github.com/Tarsnap/scrypt

const std = @import("std");
const crypto = std.crypto;
const fmt = std.fmt;
const io = std.io;
const math = std.math;
const mem = std.mem;
const meta = std.meta;
const pwhash = crypto.pwhash;

const phc_format = @import("phc_encoding.zig");

const HmacSha256 = crypto.auth.hmac.sha2.HmacSha256;
const KdfError = pwhash.KdfError;
const HasherError = pwhash.HasherError;
const EncodingError = phc_format.Error;
const Error = pwhash.Error;

const max_size = math.maxInt(usize);
const max_int = max_size >> 1;
const default_salt_len = 32;
const default_hash_len = 32;
const max_salt_len = 64;
const max_hash_len = 64;

fn blockCopy(dst: []align(16) u32, src: []align(16) const u32, n: usize) void {
    @memcpy(dst[0 .. n * 16], src[0 .. n * 16]);
}

fn blockXor(dst: []align(16) u32, src: []align(16) const u32, n: usize) void {
    for (src[0 .. n * 16], 0..) |v, i| {
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
    blockCopy(tmp, @alignCast(in[(2 * r - 1) * 16 ..]), 1);
    var i: usize = 0;
    while (i < 2 * r) : (i += 2) {
        salsaXor(tmp, @alignCast(in[i * 16 ..]), @alignCast(out[i * 8 ..]));
        salsaXor(tmp, @alignCast(in[i * 16 + 16 ..]), @alignCast(out[i * 8 + r * 16 ..]));
    }
}

fn integerify(b: []align(16) const u32, r: u30) u64 {
    const j = (2 * r - 1) * 16;
    return @as(u64, b[j]) | @as(u64, b[j + 1]) << 32;
}

fn smix(b: []align(16) u8, r: u30, n: usize, v: []align(16) u32, xy: []align(16) u32) void {
    const x: []align(16) u32 = @alignCast(xy[0 .. 32 * r]);
    const y: []align(16) u32 = @alignCast(xy[32 * r ..]);

    for (x, 0..) |*v1, j| {
        v1.* = mem.readInt(u32, b[4 * j ..][0..4], .little);
    }

    var tmp: [16]u32 align(16) = undefined;
    var i: usize = 0;
    while (i < n) : (i += 2) {
        blockCopy(@alignCast(v[i * (32 * r) ..]), x, 2 * r);
        blockMix(&tmp, x, y, r);

        blockCopy(@alignCast(v[(i + 1) * (32 * r) ..]), y, 2 * r);
        blockMix(&tmp, y, x, r);
    }

    i = 0;
    while (i < n) : (i += 2) {
        var j = @as(usize, @intCast(integerify(x, r) & (n - 1)));
        blockXor(x, @alignCast(v[j * (32 * r) ..]), 2 * r);
        blockMix(&tmp, x, y, r);

        j = @as(usize, @intCast(integerify(y, r) & (n - 1)));
        blockXor(y, @alignCast(v[j * (32 * r) ..]), 2 * r);
        blockMix(&tmp, y, x, r);
    }

    for (x, 0..) |v1, j| {
        mem.writeInt(u32, b[4 * j ..][0..4], v1, .little);
    }
}

/// Scrypt parameters
pub const Params = struct {
    const Self = @This();

    /// The CPU/Memory cost parameter [ln] is log2(N).
    ln: u6,

    /// The [r]esource usage parameter specifies the block size.
    r: u30,

    /// The [p]arallelization parameter.
    /// A large value of [p] can be used to increase the computational cost of scrypt without
    /// increasing the memory usage.
    p: u30,

    /// Baseline parameters for interactive logins
    pub const interactive = Self.fromLimits(524288, 16777216);

    /// Baseline parameters for offline usage
    pub const sensitive = Self.fromLimits(33554432, 1073741824);

    /// Create parameters from ops and mem limits, where mem_limit given in bytes
    pub fn fromLimits(ops_limit: u64, mem_limit: usize) Self {
        const ops = @max(32768, ops_limit);
        const r: u30 = 8;
        if (ops < mem_limit / 32) {
            const max_n = ops / (r * 4);
            return Self{ .r = r, .p = 1, .ln = @as(u6, @intCast(math.log2(max_n))) };
        } else {
            const max_n = mem_limit / (@as(usize, @intCast(r)) * 128);
            const ln = @as(u6, @intCast(math.log2(max_n)));
            const max_rp = @min(0x3fffffff, (ops / 4) / (@as(u64, 1) << ln));
            return Self{ .r = r, .p = @as(u30, @intCast(max_rp / @as(u64, r))), .ln = ln };
        }
    }
};

/// Apply scrypt to generate a key from a password.
///
/// scrypt is defined in RFC 7914.
///
/// allocator: mem.Allocator.
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
    allocator: mem.Allocator,
    derived_key: []u8,
    password: []const u8,
    salt: []const u8,
    params: Params,
) KdfError!void {
    if (derived_key.len == 0) return KdfError.WeakParameters;
    if (derived_key.len / 32 > 0xffff_ffff) return KdfError.OutputTooLong;
    if (params.ln == 0 or params.r == 0 or params.p == 0) return KdfError.WeakParameters;

    const n64 = @as(u64, 1) << params.ln;
    if (n64 > max_size) return KdfError.WeakParameters;
    const n = @as(usize, @intCast(n64));
    if (@as(u64, params.r) * @as(u64, params.p) >= 1 << 30 or
        params.r > max_int / 128 / @as(u64, params.p) or
        params.r > max_int / 256 or
        n > max_int / 128 / @as(u64, params.r)) return KdfError.WeakParameters;

    const xy = try allocator.alignedAlloc(u32, 16, 64 * params.r);
    defer allocator.free(xy);
    const v = try allocator.alignedAlloc(u32, 16, 32 * n * params.r);
    defer allocator.free(v);
    var dk = try allocator.alignedAlloc(u8, 16, params.p * 128 * params.r);
    defer allocator.free(dk);

    try pwhash.pbkdf2(dk, password, salt, 1, HmacSha256);
    var i: u32 = 0;
    while (i < params.p) : (i += 1) {
        smix(@alignCast(dk[i * 128 * params.r ..]), params.r, n, v, xy);
    }
    try pwhash.pbkdf2(derived_key, password, dk, 1, HmacSha256);
}

const crypt_format = struct {
    /// String prefix for scrypt
    pub const prefix = "$7$";

    /// Standard type for a set of scrypt parameters, with the salt and hash.
    pub fn HashResult(comptime crypt_max_hash_len: usize) type {
        return struct {
            ln: u6,
            r: u30,
            p: u30,
            salt: []const u8,
            hash: BinValue(crypt_max_hash_len),
        };
    }

    const Codec = CustomB64Codec("./0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".*);

    /// A wrapped binary value whose maximum size is `max_len`.
    ///
    /// This type must be used whenever a binary value is encoded in a PHC-formatted string.
    /// This includes `salt`, `hash`, and any other binary parameters such as keys.
    ///
    /// Once initialized, the actual value can be read with the `constSlice()` function.
    pub fn BinValue(comptime max_len: usize) type {
        return struct {
            const Self = @This();
            const capacity = max_len;
            const max_encoded_length = Codec.encodedLen(max_len);

            buf: [max_len]u8 = undefined,
            len: usize = 0,

            /// Wrap an existing byte slice
            pub fn fromSlice(slice: []const u8) EncodingError!Self {
                if (slice.len > capacity) return EncodingError.NoSpaceLeft;
                var bin_value: Self = undefined;
                @memcpy(bin_value.buf[0..slice.len], slice);
                bin_value.len = slice.len;
                return bin_value;
            }

            /// Return the slice containing the actual value.
            pub fn constSlice(self: *const Self) []const u8 {
                return self.buf[0..self.len];
            }

            fn fromB64(self: *Self, str: []const u8) !void {
                const len = Codec.decodedLen(str.len);
                if (len > self.buf.len) return EncodingError.NoSpaceLeft;
                try Codec.decode(self.buf[0..len], str);
                self.len = len;
            }

            fn toB64(self: *const Self, buf: []u8) ![]const u8 {
                const value = self.constSlice();
                const len = Codec.encodedLen(value.len);
                if (len > buf.len) return EncodingError.NoSpaceLeft;
                const encoded = buf[0..len];
                Codec.encode(encoded, value);
                return encoded;
            }
        };
    }

    /// Expand binary data into a salt for the modular crypt format.
    pub fn saltFromBin(comptime len: usize, salt: [len]u8) [Codec.encodedLen(len)]u8 {
        var buf: [Codec.encodedLen(len)]u8 = undefined;
        Codec.encode(&buf, &salt);
        return buf;
    }

    /// Deserialize a string into a structure `T` (matching `HashResult`).
    pub fn deserialize(comptime T: type, str: []const u8) EncodingError!T {
        var out: T = undefined;

        if (str.len < 16) return EncodingError.InvalidEncoding;
        if (!mem.eql(u8, prefix, str[0..3])) return EncodingError.InvalidEncoding;
        out.ln = try Codec.intDecode(u6, str[3..4]);
        out.r = try Codec.intDecode(u30, str[4..9]);
        out.p = try Codec.intDecode(u30, str[9..14]);

        var it = mem.splitScalar(u8, str[14..], '$');

        const salt = it.first();
        if (@hasField(T, "salt")) out.salt = salt;

        const hash_str = it.next() orelse return EncodingError.InvalidEncoding;
        if (@hasField(T, "hash")) try out.hash.fromB64(hash_str);

        return out;
    }

    /// Serialize parameters into a string in modular crypt format.
    pub fn serialize(params: anytype, str: []u8) EncodingError![]const u8 {
        var buf = io.fixedBufferStream(str);
        try serializeTo(params, buf.writer());
        return buf.getWritten();
    }

    /// Compute the number of bytes required to serialize `params`
    pub fn calcSize(params: anytype) usize {
        var buf = io.countingWriter(io.null_writer);
        serializeTo(params, buf.writer()) catch unreachable;
        return @as(usize, @intCast(buf.bytes_written));
    }

    fn serializeTo(params: anytype, out: anytype) !void {
        var header: [14]u8 = undefined;
        header[0..3].* = prefix.*;
        Codec.intEncode(header[3..4], params.ln);
        Codec.intEncode(header[4..9], params.r);
        Codec.intEncode(header[9..14], params.p);
        try out.writeAll(&header);
        try out.writeAll(params.salt);
        try out.writeAll("$");
        var buf: [@TypeOf(params.hash).max_encoded_length]u8 = undefined;
        const hash_str = try params.hash.toB64(&buf);
        try out.writeAll(hash_str);
    }

    /// Custom codec that maps 6 bits into 8 like regular Base64, but uses its own alphabet,
    /// encodes bits in little-endian, and can also encode integers.
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
                for (dst) |*x| {
                    x.* = map64[@as(u6, @truncate(n))];
                    n = math.shr(@TypeOf(src), n, 6);
                }
            }

            fn intDecode(comptime T: type, src: *const [(@bitSizeOf(T) + 5) / 6]u8) !T {
                var v: T = 0;
                for (src, 0..) |x, i| {
                    const vi = mem.indexOfScalar(u8, &map64, x) orelse return EncodingError.InvalidEncoding;
                    v |= @as(T, @intCast(vi)) << @as(math.Log2Int(T), @intCast(i * 6));
                }
                return v;
            }

            fn decode(dst: []u8, src: []const u8) !void {
                std.debug.assert(dst.len == decodedLen(src.len));
                var i: usize = 0;
                while (i < src.len / 4) : (i += 1) {
                    mem.writeInt(u24, dst[i * 3 ..][0..3], try intDecode(u24, src[i * 4 ..][0..4]), .little);
                }
                const leftover = src[i * 4 ..];
                var v: u24 = 0;
                for (leftover, 0..) |_, j| {
                    v |= @as(u24, try intDecode(u6, leftover[j..][0..1])) << @as(u5, @intCast(j * 6));
                }
                for (dst[i * 3 ..], 0..) |*x, j| {
                    x.* = @as(u8, @truncate(v >> @as(u5, @intCast(j * 8))));
                }
            }

            fn encode(dst: []u8, src: []const u8) void {
                std.debug.assert(dst.len == encodedLen(src.len));
                var i: usize = 0;
                while (i < src.len / 3) : (i += 1) {
                    intEncode(dst[i * 4 ..][0..4], mem.readInt(u24, src[i * 3 ..][0..3], .little));
                }
                const leftover = src[i * 3 ..];
                var v: u24 = 0;
                for (leftover, 0..) |x, j| {
                    v |= @as(u24, x) << @as(u5, @intCast(j * 8));
                }
                intEncode(dst[i * 4 ..], v);
            }
        };
    }
};

/// Hash and verify passwords using the PHC format.
const PhcFormatHasher = struct {
    const alg_id = "scrypt";
    const BinValue = phc_format.BinValue;

    const HashResult = struct {
        alg_id: []const u8,
        ln: u6,
        r: u30,
        p: u30,
        salt: BinValue(max_salt_len),
        hash: BinValue(max_hash_len),
    };

    /// Return a non-deterministic hash of the password encoded as a PHC-format string
    pub fn create(
        allocator: mem.Allocator,
        password: []const u8,
        params: Params,
        buf: []u8,
    ) HasherError![]const u8 {
        var salt: [default_salt_len]u8 = undefined;
        crypto.random.bytes(&salt);

        var hash: [default_hash_len]u8 = undefined;
        try kdf(allocator, &hash, password, &salt, params);

        return phc_format.serialize(HashResult{
            .alg_id = alg_id,
            .ln = params.ln,
            .r = params.r,
            .p = params.p,
            .salt = try BinValue(max_salt_len).fromSlice(&salt),
            .hash = try BinValue(max_hash_len).fromSlice(&hash),
        }, buf);
    }

    /// Verify a password against a PHC-format encoded string
    pub fn verify(
        allocator: mem.Allocator,
        str: []const u8,
        password: []const u8,
    ) HasherError!void {
        const hash_result = try phc_format.deserialize(HashResult, str);
        if (!mem.eql(u8, hash_result.alg_id, alg_id)) return HasherError.PasswordVerificationFailed;
        const params = Params{ .ln = hash_result.ln, .r = hash_result.r, .p = hash_result.p };
        const expected_hash = hash_result.hash.constSlice();
        var hash_buf: [max_hash_len]u8 = undefined;
        if (expected_hash.len > hash_buf.len) return HasherError.InvalidEncoding;
        const hash = hash_buf[0..expected_hash.len];
        try kdf(allocator, hash, password, hash_result.salt.constSlice(), params);
        if (!mem.eql(u8, hash, expected_hash)) return HasherError.PasswordVerificationFailed;
    }
};

/// Hash and verify passwords using the modular crypt format.
const CryptFormatHasher = struct {
    const BinValue = crypt_format.BinValue;
    const HashResult = crypt_format.HashResult(max_hash_len);

    /// Length of a string returned by the create() function
    pub const pwhash_str_length: usize = 101;

    /// Return a non-deterministic hash of the password encoded into the modular crypt format
    pub fn create(
        allocator: mem.Allocator,
        password: []const u8,
        params: Params,
        buf: []u8,
    ) HasherError![]const u8 {
        var salt_bin: [default_salt_len]u8 = undefined;
        crypto.random.bytes(&salt_bin);
        const salt = crypt_format.saltFromBin(salt_bin.len, salt_bin);

        var hash: [default_hash_len]u8 = undefined;
        try kdf(allocator, &hash, password, &salt, params);

        return crypt_format.serialize(HashResult{
            .ln = params.ln,
            .r = params.r,
            .p = params.p,
            .salt = &salt,
            .hash = try BinValue(max_hash_len).fromSlice(&hash),
        }, buf);
    }

    /// Verify a password against a string in modular crypt format
    pub fn verify(
        allocator: mem.Allocator,
        str: []const u8,
        password: []const u8,
    ) HasherError!void {
        const hash_result = try crypt_format.deserialize(HashResult, str);
        const params = Params{ .ln = hash_result.ln, .r = hash_result.r, .p = hash_result.p };
        const expected_hash = hash_result.hash.constSlice();
        var hash_buf: [max_hash_len]u8 = undefined;
        if (expected_hash.len > hash_buf.len) return HasherError.InvalidEncoding;
        const hash = hash_buf[0..expected_hash.len];
        try kdf(allocator, hash, password, hash_result.salt, params);
        if (!mem.eql(u8, hash, expected_hash)) return HasherError.PasswordVerificationFailed;
    }
};

/// Options for hashing a password.
///
/// Allocator is required for scrypt.
pub const HashOptions = struct {
    allocator: ?mem.Allocator,
    params: Params,
    encoding: pwhash.Encoding,
};

/// Compute a hash of a password using the scrypt key derivation function.
/// The function returns a string that includes all the parameters required for verification.
pub fn strHash(
    password: []const u8,
    options: HashOptions,
    out: []u8,
) Error![]const u8 {
    const allocator = options.allocator orelse return Error.AllocatorRequired;
    switch (options.encoding) {
        .phc => return PhcFormatHasher.create(allocator, password, options.params, out),
        .crypt => return CryptFormatHasher.create(allocator, password, options.params, out),
    }
}

/// Options for hash verification.
///
/// Allocator is required for scrypt.
pub const VerifyOptions = struct {
    allocator: ?mem.Allocator,
};

/// Verify that a previously computed hash is valid for a given password.
pub fn strVerify(
    str: []const u8,
    password: []const u8,
    options: VerifyOptions,
) Error!void {
    const allocator = options.allocator orelse return Error.AllocatorRequired;
    if (mem.startsWith(u8, str, crypt_format.prefix)) {
        return CryptFormatHasher.verify(allocator, str, password);
    } else {
        return PhcFormatHasher.verify(allocator, str, password);
    }
}

// These tests take way too long to run, so I have disabled them.
const run_long_tests = false;

test "kdf" {
    if (!run_long_tests) return error.SkipZigTest;

    const password = "testpass";
    const salt = "saltsalt";

    var dk: [32]u8 = undefined;
    try kdf(std.testing.allocator, &dk, password, salt, .{ .ln = 15, .r = 8, .p = 1 });

    const hex = "1e0f97c3f6609024022fbe698da29c2fe53ef1087a8e396dc6d5d2a041e886de";
    var bytes: [hex.len / 2]u8 = undefined;
    _ = try fmt.hexToBytes(&bytes, hex);

    try std.testing.expectEqualSlices(u8, &bytes, &dk);
}

test "kdf rfc 1" {
    if (!run_long_tests) return error.SkipZigTest;

    const password = "";
    const salt = "";

    var dk: [64]u8 = undefined;
    try kdf(std.testing.allocator, &dk, password, salt, .{ .ln = 4, .r = 1, .p = 1 });

    const hex = "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906";
    var bytes: [hex.len / 2]u8 = undefined;
    _ = try fmt.hexToBytes(&bytes, hex);

    try std.testing.expectEqualSlices(u8, &bytes, &dk);
}

test "kdf rfc 2" {
    if (!run_long_tests) return error.SkipZigTest;

    const password = "password";
    const salt = "NaCl";

    var dk: [64]u8 = undefined;
    try kdf(std.testing.allocator, &dk, password, salt, .{ .ln = 10, .r = 8, .p = 16 });

    const hex = "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b3731622eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640";
    var bytes: [hex.len / 2]u8 = undefined;
    _ = try fmt.hexToBytes(&bytes, hex);

    try std.testing.expectEqualSlices(u8, &bytes, &dk);
}

test "kdf rfc 3" {
    if (!run_long_tests) return error.SkipZigTest;

    const password = "pleaseletmein";
    const salt = "SodiumChloride";

    var dk: [64]u8 = undefined;
    try kdf(std.testing.allocator, &dk, password, salt, .{ .ln = 14, .r = 8, .p = 1 });

    const hex = "7023bdcb3afd7348461c06cd81fd38ebfda8fbba904f8e3ea9b543f6545da1f2d5432955613f0fcf62d49705242a9af9e61e85dc0d651e40dfcf017b45575887";
    var bytes: [hex.len / 2]u8 = undefined;
    _ = try fmt.hexToBytes(&bytes, hex);

    try std.testing.expectEqualSlices(u8, &bytes, &dk);
}

test "kdf rfc 4" {
    if (!run_long_tests) return error.SkipZigTest;

    const password = "pleaseletmein";
    const salt = "SodiumChloride";

    var dk: [64]u8 = undefined;
    try kdf(std.testing.allocator, &dk, password, salt, .{ .ln = 20, .r = 8, .p = 1 });

    const hex = "2101cb9b6a511aaeaddbbe09cf70f881ec568d574a2ffd4dabe5ee9820adaa478e56fd8f4ba5d09ffa1c6d927c40f4c337304049e8a952fbcbf45c6fa77a41a4";
    var bytes: [hex.len / 2]u8 = undefined;
    _ = try fmt.hexToBytes(&bytes, hex);

    try std.testing.expectEqualSlices(u8, &bytes, &dk);
}

test "password hashing (crypt format)" {
    if (!run_long_tests) return error.SkipZigTest;

    const alloc = std.testing.allocator;

    const str = "$7$A6....1....TrXs5Zk6s8sWHpQgWDIXTR8kUU3s6Jc3s.DtdS8M2i4$a4ik5hGDN7foMuHOW.cp.CtX01UyCeO0.JAG.AHPpx5";
    const password = "Y0!?iQa9M%5ekffW(`";
    try CryptFormatHasher.verify(alloc, str, password);

    const params = Params.interactive;
    var buf: [CryptFormatHasher.pwhash_str_length]u8 = undefined;
    const str2 = try CryptFormatHasher.create(alloc, password, params, &buf);
    try CryptFormatHasher.verify(alloc, str2, password);
}

test "strHash and strVerify" {
    if (!run_long_tests) return error.SkipZigTest;

    const alloc = std.testing.allocator;

    const password = "testpass";
    const params = Params.interactive;
    const verify_options = VerifyOptions{ .allocator = alloc };
    var buf: [128]u8 = undefined;

    {
        const str = try strHash(
            password,
            .{ .allocator = alloc, .params = params, .encoding = .crypt },
            &buf,
        );
        try strVerify(str, password, verify_options);
    }
    {
        const str = try strHash(
            password,
            .{ .allocator = alloc, .params = params, .encoding = .phc },
            &buf,
        );
        try strVerify(str, password, verify_options);
    }
}

test "unix-scrypt" {
    if (!run_long_tests) return error.SkipZigTest;

    const alloc = std.testing.allocator;

    // https://gitlab.com/jas/scrypt-unix-crypt/blob/master/unix-scrypt.txt
    {
        const str = "$7$C6..../....SodiumChloride$kBGj9fHznVYFQMEn/qDCfrDevf9YDtcDdKvEqHJLV8D";
        const password = "pleaseletmein";
        try strVerify(str, password, .{ .allocator = alloc });
    }
    // one of the libsodium test vectors
    {
        const str = "$7$B6....1....75gBMAGwfFWZqBdyF3WdTQnWdUsuTiWjG1fF9c1jiSD$tc8RoB3.Em3/zNgMLWo2u00oGIoTyJv4fl3Fl8Tix72";
        const password = "^T5H$JYt39n%K*j:W]!1s?vg!:jGi]Ax?..l7[p0v:1jHTpla9;]bUN;?bWyCbtqg nrDFal+Jxl3,2`#^tFSu%v_+7iYse8-cCkNf!tD=KrW)";
        try strVerify(str, password, .{ .allocator = alloc });
    }
}

test "crypt format" {
    const str = "$7$C6..../....SodiumChloride$kBGj9fHznVYFQMEn/qDCfrDevf9YDtcDdKvEqHJLV8D";
    const params = try crypt_format.deserialize(crypt_format.HashResult(32), str);
    var buf: [str.len]u8 = undefined;
    const s1 = try crypt_format.serialize(params, &buf);
    try std.testing.expectEqualStrings(s1, str);
}

test "kdf fast" {
    const TestVector = struct {
        password: []const u8,
        salt: []const u8,
        params: Params,
        want: []const u8,
    };
    const test_vectors = [_]TestVector{
        .{
            .password = "p",
            .salt = "s",
            .params = .{ .ln = 1, .r = 1, .p = 1 },
            .want = &([_]u8{
                0x48, 0xb0, 0xd2, 0xa8, 0xa3, 0x27, 0x26, 0x11,
                0x98, 0x4c, 0x50, 0xeb, 0xd6, 0x30, 0xaf, 0x52,
            }),
        },
    };
    inline for (test_vectors) |v| {
        var dk: [v.want.len]u8 = undefined;
        try kdf(std.testing.allocator, &dk, v.password, v.salt, v.params);
        try std.testing.expectEqualSlices(u8, &dk, v.want);
    }
}
