// https://github.com/P-H-C/phc-string-format

const std = @import("std");
const fmt = std.fmt;
const io = std.io;
const mem = std.mem;
const meta = std.meta;

const fields_delimiter = "$";
const fields_delimiter_scalar = '$';
const version_param_name = "v";
const params_delimiter = ",";
const params_delimiter_scalar = ',';
const kv_delimiter = "=";
const kv_delimiter_scalar = '=';

pub const Error = std.crypto.errors.EncodingError || error{NoSpaceLeft};

const B64Decoder = std.base64.standard_no_pad.Decoder;
const B64Encoder = std.base64.standard_no_pad.Encoder;

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
        const max_encoded_length = B64Encoder.calcSize(max_len);

        buf: [max_len]u8 = undefined,
        len: usize = 0,

        /// Wrap an existing byte slice
        pub fn fromSlice(slice: []const u8) Error!Self {
            if (slice.len > capacity) return Error.NoSpaceLeft;
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
            const len = B64Decoder.calcSizeForSlice(str) catch return Error.InvalidEncoding;
            if (len > self.buf.len) return Error.NoSpaceLeft;
            B64Decoder.decode(&self.buf, str) catch return Error.InvalidEncoding;
            self.len = len;
        }

        fn toB64(self: *const Self, buf: []u8) ![]const u8 {
            const value = self.constSlice();
            const len = B64Encoder.calcSize(value.len);
            if (len > buf.len) return Error.NoSpaceLeft;
            return B64Encoder.encode(buf, value);
        }
    };
}

/// Deserialize a PHC-formatted string into a structure `HashResult`.
///
/// Required field in the `HashResult` structure:
///   - `alg_id`: algorithm identifier
/// Optional, special fields:
///   - `alg_version`: algorithm version (unsigned integer)
///   - `salt`: salt
///   - `hash`: output of the hash function
///
/// Other fields will also be deserialized from the function parameters section.
pub fn deserialize(comptime HashResult: type, str: []const u8) Error!HashResult {
    var out = mem.zeroes(HashResult);
    var it = mem.splitScalar(u8, str, fields_delimiter_scalar);
    var set_fields: usize = 0;

    while (true) {
        // Read the algorithm identifier
        if ((it.next() orelse return Error.InvalidEncoding).len != 0) return Error.InvalidEncoding;
        out.alg_id = it.next() orelse return Error.InvalidEncoding;
        set_fields += 1;

        // Read the optional version number
        var field = it.next() orelse break;
        if (kvSplit(field)) |opt_version| {
            if (mem.eql(u8, opt_version.key, version_param_name)) {
                if (@hasField(HashResult, "alg_version")) {
                    const value_type_info = switch (@typeInfo(@TypeOf(out.alg_version))) {
                        .optional => |opt| @typeInfo(opt.child),
                        else => |t| t,
                    };
                    out.alg_version = fmt.parseUnsigned(
                        @Type(value_type_info),
                        opt_version.value,
                        10,
                    ) catch return Error.InvalidEncoding;
                    set_fields += 1;
                }
                field = it.next() orelse break;
            }
        } else |_| {}

        // Read optional parameters
        var has_params = false;
        var it_params = mem.splitScalar(u8, field, params_delimiter_scalar);
        while (it_params.next()) |params| {
            const param = kvSplit(params) catch break;
            var found = false;
            inline for (comptime meta.fields(HashResult)) |p| {
                if (mem.eql(u8, p.name, param.key)) {
                    switch (@typeInfo(p.type)) {
                        .int => @field(out, p.name) = fmt.parseUnsigned(
                            p.type,
                            param.value,
                            10,
                        ) catch return Error.InvalidEncoding,
                        .pointer => |ptr| {
                            if (!ptr.is_const) @compileError("Value slice must be constant");
                            @field(out, p.name) = param.value;
                        },
                        .@"struct" => try @field(out, p.name).fromB64(param.value),
                        else => std.debug.panic(
                            "Value for [{s}] must be an integer, a constant slice or a BinValue",
                            .{p.name},
                        ),
                    }
                    set_fields += 1;
                    found = true;
                    break;
                }
            }
            if (!found) return Error.InvalidEncoding; // An unexpected parameter was found in the string
            has_params = true;
        }

        // No separator between an empty parameters set and the salt
        if (has_params) field = it.next() orelse break;

        // Read an optional salt
        if (@hasField(HashResult, "salt")) {
            try out.salt.fromB64(field);
            set_fields += 1;
        } else {
            return Error.InvalidEncoding;
        }

        // Read an optional hash
        field = it.next() orelse break;
        if (@hasField(HashResult, "hash")) {
            try out.hash.fromB64(field);
            set_fields += 1;
        } else {
            return Error.InvalidEncoding;
        }
        break;
    }

    // Check that all the required fields have been set, excluding optional values and parameters
    // with default values
    var expected_fields: usize = 0;
    inline for (comptime meta.fields(HashResult)) |p| {
        if (@typeInfo(p.type) != .optional and p.default_value == null) {
            expected_fields += 1;
        }
    }
    if (set_fields < expected_fields) return Error.InvalidEncoding;

    return out;
}

