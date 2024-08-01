const std = @import("../std.zig");
const assert = std.debug.assert;
const utf8Decode = std.unicode.utf8Decode;
const utf8Encode = std.unicode.utf8Encode;

pub const ParseError = error{
    OutOfMemory,
    InvalidLiteral,
};

pub const Base = enum(u8) { decimal = 10, hex = 16, binary = 2, octal = 8 };
pub const FloatBase = enum(u8) { decimal = 10, hex = 16 };

pub const Result = union(enum) {
    /// Result fits if it fits in u64
    int: u64,
    /// Result is an int that doesn't fit in u64. Payload is the base, if it is
    /// not `.decimal` then the slice has a two character prefix.
    big_int: Base,
    /// Result is a float. Payload is the base, if it is not `.decimal` then
    /// the slice has a two character prefix.
    float: FloatBase,
    failure: Error,
};

pub const Error = union(enum) {
    /// The number has leading zeroes.
    leading_zero,
    /// Expected a digit after base prefix.
    digit_after_base,
    /// The base prefix is in uppercase.
    upper_case_base: usize,
    /// Float literal has an invalid base prefix.
    invalid_float_base: usize,
    /// Repeated '_' digit separator.
    repeated_underscore: usize,
    /// '_' digit separator after special character (+-.)
    invalid_underscore_after_special: usize,
    /// Invalid digit for the specified base.
    invalid_digit: struct { i: usize, base: Base },
    /// Invalid digit for an exponent.
    invalid_digit_exponent: usize,
    /// Float literal has multiple periods.
    duplicate_period,
    /// Float literal has multiple exponents.
    duplicate_exponent: usize,
    /// Exponent comes directly after '_' digit separator.
    exponent_after_underscore: usize,
    /// Special character (+-.) comes directly after exponent.
    special_after_underscore: usize,
    /// Number ends in special character (+-.)
    trailing_special: usize,
    /// Number ends in '_' digit separator.
    trailing_underscore: usize,
    /// Character not in [0-9a-zA-Z.+-_]
    invalid_character: usize,
    /// [+-] not immediately after [pPeE]
    invalid_exponent_sign: usize,
    /// Period comes directly after exponent.
    period_after_exponent: usize,

    pub fn fmtWithSource(self: Error, bytes: []const u8) std.fmt.Formatter(formatErrorWithSource) {
        return .{ .data = .{ .err = self, .bytes = bytes } };
    }

    pub fn noteWithSource(self: Error, bytes: []const u8) ?[]const u8 {
        if (self == .leading_zero) {
            const is_float = std.mem.indexOfScalar(u8, bytes, '.') != null;
            if (!is_float) return "use '0o' prefix for octal literals";
        }
        return null;
    }

    pub fn offset(self: Error) usize {
        return switch (self) {
            .leading_zero => 0,
            .digit_after_base => 0,
            .upper_case_base => |i| i,
            .invalid_float_base => |i| i,
            .repeated_underscore => |i| i,
            .invalid_underscore_after_special => |i| i,
            .invalid_digit => |e| e.i,
            .invalid_digit_exponent => |i| i,
            .duplicate_period => 0,
            .duplicate_exponent => |i| i,
            .exponent_after_underscore => |i| i,
            .special_after_underscore => |i| i,
            .trailing_special => |i| i,
            .trailing_underscore => |i| i,
            .invalid_character => |i| i,
            .invalid_exponent_sign => |i| i,
            .period_after_exponent => |i| i,
        };
    }
};

const FormatWithSource = struct {
    bytes: []const u8,
    err: Error,
};

fn formatErrorWithSource(
    self: FormatWithSource,
    comptime fmt: []const u8,
    options: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    _ = options;
    _ = fmt;
    switch (self.err) {
        .leading_zero => try writer.print("number '{s}' has leading zero", .{self.bytes}),
        .digit_after_base => try writer.writeAll("expected a digit after base prefix"),
        .upper_case_base => try writer.writeAll("base prefix must be lowercase"),
        .invalid_float_base => try writer.writeAll("invalid base for float literal"),
        .repeated_underscore => try writer.writeAll("repeated digit separator"),
        .invalid_underscore_after_special => try writer.writeAll("expected digit before digit separator"),
        .invalid_digit => |info| try writer.print("invalid digit '{c}' for {s} base", .{ self.bytes[info.i], @tagName(info.base) }),
        .invalid_digit_exponent => |i| try writer.print("invalid digit '{c}' in exponent", .{self.bytes[i]}),
        .duplicate_exponent => try writer.writeAll("duplicate exponent"),
        .exponent_after_underscore => try writer.writeAll("expected digit before exponent"),
        .special_after_underscore => |i| try writer.print("expected digit before '{c}'", .{self.bytes[i]}),
        .trailing_special => |i| try writer.print("expected digit after '{c}'", .{self.bytes[i - 1]}),
        .trailing_underscore => try writer.writeAll("trailing digit separator"),
        .duplicate_period => try writer.writeAll("duplicate period"),
        .invalid_character => try writer.writeAll("invalid character"),
        .invalid_exponent_sign => |i| {
            const hex = self.bytes.len >= 2 and self.bytes[0] == '0' and self.bytes[1] == 'x';
            if (hex) {
                try writer.print("sign '{c}' cannot follow digit '{c}' in hex base", .{ self.bytes[i], self.bytes[i - 1] });
            } else {
                try writer.print("sign '{c}' cannot follow digit '{c}' in current base", .{ self.bytes[i], self.bytes[i - 1] });
            }
        },
        .period_after_exponent => try writer.writeAll("unexpected period after exponent"),
    }
}

