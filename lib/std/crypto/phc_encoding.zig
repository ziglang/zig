// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.

// https://github.com/P-H-C/phc-string-format/blob/master/phc-sf-spec.md
// https://github.com/P-H-C/phc-string-format/pull/4

const std = @import("std");
const base64 = std.base64;
const crypto = std.crypto;
const fmt = std.fmt;
const mem = std.mem;

const Error = crypto.Error;
const B64Encoder = base64.standard_no_pad.Encoder;
const B64Decoder = base64.standard_no_pad.Decoder;

const fields_delimiter = "$";
const version_prefix = "v=";
const params_delimiter = ",";
const kv_delimiter = "=";
const max_algorithm_id_len = 32;
const max_param_key_len = 32;

fn WrappedValue(comptime buf_len: usize) type {
    return struct {
        const Self = @This();

        buf: [buf_len]u8 = undefined,
        len: usize = 0,

        pub fn unwrap(self: Self) []const u8 {
            return self.buf[0..self.len];
        }
    };
}

pub fn Parser(
    comptime PhcParamsIterator: type,
    comptime Params: type,
    comptime salt_buf_len: usize,
    comptime derived_key_buf_len: usize,
) type {
    return struct {
        const Self = @This();
        pub const AlgorithmId = WrappedValue(max_algorithm_id_len);
        pub const Salt = WrappedValue(salt_buf_len);
        pub const DerivedKey = WrappedValue(derived_key_buf_len);

        algorithm_id: AlgorithmId,
        version: ?u32 = null,
        params: ?Params = null,
        salt: ?Salt = null,
        derived_key: ?DerivedKey = null,

        /// Parse phc encoded string
        pub fn fromString(str: []const u8) Error!Self {
            var it = mem.split(str, fields_delimiter);
            _ = it.next();
            var s = it.next() orelse return Error.InvalidEncoding;
            var res = Self{ .algorithm_id = AlgorithmId{} };
            if (s.len == 0 or s.len > res.algorithm_id.buf.len) {
                return Error.InvalidEncoding;
            }
            res.algorithm_id.len = s.len;
            mem.copy(u8, &res.algorithm_id.buf, s);
            s = it.next() orelse return res;
            if (mem.startsWith(u8, s, version_prefix) and
                mem.indexOf(u8, s, params_delimiter) == null)
            {
                res.version = fmt.parseInt(u32, s[version_prefix.len..], 10) catch {
                    return Error.InvalidEncoding;
                };
                s = it.next() orelse return res;
            }
            if (mem.indexOf(u8, s, kv_delimiter) != null) {
                var params_it = PhcParamsIterator.new(s, @typeInfo(Params).Struct.fields.len);
                res.params = try Params.fromPhcEncoding(&params_it);
                s = it.next() orelse return res;
            }
            res.salt = Salt{};
            b64decode(&res.salt.?, s) catch return Error.InvalidEncoding;
            s = it.next() orelse return res;
            res.derived_key = DerivedKey{};
            b64decode(&res.derived_key.?, s) catch return Error.InvalidEncoding;
            if (it.next() != null) {
                return Error.InvalidEncoding;
            }
            return res;
        }

        /// Calculate size for toString function out param
        pub fn calcSize(self: *Self) usize {
            var i = fields_delimiter.len + self.algorithm_id.len;
            if (self.version) |v| {
                // 32bit safe downcast
                i += @intCast(
                    usize,
                    fmt.count("{s}{s}{d}", .{ fields_delimiter, version_prefix, v }),
                );
            }
            if (self.params) |v| {
                var params: [@typeInfo(Params).Struct.fields.len]?PhcParamsIterator.Param = undefined;
                v.toPhcEncoding(&params);
                var sep_cnt: usize = 0;
                for (params) |param| {
                    const kv = param orelse continue;
                    i += kv.key.len + kv_delimiter.len + kv.value.len;
                    sep_cnt += 1;
                }
                if (sep_cnt != 0) {
                    i += fields_delimiter.len + ((sep_cnt - 1) * params_delimiter.len);
                }
            }
            if (self.salt) |v| {
                i += fields_delimiter.len + B64Encoder.calcSize(v.len);
            }
            if (self.derived_key) |v| {
                i += fields_delimiter.len + B64Encoder.calcSize(v.len);
            }
            return i;
        }

        /// Create phc encoded string
        pub fn toString(self: *Self, out: []u8) Error![]u8 {
            if (self.salt == null and self.derived_key != null) {
                return Error.InvalidEncoding;
            }
            mem.copy(u8, out, fields_delimiter);
            mem.copy(u8, out[fields_delimiter.len..], self.algorithm_id.unwrap());
            var i = fields_delimiter.len + self.algorithm_id.len;
            if (self.version) |v| {
                const s = fmt.bufPrint(
                    out[i..],
                    "{s}{s}{d}",
                    .{ fields_delimiter, version_prefix, v },
                ) catch unreachable;
                i += s.len;
            }
            if (self.params) |v| {
                var params: [@typeInfo(Params).Struct.fields.len]?PhcParamsIterator.Param = undefined;
                v.toPhcEncoding(&params);
                var sep_cnt: usize = 0;
                for (params) |param| {
                    if (param != null) {
                        sep_cnt += 1;
                    }
                }
                if (sep_cnt != 0) {
                    mem.copy(u8, out[i..], fields_delimiter);
                    i += fields_delimiter.len;
                    sep_cnt -= 1;
                }
                for (params) |param| {
                    const kv = param orelse continue;
                    const s = fmt.bufPrint(
                        out[i..],
                        "{s}{s}{s}",
                        .{ kv.key, kv_delimiter, kv.value.unwrap() },
                    ) catch unreachable;
                    i += s.len;
                    if (sep_cnt != 0) {
                        mem.copy(u8, out[i..], params_delimiter);
                        i += params_delimiter.len;
                        sep_cnt -= 1;
                    }
                }
            }
            if (self.salt) |v| {
                i += b64encode(out[i..], v.unwrap());
            }
            if (self.derived_key) |v| {
                i += b64encode(out[i..], v.unwrap());
            }
            return out[0..i];
        }
    };
}