/// Serialize parameters into a PHC string.
///
/// Required field for `params`:
///   - `alg_id`: algorithm identifier
/// Optional, special fields:
///   - `alg_version`: algorithm version (unsigned integer)
///   - `salt`: salt
///   - `hash`: output of the hash function
///
/// `params` can also include any additional parameters.
pub fn serialize(params: anytype, str: []u8) Error![]const u8 {
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
    const HashResult = @TypeOf(params);
    try out.writeAll(fields_delimiter);
    try out.writeAll(params.alg_id);

    if (@hasField(HashResult, "alg_version")) {
        if (@typeInfo(@TypeOf(params.alg_version)) == .optional) {
            if (params.alg_version) |alg_version| {
                try out.print(
                    "{s}{s}{s}{}",
                    .{ fields_delimiter, version_param_name, kv_delimiter, alg_version },
                );
            }
        } else {
            try out.print(
                "{s}{s}{s}{}",
                .{ fields_delimiter, version_param_name, kv_delimiter, params.alg_version },
            );
        }
    }

    var has_params = false;
    inline for (comptime meta.fields(HashResult)) |p| {
        if (comptime !(mem.eql(u8, p.name, "alg_id") or
            mem.eql(u8, p.name, "alg_version") or
            mem.eql(u8, p.name, "hash") or
            mem.eql(u8, p.name, "salt")))
        {
            const value = @field(params, p.name);
            try out.writeAll(if (has_params) params_delimiter else fields_delimiter);
            if (@typeInfo(p.type) == .@"struct") {
                var buf: [@TypeOf(value).max_encoded_length]u8 = undefined;
                try out.print("{s}{s}{s}", .{ p.name, kv_delimiter, try value.toB64(&buf) });
            } else {
                try out.print(
                    if (@typeInfo(@TypeOf(value)) == .pointer) "{s}{s}{s}" else "{s}{s}{}",
                    .{ p.name, kv_delimiter, value },
                );
            }
            has_params = true;
        }
    }

    var has_salt = false;
    if (@hasField(HashResult, "salt")) {
        var buf: [@TypeOf(params.salt).max_encoded_length]u8 = undefined;
        try out.print("{s}{s}", .{ fields_delimiter, try params.salt.toB64(&buf) });
        has_salt = true;
    }

    if (@hasField(HashResult, "hash")) {
        var buf: [@TypeOf(params.hash).max_encoded_length]u8 = undefined;
        if (!has_salt) try out.writeAll(fields_delimiter);
        try out.print("{s}{s}", .{ fields_delimiter, try params.hash.toB64(&buf) });
    }
}

// Split a `key=value` string into `key` and `value`
fn kvSplit(str: []const u8) !struct { key: []const u8, value: []const u8 } {
    var it = mem.splitScalar(u8, str, kv_delimiter_scalar);
    const key = it.first();
    const value = it.next() orelse return Error.InvalidEncoding;
    const ret = .{ .key = key, .value = value };
    return ret;
}