/// Parse Zig number literal accepted by fmt.parseInt, fmt.parseFloat and big_int.setString.
/// Valid for any input.
pub fn parseNumberLiteral(bytes: []const u8) Result {
    var i: usize = 0;
    var base: u8 = 10;
    if (bytes.len >= 2 and bytes[0] == '0') switch (bytes[1]) {
        'b' => {
            base = 2;
            i = 2;
        },
        'o' => {
            base = 8;
            i = 2;
        },
        'x' => {
            base = 16;
            i = 2;
        },
        'B', 'O', 'X' => return .{ .failure = .{ .upper_case_base = 1 } },
        '.', 'e', 'E' => {},
        else => return .{ .failure = .leading_zero },
    };
    if (bytes.len == 2 and base != 10) return .{ .failure = .digit_after_base };

    var x: u64 = 0;
    var overflow = false;
    var underscore = false;
    var period = false;
    var special: u8 = 0;
    var exponent = false;
    var float = false;
    while (i < bytes.len) : (i += 1) {
        const c = bytes[i];
        switch (c) {
            '_' => {
                if (i == 2 and base != 10) return .{ .failure = .{ .invalid_underscore_after_special = i } };
                if (special != 0) return .{ .failure = .{ .invalid_underscore_after_special = i } };
                if (underscore) return .{ .failure = .{ .repeated_underscore = i } };
                underscore = true;
                continue;
            },
            'e', 'E' => if (base == 10) {
                float = true;
                if (exponent) return .{ .failure = .{ .duplicate_exponent = i } };
                if (underscore) return .{ .failure = .{ .exponent_after_underscore = i } };
                special = c;
                exponent = true;
                continue;
            },
            'p', 'P' => if (base == 16) {
                if (i == 2) {
                    return .{ .failure = .{ .digit_after_base = {} } };
                }
                float = true;
                if (exponent) return .{ .failure = .{ .duplicate_exponent = i } };
                if (underscore) return .{ .failure = .{ .exponent_after_underscore = i } };
                special = c;
                exponent = true;
                continue;
            },
            '.' => {
                if (exponent) {
                    const digit_index = i - ".e".len;
                    if (digit_index < bytes.len) {
                        switch (bytes[digit_index]) {
                            '0'...'9' => return .{ .failure = .{ .period_after_exponent = i } },
                            else => {},
                        }
                    }
                }
                float = true;
                if (base != 10 and base != 16) return .{ .failure = .{ .invalid_float_base = 2 } };
                if (period) return .{ .failure = .duplicate_period };
                period = true;
                if (underscore) return .{ .failure = .{ .special_after_underscore = i } };
                special = c;
                continue;
            },
            '+', '-' => {
                switch (special) {
                    'p', 'P' => {},
                    'e', 'E' => if (base != 10) return .{ .failure = .{ .invalid_exponent_sign = i } },
                    else => return .{ .failure = .{ .invalid_exponent_sign = i } },
                }
                special = c;
                continue;
            },
            else => {},
        }
        const digit = switch (c) {
            '0'...'9' => c - '0',
            'A'...'Z' => c - 'A' + 10,
            'a'...'z' => c - 'a' + 10,
            else => return .{ .failure = .{ .invalid_character = i } },
        };
        if (digit >= base) return .{ .failure = .{ .invalid_digit = .{ .i = i, .base = @as(Base, @enumFromInt(base)) } } };
        if (exponent and digit >= 10) return .{ .failure = .{ .invalid_digit_exponent = i } };
        underscore = false;
        special = 0;

        if (float) continue;
        if (x != 0) {
            const res = @mulWithOverflow(x, base);
            if (res[1] != 0) overflow = true;
            x = res[0];
        }
        const res = @addWithOverflow(x, digit);
        if (res[1] != 0) overflow = true;
        x = res[0];
    }
    if (underscore) return .{ .failure = .{ .trailing_underscore = bytes.len - 1 } };
    if (special != 0) return .{ .failure = .{ .trailing_special = bytes.len - 1 } };

    if (float) return .{ .float = @as(FloatBase, @enumFromInt(base)) };
    if (overflow) return .{ .big_int = @as(Base, @enumFromInt(base)) };
    return .{ .int = x };
}