/// For strHash && strVerify usage
pub fn Hasher(
    comptime PhcParser: type,
    comptime Params: type,
    comptime kdf: anytype,
    comptime algorithm_id: []const u8,
    comptime salt_len: usize,
    comptime derived_key_len: usize,
) type {
    return struct {
        /// Verify password against phc encoded string
        pub fn verify(
            allocator: *mem.Allocator,
            str: []const u8,
            password: []const u8,
        ) (Error || mem.Allocator.Error)!void {
            var parser = try PhcParser.fromString(str);
            if (!mem.eql(u8, parser.algorithm_id.unwrap(), algorithm_id)) {
                return Error.InvalidEncoding;
            }
            const params = parser.params orelse return Error.InvalidEncoding;
            const salt = parser.salt orelse return Error.InvalidEncoding;
            const derived_key = parser.derived_key orelse return Error.InvalidEncoding;
            if (derived_key.len != derived_key_len) {
                return Error.InvalidEncoding;
            }
            var dk: [derived_key_len]u8 = undefined;
            try kdf(allocator, &dk, password, salt.unwrap(), params);
            const ok = crypto.utils.timingSafeEql(
                [derived_key_len]u8,
                dk,
                derived_key.buf[0..derived_key_len].*,
            );
            crypto.utils.secureZero(u8, &dk);
            if (!ok) {
                return Error.PasswordVerificationFailed;
            }
        }

        fn makeParser(params: Params) PhcParser {
            return PhcParser{
                .algorithm_id = PhcParser.AlgorithmId{ .len = algorithm_id.len },
                .params = params,
                .salt = PhcParser.Salt{ .len = salt_len },
                .derived_key = PhcParser.DerivedKey{ .len = derived_key_len },
            };
        }

        /// Calculate size for create function out param
        pub fn calcSize(params: Params) usize {
            return makeParser(params).calcSize();
        }

        /// Derive key from password and return phc encoded string
        pub fn create(
            allocator: *mem.Allocator,
            password: []const u8,
            params: Params,
            out: []u8,
        ) (Error || mem.Allocator.Error)![]u8 {
            var salt: [salt_len]u8 = undefined;
            crypto.random.bytes(&salt);
            var derived_key: [derived_key_len]u8 = undefined;
            try kdf(allocator, &derived_key, password, &salt, params);
            var parser = makeParser(params);
            mem.copy(u8, &parser.algorithm_id.buf, algorithm_id);
            mem.copy(u8, &parser.salt.?.buf, &salt);
            mem.copy(u8, &parser.derived_key.?.buf, &derived_key);
            return parser.toString(out) catch unreachable;
        }
    };
}