test "phc format - encoding/decoding" {
    const Input = struct {
        str: []const u8,
        HashResult: type,
    };
    const inputs = [_]Input{
        .{
            .str = "$argon2id$v=19$key=a2V5,m=4096,t=0,p=1$X1NhbHQAAAAAAAAAAAAAAA$bWh++MKN1OiFHKgIWTLvIi1iHicmHH7+Fv3K88ifFfI",
            .HashResult = struct {
                alg_id: []const u8,
                alg_version: u16,
                key: BinValue(16),
                m: usize,
                t: u64,
                p: u32,
                salt: BinValue(16),
                hash: BinValue(32),
            },
        },
        .{
            .str = "$scrypt$v=1$ln=15,r=8,p=1$c2FsdHNhbHQ$dGVzdHBhc3M",
            .HashResult = struct {
                alg_id: []const u8,
                alg_version: ?u30,
                ln: u6,
                r: u30,
                p: u30,
                salt: BinValue(16),
                hash: BinValue(16),
            },
        },
        .{
            .str = "$scrypt",
            .HashResult = struct { alg_id: []const u8 },
        },
        .{ .str = "$scrypt$v=1", .HashResult = struct { alg_id: []const u8, alg_version: u16 } },
        .{
            .str = "$scrypt$ln=15,r=8,p=1",
            .HashResult = struct { alg_id: []const u8, alg_version: ?u30, ln: u6, r: u30, p: u30 },
        },
        .{
            .str = "$scrypt$c2FsdHNhbHQ",
            .HashResult = struct { alg_id: []const u8, salt: BinValue(16) },
        },
        .{
            .str = "$scrypt$v=1$ln=15,r=8,p=1$c2FsdHNhbHQ",
            .HashResult = struct {
                alg_id: []const u8,
                alg_version: u16,
                ln: u6,
                r: u30,
                p: u30,
                salt: BinValue(16),
            },
        },
        .{
            .str = "$scrypt$v=1$ln=15,r=8,p=1",
            .HashResult = struct { alg_id: []const u8, alg_version: ?u30, ln: u6, r: u30, p: u30 },
        },
        .{
            .str = "$scrypt$v=1$c2FsdHNhbHQ$dGVzdHBhc3M",
            .HashResult = struct {
                alg_id: []const u8,
                alg_version: u16,
                salt: BinValue(16),
                hash: BinValue(16),
            },
        },
        .{
            .str = "$scrypt$v=1$c2FsdHNhbHQ",
            .HashResult = struct { alg_id: []const u8, alg_version: u16, salt: BinValue(16) },
        },
        .{
            .str = "$scrypt$c2FsdHNhbHQ$dGVzdHBhc3M",
            .HashResult = struct { alg_id: []const u8, salt: BinValue(16), hash: BinValue(16) },
        },
    };
    inline for (inputs) |input| {
        const v = try deserialize(input.HashResult, input.str);
        var buf: [input.str.len]u8 = undefined;
        const s1 = try serialize(v, &buf);
        try std.testing.expectEqualSlices(u8, input.str, s1);
    }
}

test "phc format - empty input string" {
    const s = "";
    const v = deserialize(struct { alg_id: []const u8 }, s);
    try std.testing.expectError(Error.InvalidEncoding, v);
}

test "phc format - hash without salt" {
    const s = "$scrypt";
    const v = deserialize(struct { alg_id: []const u8, hash: BinValue(16) }, s);
    try std.testing.expectError(Error.InvalidEncoding, v);
}

test "phc format - calcSize" {
    const s = "$scrypt$v=1$ln=15,r=8,p=1$c2FsdHNhbHQ$dGVzdHBhc3M";
    const v = try deserialize(struct {
        alg_id: []const u8,
        alg_version: u16,
        ln: u6,
        r: u30,
        p: u30,
        salt: BinValue(8),
        hash: BinValue(8),
    }, s);
    try std.testing.expectEqual(calcSize(v), s.len);
}