fn b64encode(buf: []u8, v: []const u8) usize {
    mem.copy(u8, buf, fields_delimiter);
    const s = B64Encoder.encode(buf[fields_delimiter.len..], v);
    return fields_delimiter.len + s.len;
}

fn b64decode(buf_v: anytype, s: []const u8) !void {
    if (s.len == 0) {
        return Error.InvalidEncoding;
    }
    const len = try B64Decoder.calcSizeForSlice(s);
    if (len > buf_v.buf.len) {
        return Error.InvalidEncoding;
    }
    buf_v.len = len;
    try B64Decoder.decode(&buf_v.buf, s);
}

fn IteratorParam(comptime value_buf_len: usize) type {
    return struct {
        const Self = @This();
        pub const Value = WrappedValue(value_buf_len);

        key: []const u8,
        value: Value,

        pub fn decimal(self: Self, comptime T: type) Error!T {
            return fmt.parseInt(T, self.value.unwrap(), 10) catch return Error.InvalidEncoding;
        }
    };
}

/// For public interface usage
pub fn ParamsIterator(comptime value_buf_len: usize) type {
    return struct {
        const Self = @This();
        pub const Param = IteratorParam(value_buf_len);

        it: mem.SplitIterator,
        limit: usize,
        pos: usize = 0,

        fn new(s: []const u8, limit: usize) Self {
            return Self{ .it = mem.split(s, params_delimiter), .limit = limit };
        }

        pub fn next(self: *Self) Error!?Param {
            const s = self.it.next() orelse return null;
            if (self.pos == self.limit) {
                return Error.InvalidEncoding;
            }
            var it = mem.split(s, kv_delimiter);
            const key = it.next() orelse return Error.InvalidEncoding;
            if (key.len == 0 or key.len > max_param_key_len) {
                return Error.InvalidEncoding;
            }
            const value = it.next() orelse return Error.InvalidEncoding;
            if (it.next() != null) {
                return Error.InvalidEncoding;
            }
            var param = Param{ .key = key, .value = Param.Value{} };
            if (value.len > param.value.buf.len) {
                return Error.InvalidEncoding;
            }
            param.value.len = value.len;
            mem.copy(u8, &param.value.buf, value);
            self.pos += 1;
            return param;
        }
    };
}

test "conv" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt$v=1$ln=15,r=8,p=1$c2FsdHNhbHQ$dGVzdHBhc3M";

    var v = try scrypt.PhcParser.fromString(s);

    var buf: [s.len]u8 = undefined;
    const s1 = try v.toString(&buf);

    std.testing.expectEqualSlices(u8, s, s1);
}

test "conv only id" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt";

    var v = try scrypt.PhcParser.fromString(s);

    var buf: [s.len]u8 = undefined;
    const s1 = try v.toString(&buf);

    std.testing.expectEqualSlices(u8, s, s1);
}

test "conv only version" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt$v=1";

    var v = try scrypt.PhcParser.fromString(s);

    var buf: [s.len]u8 = undefined;
    const s1 = try v.toString(&buf);

    std.testing.expectEqualSlices(u8, s, s1);
}

test "conv only params" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt$ln=15,r=8,p=1";

    var v = try scrypt.PhcParser.fromString(s);

    var buf: [s.len]u8 = undefined;
    const s1 = try v.toString(&buf);

    std.testing.expectEqualSlices(u8, s, s1);
}

test "conv only salt" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt$c2FsdHNhbHQ";

    var v = try scrypt.PhcParser.fromString(s);

    var buf: [s.len]u8 = undefined;
    const s1 = try v.toString(&buf);

    std.testing.expectEqualSlices(u8, s, s1);
}

test "conv without derived_key" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt$v=1$ln=15,r=8,p=1$c2FsdHNhbHQ";

    var v = try scrypt.PhcParser.fromString(s);

    var buf: [s.len]u8 = undefined;
    const s1 = try v.toString(&buf);

    std.testing.expectEqualSlices(u8, s, s1);
}

test "conv without salt" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt$v=1$ln=15,r=8,p=1";

    var v = try scrypt.PhcParser.fromString(s);

    var buf: [s.len]u8 = undefined;
    const s1 = try v.toString(&buf);

    std.testing.expectEqualSlices(u8, s, s1);
}

test "conv without params" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt$v=1$c2FsdHNhbHQ$dGVzdHBhc3M";

    var v = try scrypt.PhcParser.fromString(s);

    var buf: [s.len]u8 = undefined;
    const s1 = try v.toString(&buf);

    std.testing.expectEqualSlices(u8, s, s1);
}

test "conv without version" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt$ln=15,r=8,p=1$c2FsdHNhbHQ$dGVzdHBhc3M";

    var v = try scrypt.PhcParser.fromString(s);

    var buf: [s.len]u8 = undefined;
    const s1 = try v.toString(&buf);

    std.testing.expectEqualSlices(u8, s, s1);
}

test "conv without params and derived_key" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt$v=1$c2FsdHNhbHQ";

    var v = try scrypt.PhcParser.fromString(s);

    var buf: [s.len]u8 = undefined;
    const s1 = try v.toString(&buf);

    std.testing.expectEqualSlices(u8, s, s1);
}

test "conv without version and params" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt$c2FsdHNhbHQ$dGVzdHBhc3M";

    var v = try scrypt.PhcParser.fromString(s);

    var buf: [s.len]u8 = undefined;
    const s1 = try v.toString(&buf);

    std.testing.expectEqualSlices(u8, s, s1);
}

test "error: invalid str" {
    const scrypt = @import("scrypt.zig");

    const s = "";
    std.testing.expectError(Error.InvalidEncoding, scrypt.PhcParser.fromString(s));

    const s1 = "$";
    std.testing.expectError(Error.InvalidEncoding, scrypt.PhcParser.fromString(s1));
}

test "error: derived_key without salt" {
    const scrypt = @import("scrypt.zig");

    const s = "$scrypt";

    var v = try scrypt.PhcParser.fromString(s);
    v.derived_key = scrypt.PhcParser.DerivedKey{};

    var buf: [s.len]u8 = undefined;
    std.testing.expectError(Error.InvalidEncoding, v.toString(&buf));
}

test "Hasher" {
    const scrypt = @import("scrypt.zig");
    const alloc = std.testing.allocator;

    const password = "testpass";

    var buf: [128]u8 = undefined;
    const s = try scrypt.PhcHasher.create(alloc, password, scrypt.Params.interactive, &buf);
    try scrypt.PhcHasher.verify(alloc, s, password);
}

test "calcSize" {
    const scrypt = @import("scrypt.zig");
    const alloc = std.testing.allocator;

    const s = "$scrypt$v=1$ln=15,r=8,p=1$c2FsdHNhbHQ$dGVzdHBhc3M";
    const password = "testpass";
    const params = scrypt.Params.interactive;

    var v = try scrypt.PhcParser.fromString(s);
    std.testing.expectEqual(v.calcSize(), s.len);

    var buf: [128]u8 = undefined;
    const s1 = try scrypt.PhcHasher.create(alloc, password, params, &buf);

    std.testing.expectEqual(scrypt.PhcHasher.calcSize(params), s1.len);
}
