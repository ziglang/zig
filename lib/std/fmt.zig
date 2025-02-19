//! String formatting and parsing.

const std = @import("std.zig");
const builtin = @import("builtin");

const io = std.io;
const math = std.math;
const assert = std.debug.assert;
const mem = std.mem;
const unicode = std.unicode;
const meta = std.meta;
const lossyCast = math.lossyCast;
const expectFmt = std.testing.expectFmt;
const testing = std.testing;

pub const float = @import("fmt/float.zig");

pub const default_max_depth = 3;

pub const Alignment = enum {
    left,
    center,
    right,
};

const default_alignment = .right;
const default_fill_char = ' ';

/// Deprecated; to be removed after 0.14.0 is tagged.
pub const FormatOptions = Options;

pub const Options = struct {
    precision: ?usize = null,
    width: ?usize = null,
    alignment: Alignment = default_alignment,
    fill: u8 = default_fill_char,
};

/// Renders fmt string with args, calling `writer` with slices of bytes.
/// If `writer` returns an error, the error is returned from `format` and
/// `writer` is not called again.
///
/// The format string must be comptime-known and may contain placeholders following
/// this format:
/// `{[argument][specifier]:[fill][alignment][width].[precision]}`
///
/// Above, each word including its surrounding [ and ] is a parameter which you have to replace with something:
///
/// - *argument* is either the numeric index or the field name of the argument that should be inserted
///   - when using a field name, you are required to enclose the field name (an identifier) in square
///     brackets, e.g. {[score]...} as opposed to the numeric index form which can be written e.g. {2...}
/// - *specifier* is a type-dependent formatting option that determines how a type should formatted (see below)
/// - *fill* is a single byte which is used to pad the formatted text
/// - *alignment* is one of the three bytes '<', '^', or '>' to make the text left-, center-, or right-aligned, respectively
/// - *width* is the total width of the field in bytes. This is generally only
///   useful for ASCII text, such as numbers.
/// - *precision* specifies how many decimals a formatted number should have
///
/// Note that most of the parameters are optional and may be omitted. Also you can leave out separators like `:` and `.` when
/// all parameters after the separator are omitted.
/// Only exception is the *fill* parameter. If a non-zero *fill* character is required at the same time as *width* is specified,
/// one has to specify *alignment* as well, as otherwise the digit following `:` is interpreted as *width*, not *fill*.
///
/// The *specifier* has several options for types:
/// - `x` and `X`: output numeric value in hexadecimal notation, or string in hexadecimal bytes
/// - `s`:
///   - for pointer-to-many and C pointers of u8, print as a C-string using zero-termination
///   - for slices of u8, print the entire slice as a string without zero-termination
/// - `b64`: output string as standard base64
/// - `e`: output floating point value in scientific notation
/// - `d`: output numeric value in decimal notation
/// - `b`: output integer value in binary notation
/// - `o`: output integer value in octal notation
/// - `c`: output integer as an ASCII character. Integer type must have 8 bits at max.
/// - `u`: output integer as an UTF-8 sequence. Integer type must have 21 bits at max.
/// - `D`: output nanoseconds as duration
/// - `B`: output bytes in SI units (decimal)
/// - `Bi`: output bytes in IEC units (binary)
/// - `?`: output optional value as either the unwrapped value, or `null`; may be followed by a format specifier for the underlying value.
/// - `!`: output error union value as either the unwrapped value, or the formatted error value; may be followed by a format specifier for the underlying value.
/// - `*`: output the address of the value instead of the value itself.
/// - `any`: output a value of any type using its default format.
///
/// If a formatted user type contains a function of the type
/// ```
/// pub fn format(value: ?, comptime fmt: []const u8, options: std.fmt.Options, writer: anytype) !void
/// ```
/// with `?` being the type formatted, this function will be called instead of the default implementation.
/// This allows user types to be formatted in a logical manner instead of dumping all fields of the type.
///
/// A user type may be a `struct`, `vector`, `union` or `enum` type.
///
/// To print literal curly braces, escape them by writing them twice, e.g. `{{` or `}}`.
pub fn format(bw: *std.io.BufferedWriter, comptime fmt: []const u8, args: anytype) anyerror!void {
    const ArgsType = @TypeOf(args);
    const args_type_info = @typeInfo(ArgsType);
    if (args_type_info != .@"struct") {
        @compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
    }

    const fields_info = args_type_info.@"struct".fields;
    if (fields_info.len > max_format_args) {
        @compileError("32 arguments max are supported per format call");
    }

    @setEvalBranchQuota(2000000);
    comptime var arg_state: ArgState = .{ .args_len = fields_info.len };
    comptime var i = 0;
    comptime var literal: []const u8 = "";
    inline while (true) {
        const start_index = i;

        inline while (i < fmt.len) : (i += 1) {
            switch (fmt[i]) {
                '{', '}' => break,
                else => {},
            }
        }

        comptime var end_index = i;
        comptime var unescape_brace = false;

        // Handle {{ and }}, those are un-escaped as single braces
        if (i + 1 < fmt.len and fmt[i + 1] == fmt[i]) {
            unescape_brace = true;
            // Make the first brace part of the literal...
            end_index += 1;
            // ...and skip both
            i += 2;
        }

        literal = literal ++ fmt[start_index..end_index];

        // We've already skipped the other brace, restart the loop
        if (unescape_brace) continue;

        // Write out the literal
        if (literal.len != 0) {
            try bw.writeAll(literal);
            literal = "";
        }

        if (i >= fmt.len) break;

        if (fmt[i] == '}') {
            @compileError("missing opening {");
        }

        // Get past the {
        comptime assert(fmt[i] == '{');
        i += 1;

        const fmt_begin = i;
        // Find the closing brace
        inline while (i < fmt.len and fmt[i] != '}') : (i += 1) {}
        const fmt_end = i;

        if (i >= fmt.len) {
            @compileError("missing closing }");
        }

        // Get past the }
        comptime assert(fmt[i] == '}');
        i += 1;

        const placeholder = comptime Placeholder.parse(fmt[fmt_begin..fmt_end].*);
        const arg_pos = comptime switch (placeholder.arg) {
            .none => null,
            .number => |pos| pos,
            .named => |arg_name| meta.fieldIndex(ArgsType, arg_name) orelse
                @compileError("no argument with name '" ++ arg_name ++ "'"),
        };

        const width = switch (placeholder.width) {
            .none => null,
            .number => |v| v,
            .named => |arg_name| blk: {
                const arg_i = comptime meta.fieldIndex(ArgsType, arg_name) orelse
                    @compileError("no argument with name '" ++ arg_name ++ "'");
                _ = comptime arg_state.nextArg(arg_i) orelse @compileError("too few arguments");
                break :blk @field(args, arg_name);
            },
        };

        const precision = switch (placeholder.precision) {
            .none => null,
            .number => |v| v,
            .named => |arg_name| blk: {
                const arg_i = comptime meta.fieldIndex(ArgsType, arg_name) orelse
                    @compileError("no argument with name '" ++ arg_name ++ "'");
                _ = comptime arg_state.nextArg(arg_i) orelse @compileError("too few arguments");
                break :blk @field(args, arg_name);
            },
        };

        const arg_to_print = comptime arg_state.nextArg(arg_pos) orelse
            @compileError("too few arguments");

        try bw.printValue(
            placeholder.specifier_arg,
            .{
                .fill = placeholder.fill,
                .alignment = placeholder.alignment,
                .width = width,
                .precision = precision,
            },
            @field(args, fields_info[arg_to_print].name),
            std.options.fmt_max_depth,
        );
    }

    if (comptime arg_state.hasUnusedArgs()) {
        const missing_count = arg_state.args_len - @popCount(arg_state.used_args);
        switch (missing_count) {
            0 => unreachable,
            1 => @compileError("unused argument in '" ++ fmt ++ "'"),
            else => @compileError(comptimePrint("{d}", .{missing_count}) ++ " unused arguments in '" ++ fmt ++ "'"),
        }
    }
}

fn cacheString(str: anytype) []const u8 {
    return &str;
}

pub const Placeholder = struct {
    specifier_arg: []const u8,
    fill: u21,
    alignment: Alignment,
    arg: Specifier,
    width: Specifier,
    precision: Specifier,

    pub fn parse(comptime str: anytype) Placeholder {
        const view = std.unicode.Utf8View.initComptime(&str);
        comptime var parser = Parser{
            .iter = view.iterator(),
        };

        // Parse the positional argument number
        const arg = comptime parser.specifier() catch |err|
            @compileError(@errorName(err));

        // Parse the format specifier
        const specifier_arg = comptime parser.until(':');

        // Skip the colon, if present
        if (comptime parser.char()) |ch| {
            if (ch != ':') {
                @compileError("expected : or }, found '" ++ unicode.utf8EncodeComptime(ch) ++ "'");
            }
        }

        // Parse the fill character, if present.
        // When the width field is also specified, the fill character must
        // be followed by an alignment specifier, unless it's '0' (zero)
        // (in which case it's handled as part of the width specifier)
        var fill: ?u21 = comptime if (parser.peek(1)) |ch|
            switch (ch) {
                '<', '^', '>' => parser.char(),
                else => null,
            }
        else
            null;

        // Parse the alignment parameter
        const alignment: ?Alignment = comptime if (parser.peek(0)) |ch| init: {
            switch (ch) {
                '<', '^', '>' => {
                    // consume the character
                    break :init switch (parser.char().?) {
                        '<' => .left,
                        '^' => .center,
                        else => .right,
                    };
                },
                else => break :init null,
            }
        } else null;

        // When none of the fill character and the alignment specifier have
        // been provided, check whether the width starts with a zero.
        if (fill == null and alignment == null) {
            fill = comptime if (parser.peek(0) == '0') '0' else null;
        }

        // Parse the width parameter
        const width = comptime parser.specifier() catch |err|
            @compileError(@errorName(err));

        // Skip the dot, if present
        if (comptime parser.char()) |ch| {
            if (ch != '.') {
                @compileError("expected . or }, found '" ++ unicode.utf8EncodeComptime(ch) ++ "'");
            }
        }

        // Parse the precision parameter
        const precision = comptime parser.specifier() catch |err|
            @compileError(@errorName(err));

        if (comptime parser.char()) |ch| {
            @compileError("extraneous trailing character '" ++ unicode.utf8EncodeComptime(ch) ++ "'");
        }

        return .{
            .specifier_arg = cacheString(specifier_arg[0..specifier_arg.len].*),
            .fill = fill orelse default_fill_char,
            .alignment = alignment orelse default_alignment,
            .arg = arg,
            .width = width,
            .precision = precision,
        };
    }
};

pub const Specifier = union(enum) {
    none,
    number: usize,
    named: []const u8,
};

/// A stream based parser for format strings.
///
/// Allows to implement formatters compatible with std.fmt without replicating
/// the standard library behavior.
pub const Parser = struct {
    iter: std.unicode.Utf8Iterator,

    // Returns a decimal number or null if the current character is not a
    // digit
    pub fn number(self: *@This()) ?usize {
        var r: ?usize = null;

        while (self.peek(0)) |code_point| {
            switch (code_point) {
                '0'...'9' => {
                    if (r == null) r = 0;
                    r.? *= 10;
                    r.? += code_point - '0';
                },
                else => break,
            }
            _ = self.iter.nextCodepoint();
        }

        return r;
    }

    // Returns a substring of the input starting from the current position
    // and ending where `ch` is found or until the end if not found
    pub fn until(self: *@This(), ch: u21) []const u8 {
        const start = self.iter.i;
        while (self.peek(0)) |code_point| {
            if (code_point == ch)
                break;
            _ = self.iter.nextCodepoint();
        }
        return self.iter.bytes[start..self.iter.i];
    }

    // Returns the character pointed to by the iterator if available, or
    // null otherwise
    pub fn char(self: *@This()) ?u21 {
        if (self.iter.nextCodepoint()) |code_point| {
            return code_point;
        }
        return null;
    }

    // Returns true if the iterator points to an existing character and
    // false otherwise
    pub fn maybe(self: *@This(), val: u21) bool {
        if (self.peek(0) == val) {
            _ = self.iter.nextCodepoint();
            return true;
        }
        return false;
    }

    // Returns a decimal number or null if the current character is not a
    // digit
    pub fn specifier(self: *@This()) !Specifier {
        if (self.maybe('[')) {
            const arg_name = self.until(']');

            if (!self.maybe(']'))
                return @field(anyerror, "Expected closing ]");

            return Specifier{ .named = arg_name };
        }
        if (self.number()) |i|
            return Specifier{ .number = i };

        return Specifier{ .none = {} };
    }

    // Returns the n-th next character or null if that's past the end
    pub fn peek(self: *@This(), n: usize) ?u21 {
        const original_i = self.iter.i;
        defer self.iter.i = original_i;

        var i: usize = 0;
        var code_point: ?u21 = null;
        while (i <= n) : (i += 1) {
            code_point = self.iter.nextCodepoint();
            if (code_point == null) return null;
        }
        return code_point;
    }
};

pub const ArgSetType = u32;
const max_format_args = @typeInfo(ArgSetType).int.bits;

pub const ArgState = struct {
    next_arg: usize = 0,
    used_args: ArgSetType = 0,
    args_len: usize,

    pub fn hasUnusedArgs(self: *@This()) bool {
        return @popCount(self.used_args) != self.args_len;
    }

    pub fn nextArg(self: *@This(), arg_index: ?usize) ?usize {
        const next_index = arg_index orelse init: {
            const arg = self.next_arg;
            self.next_arg += 1;
            break :init arg;
        };

        if (next_index >= self.args_len) {
            return null;
        }

        // Mark this argument as used
        self.used_args |= @as(ArgSetType, 1) << @as(u5, @intCast(next_index));
        return next_index;
    }
};

test {
    _ = float;
}

pub const Case = enum { lower, upper };

fn SliceEscape(comptime case: Case) type {
    const charset = "0123456789" ++ if (case == .upper) "ABCDEF" else "abcdef";

    return struct {
        pub fn format(
            bytes: []const u8,
            comptime fmt: []const u8,
            options: std.fmt.Options,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;
            var buf: [4]u8 = undefined;

            buf[0] = '\\';
            buf[1] = 'x';

            for (bytes) |c| {
                if (std.ascii.isPrint(c)) {
                    try writer.writeByte(c);
                } else {
                    buf[2] = charset[c >> 4];
                    buf[3] = charset[c & 15];
                    try writer.writeAll(&buf);
                }
            }
        }
    };
}

const formatSliceEscapeLower = SliceEscape(.lower).format;
const formatSliceEscapeUpper = SliceEscape(.upper).format;

/// Return a Formatter for a []const u8 where every non-printable ASCII
/// character is escaped as \xNN, where NN is the character in lowercase
/// hexadecimal notation.
pub fn fmtSliceEscapeLower(bytes: []const u8) std.fmt.Formatter(formatSliceEscapeLower) {
    return .{ .data = bytes };
}

/// Return a Formatter for a []const u8 where every non-printable ASCII
/// character is escaped as \xNN, where NN is the character in uppercase
/// hexadecimal notation.
pub fn fmtSliceEscapeUpper(bytes: []const u8) std.fmt.Formatter(formatSliceEscapeUpper) {
    return .{ .data = bytes };
}

/// Asserts the rendered integer value fits in `buffer`.
/// Returns the end index within `buffer`.
pub fn printInt(buffer: []u8, value: anytype, base: u8, case: Case, options: Options) usize {
    var bw: std.io.BufferedWriter = undefined;
    bw.initFixed(buffer);
    bw.printIntOptions(value, base, case, options) catch unreachable;
    return bw.end;
}

/// Converts values in the range [0, 100) to a base 10 string.
pub fn digits2(value: u8) [2]u8 {
    if (builtin.mode == .ReleaseSmall) {
        return .{ @intCast('0' + value / 10), @intCast('0' + value % 10) };
    } else {
        return "00010203040506070809101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899"[value * 2 ..][0..2].*;
    }
}

pub const ParseIntError = error{
    /// The result cannot fit in the type specified
    Overflow,

    /// The input was empty or contained an invalid character
    InvalidCharacter,
};

/// Creates a Formatter type from a format function. Wrapping data in Formatter(func) causes
/// the data to be formatted using the given function `func`.  `func` must be of the following
/// form:
///
///     fn formatExample(
///         data: T,
///         comptime fmt: []const u8,
///         options: std.fmt.Options,
///         writer: anytype,
///     ) !void;
///
pub fn Formatter(comptime formatFn: anytype) type {
    const Data = @typeInfo(@TypeOf(formatFn)).@"fn".params[0].type.?;
    return struct {
        data: Data,
        pub fn format(
            self: @This(),
            comptime fmt: []const u8,
            options: std.fmt.Options,
            writer: *std.io.BufferedWriter,
        ) anyerror!void {
            try formatFn(self.data, fmt, options, writer);
        }
    };
}

/// Parses the string `buf` as signed or unsigned representation in the
/// specified base of an integral value of type `T`.
///
/// When `base` is zero the string prefix is examined to detect the true base:
///  * A prefix of "0b" implies base=2,
///  * A prefix of "0o" implies base=8,
///  * A prefix of "0x" implies base=16,
///  * Otherwise base=10 is assumed.
///
/// Ignores '_' character in `buf`.
/// See also `parseUnsigned`.
pub fn parseInt(comptime T: type, buf: []const u8, base: u8) ParseIntError!T {
    return parseIntWithGenericCharacter(T, u8, buf, base);
}

/// Like `parseInt`, but with a generic `Character` type.
pub fn parseIntWithGenericCharacter(
    comptime Result: type,
    comptime Character: type,
    buf: []const Character,
    base: u8,
) ParseIntError!Result {
    if (buf.len == 0) return error.InvalidCharacter;
    if (buf[0] == '+') return parseIntWithSign(Result, Character, buf[1..], base, .pos);
    if (buf[0] == '-') return parseIntWithSign(Result, Character, buf[1..], base, .neg);
    return parseIntWithSign(Result, Character, buf, base, .pos);
}

test parseInt {
    try std.testing.expectEqual(-10, try parseInt(i32, "-10", 10));
    try std.testing.expectEqual(10, try parseInt(i32, "+10", 10));
    try std.testing.expectEqual(10, try parseInt(u32, "+10", 10));
    try std.testing.expectError(error.Overflow, parseInt(u32, "-10", 10));
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, " 10", 10));
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, "10 ", 10));
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, "_10_", 10));
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, "0x_10_", 10));
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, "0x10_", 10));
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, "0x_10", 10));
    try std.testing.expectEqual(255, try parseInt(u8, "255", 10));
    try std.testing.expectError(error.Overflow, parseInt(u8, "256", 10));

    // +0 and -0 should work for unsigned
    try std.testing.expectEqual(0, try parseInt(u8, "-0", 10));
    try std.testing.expectEqual(0, try parseInt(u8, "+0", 10));

    // ensure minInt is parsed correctly
    try std.testing.expectEqual(math.minInt(i1), try parseInt(i1, "-1", 10));
    try std.testing.expectEqual(math.minInt(i8), try parseInt(i8, "-128", 10));
    try std.testing.expectEqual(math.minInt(i43), try parseInt(i43, "-4398046511104", 10));

    // empty string or bare +- is invalid
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, "", 10));
    try std.testing.expectError(error.InvalidCharacter, parseInt(i32, "", 10));
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, "+", 10));
    try std.testing.expectError(error.InvalidCharacter, parseInt(i32, "+", 10));
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, "-", 10));
    try std.testing.expectError(error.InvalidCharacter, parseInt(i32, "-", 10));

    // autodectect the base
    try std.testing.expectEqual(111, try parseInt(i32, "111", 0));
    try std.testing.expectEqual(111, try parseInt(i32, "1_1_1", 0));
    try std.testing.expectEqual(111, try parseInt(i32, "1_1_1", 0));
    try std.testing.expectEqual(7, try parseInt(i32, "+0b111", 0));
    try std.testing.expectEqual(7, try parseInt(i32, "+0B111", 0));
    try std.testing.expectEqual(7, try parseInt(i32, "+0b1_11", 0));
    try std.testing.expectEqual(73, try parseInt(i32, "+0o111", 0));
    try std.testing.expectEqual(73, try parseInt(i32, "+0O111", 0));
    try std.testing.expectEqual(73, try parseInt(i32, "+0o11_1", 0));
    try std.testing.expectEqual(273, try parseInt(i32, "+0x111", 0));
    try std.testing.expectEqual(-7, try parseInt(i32, "-0b111", 0));
    try std.testing.expectEqual(-7, try parseInt(i32, "-0b11_1", 0));
    try std.testing.expectEqual(-73, try parseInt(i32, "-0o111", 0));
    try std.testing.expectEqual(-273, try parseInt(i32, "-0x111", 0));
    try std.testing.expectEqual(-273, try parseInt(i32, "-0X111", 0));
    try std.testing.expectEqual(-273, try parseInt(i32, "-0x1_11", 0));

    // bare binary/octal/decimal prefix is invalid
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, "0b", 0));
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, "0o", 0));
    try std.testing.expectError(error.InvalidCharacter, parseInt(u32, "0x", 0));

    // edge cases which previously errored due to base overflowing T
    try std.testing.expectEqual(@as(i2, -2), try std.fmt.parseInt(i2, "-10", 2));
    try std.testing.expectEqual(@as(i4, -8), try std.fmt.parseInt(i4, "-10", 8));
    try std.testing.expectEqual(@as(i5, -16), try std.fmt.parseInt(i5, "-10", 16));
}

fn parseIntWithSign(
    comptime Result: type,
    comptime Character: type,
    buf: []const Character,
    base: u8,
    comptime sign: enum { pos, neg },
) ParseIntError!Result {
    if (buf.len == 0) return error.InvalidCharacter;

    var buf_base = base;
    var buf_start = buf;
    if (base == 0) {
        // Treat is as a decimal number by default.
        buf_base = 10;
        // Detect the base by looking at buf prefix.
        if (buf.len > 2 and buf[0] == '0') {
            if (math.cast(u8, buf[1])) |c| switch (std.ascii.toLower(c)) {
                'b' => {
                    buf_base = 2;
                    buf_start = buf[2..];
                },
                'o' => {
                    buf_base = 8;
                    buf_start = buf[2..];
                },
                'x' => {
                    buf_base = 16;
                    buf_start = buf[2..];
                },
                else => {},
            };
        }
    }

    const add = switch (sign) {
        .pos => math.add,
        .neg => math.sub,
    };

    // accumulate into Accumulate which is always 8 bits or larger.  this prevents
    // `buf_base` from overflowing Result.
    const info = @typeInfo(Result);
    const Accumulate = std.meta.Int(info.int.signedness, @max(8, info.int.bits));
    var accumulate: Accumulate = 0;

    if (buf_start[0] == '_' or buf_start[buf_start.len - 1] == '_') return error.InvalidCharacter;

    for (buf_start) |c| {
        if (c == '_') continue;
        const digit = try charToDigit(math.cast(u8, c) orelse return error.InvalidCharacter, buf_base);
        if (accumulate != 0) {
            accumulate = try math.mul(Accumulate, accumulate, math.cast(Accumulate, buf_base) orelse return error.Overflow);
        } else if (sign == .neg) {
            // The first digit of a negative number.
            // Consider parsing "-4" as an i3.
            // This should work, but positive 4 overflows i3, so we can't cast the digit to T and subtract.
            accumulate = math.cast(Accumulate, -@as(i8, @intCast(digit))) orelse return error.Overflow;
            continue;
        }
        accumulate = try add(Accumulate, accumulate, math.cast(Accumulate, digit) orelse return error.Overflow);
    }

    return if (Result == Accumulate)
        accumulate
    else
        math.cast(Result, accumulate) orelse return error.Overflow;
}

/// Parses the string `buf` as unsigned representation in the specified base
/// of an integral value of type `T`.
///
/// When `base` is zero the string prefix is examined to detect the true base:
///  * A prefix of "0b" implies base=2,
///  * A prefix of "0o" implies base=8,
///  * A prefix of "0x" implies base=16,
///  * Otherwise base=10 is assumed.
///
/// Ignores '_' character in `buf`.
/// See also `parseInt`.
pub fn parseUnsigned(comptime T: type, buf: []const u8, base: u8) ParseIntError!T {
    return parseIntWithSign(T, u8, buf, base, .pos);
}

test parseUnsigned {
    try std.testing.expectEqual(50124, try parseUnsigned(u16, "050124", 10));
    try std.testing.expectEqual(65535, try parseUnsigned(u16, "65535", 10));
    try std.testing.expectEqual(65535, try parseUnsigned(u16, "65_535", 10));
    try std.testing.expectError(error.Overflow, parseUnsigned(u16, "65536", 10));

    try std.testing.expectEqual(0xffffffffffffffff, try parseUnsigned(u64, "0ffffffffffffffff", 16));
    try std.testing.expectEqual(0xffffffffffffffff, try parseUnsigned(u64, "0f_fff_fff_fff_fff_fff", 16));
    try std.testing.expectError(error.Overflow, parseUnsigned(u64, "10000000000000000", 16));

    try std.testing.expectEqual(0xDEADBEEF, try parseUnsigned(u32, "DeadBeef", 16));

    try std.testing.expectEqual(1, try parseUnsigned(u7, "1", 10));
    try std.testing.expectEqual(8, try parseUnsigned(u7, "1000", 2));

    try std.testing.expectError(error.InvalidCharacter, parseUnsigned(u32, "f", 10));
    try std.testing.expectError(error.InvalidCharacter, parseUnsigned(u8, "109", 8));

    try std.testing.expectEqual(1442151747, try parseUnsigned(u32, "NUMBER", 36));

    // these numbers should fit even though the base itself doesn't fit in the destination type
    try std.testing.expectEqual(0, try parseUnsigned(u1, "0", 10));
    try std.testing.expectEqual(1, try parseUnsigned(u1, "1", 10));
    try std.testing.expectError(error.Overflow, parseUnsigned(u1, "2", 10));
    try std.testing.expectEqual(1, try parseUnsigned(u1, "001", 16));
    try std.testing.expectEqual(3, try parseUnsigned(u2, "3", 16));
    try std.testing.expectError(error.Overflow, parseUnsigned(u2, "4", 16));

    // parseUnsigned does not expect a sign
    try std.testing.expectError(error.InvalidCharacter, parseUnsigned(u8, "+0", 10));
    try std.testing.expectError(error.InvalidCharacter, parseUnsigned(u8, "-0", 10));

    // test empty string error
    try std.testing.expectError(error.InvalidCharacter, parseUnsigned(u8, "", 10));
}

/// Parses a number like '2G', '2Gi', or '2GiB'.
pub fn parseIntSizeSuffix(buf: []const u8, digit_base: u8) ParseIntError!usize {
    var without_B = buf;
    if (mem.endsWith(u8, buf, "B")) without_B.len -= 1;
    var without_i = without_B;
    var magnitude_base: usize = 1000;
    if (mem.endsWith(u8, without_B, "i")) {
        without_i.len -= 1;
        magnitude_base = 1024;
    }
    if (without_i.len == 0) return error.InvalidCharacter;
    const orders_of_magnitude: usize = switch (without_i[without_i.len - 1]) {
        'k', 'K' => 1,
        'M' => 2,
        'G' => 3,
        'T' => 4,
        'P' => 5,
        'E' => 6,
        'Z' => 7,
        'Y' => 8,
        'R' => 9,
        'Q' => 10,
        else => 0,
    };
    var without_suffix = without_i;
    if (orders_of_magnitude > 0) {
        without_suffix.len -= 1;
    } else if (without_i.len != without_B.len) {
        return error.InvalidCharacter;
    }
    const multiplier = math.powi(usize, magnitude_base, orders_of_magnitude) catch |err| switch (err) {
        error.Underflow => unreachable,
        error.Overflow => return error.Overflow,
    };
    const number = try std.fmt.parseInt(usize, without_suffix, digit_base);
    return math.mul(usize, number, multiplier);
}

test parseIntSizeSuffix {
    try std.testing.expectEqual(2, try parseIntSizeSuffix("2", 10));
    try std.testing.expectEqual(2, try parseIntSizeSuffix("2B", 10));
    try std.testing.expectEqual(2000, try parseIntSizeSuffix("2kB", 10));
    try std.testing.expectEqual(2000, try parseIntSizeSuffix("2k", 10));
    try std.testing.expectEqual(2048, try parseIntSizeSuffix("2KiB", 10));
    try std.testing.expectEqual(2048, try parseIntSizeSuffix("2Ki", 10));
    try std.testing.expectEqual(10240, try parseIntSizeSuffix("aKiB", 16));
    try std.testing.expectError(error.InvalidCharacter, parseIntSizeSuffix("", 10));
    try std.testing.expectError(error.InvalidCharacter, parseIntSizeSuffix("2iB", 10));
}

pub const parseFloat = @import("fmt/parse_float.zig").parseFloat;
pub const ParseFloatError = @import("fmt/parse_float.zig").ParseFloatError;

test {
    _ = &parseFloat;
}

pub fn charToDigit(c: u8, base: u8) (error{InvalidCharacter}!u8) {
    const value = switch (c) {
        '0'...'9' => c - '0',
        'A'...'Z' => c - 'A' + 10,
        'a'...'z' => c - 'a' + 10,
        else => return error.InvalidCharacter,
    };

    if (value >= base) return error.InvalidCharacter;

    return value;
}

pub fn digitToChar(digit: u8, case: Case) u8 {
    return switch (digit) {
        0...9 => digit + '0',
        10...35 => digit + ((if (case == .upper) @as(u8, 'A') else @as(u8, 'a')) - 10),
        else => unreachable,
    };
}

pub const BufPrintError = error{
    /// As much as possible was written to the buffer, but it was too small to fit all the printed bytes.
    NoSpaceLeft,
};

/// Print a Formatter string into `buf`. Actually just a thin wrapper around `format` and `fixedBufferStream`.
/// Returns a slice of the bytes printed to.
pub fn bufPrint(buf: []u8, comptime fmt: []const u8, args: anytype) BufPrintError![]u8 {
    var bw: std.io.BufferedWriter = undefined;
    bw.initFixed(buf);
    bw.print(fmt, args) catch |err| switch (err) {
        error.NoSpaceLeft => return error.NoSpaceLeft,
        else => unreachable,
    };
    return bw.getWritten();
}

pub fn bufPrintZ(buf: []u8, comptime fmt: []const u8, args: anytype) BufPrintError![:0]u8 {
    const result = try bufPrint(buf, fmt ++ "\x00", args);
    return result[0 .. result.len - 1 :0];
}

/// Count the characters needed for format.
pub fn count(comptime fmt: []const u8, args: anytype) u64 {
    var counting_writer: std.io.CountingWriter = .{ .child_writer = std.io.null_writer };
    var bw = counting_writer.writer().unbuffered();
    bw.print(fmt, args) catch unreachable;
    return counting_writer.bytes_written;
}

pub const AllocPrintError = error{OutOfMemory};

pub fn allocPrint(allocator: mem.Allocator, comptime fmt: []const u8, args: anytype) AllocPrintError![]u8 {
    const size = math.cast(usize, count(fmt, args)) orelse return error.OutOfMemory;
    const buf = try allocator.alloc(u8, size);
    return bufPrint(buf, fmt, args) catch |err| switch (err) {
        error.NoSpaceLeft => unreachable, // we just counted the size above
    };
}

pub fn allocPrintZ(allocator: mem.Allocator, comptime fmt: []const u8, args: anytype) AllocPrintError![:0]u8 {
    const result = try allocPrint(allocator, fmt ++ "\x00", args);
    return result[0 .. result.len - 1 :0];
}

pub inline fn comptimePrint(comptime fmt: []const u8, args: anytype) *const [count(fmt, args):0]u8 {
    comptime {
        var buf: [count(fmt, args):0]u8 = undefined;
        _ = bufPrint(&buf, fmt, args) catch unreachable;
        buf[buf.len] = 0;
        const final = buf;
        return &final;
    }
}

test comptimePrint {
    @setEvalBranchQuota(2000);
    try std.testing.expectEqual(*const [3:0]u8, @TypeOf(comptimePrint("{}", .{100})));
    try std.testing.expectEqualSlices(u8, "100", comptimePrint("{}", .{100}));
    try std.testing.expectEqualStrings("30", comptimePrint("{d}", .{30.0}));
    try std.testing.expectEqualStrings("30.0", comptimePrint("{d:3.1}", .{30.0}));
    try std.testing.expectEqualStrings("0.05", comptimePrint("{d}", .{0.05}));
    try std.testing.expectEqualStrings("5e-2", comptimePrint("{e}", .{0.05}));
}

test "parse u64 digit too big" {
    _ = parseUnsigned(u64, "123a", 10) catch |err| {
        if (err == error.InvalidCharacter) return;
        unreachable;
    };
    unreachable;
}

test "parse unsigned comptime" {
    comptime {
        try std.testing.expectEqual(2, try parseUnsigned(usize, "2", 10));
    }
}

test "escaped braces" {
    try expectFmt("escaped: {{foo}}\n", "escaped: {{{{foo}}}}\n", .{});
    try expectFmt("escaped: {foo}\n", "escaped: {{foo}}\n", .{});
}

test "optional" {
    {
        const value: ?i32 = 1234;
        try expectFmt("optional: 1234\n", "optional: {?}\n", .{value});
        try expectFmt("optional: 1234\n", "optional: {?d}\n", .{value});
        try expectFmt("optional: 4d2\n", "optional: {?x}\n", .{value});
    }
    {
        const value: ?[]const u8 = "string";
        try expectFmt("optional: string\n", "optional: {?s}\n", .{value});
    }
    {
        const value: ?i32 = null;
        try expectFmt("optional: null\n", "optional: {?}\n", .{value});
    }
    {
        const value = @as(?*i32, @ptrFromInt(0xf000d000));
        try expectFmt("optional: *i32@f000d000\n", "optional: {*}\n", .{value});
    }
}

test "error" {
    {
        const value: anyerror!i32 = 1234;
        try expectFmt("error union: 1234\n", "error union: {!}\n", .{value});
        try expectFmt("error union: 1234\n", "error union: {!d}\n", .{value});
        try expectFmt("error union: 4d2\n", "error union: {!x}\n", .{value});
    }
    {
        const value: anyerror![]const u8 = "string";
        try expectFmt("error union: string\n", "error union: {!s}\n", .{value});
    }
    {
        const value: anyerror!i32 = error.InvalidChar;
        try expectFmt("error union: error.InvalidChar\n", "error union: {!}\n", .{value});
    }
}

test "int.small" {
    {
        const value: u3 = 0b101;
        try expectFmt("u3: 5\n", "u3: {}\n", .{value});
    }
}

test "int.specifier" {
    {
        const value: u8 = 'a';
        try expectFmt("u8: a\n", "u8: {c}\n", .{value});
    }
    {
        const value: u8 = 0b1100;
        try expectFmt("u8: 0b1100\n", "u8: 0b{b}\n", .{value});
    }
    {
        const value: u16 = 0o1234;
        try expectFmt("u16: 0o1234\n", "u16: 0o{o}\n", .{value});
    }
    {
        const value: u8 = 'a';
        try expectFmt("UTF-8: a\n", "UTF-8: {u}\n", .{value});
    }
    {
        const value: u21 = 0x1F310;
        try expectFmt("UTF-8: 🌐\n", "UTF-8: {u}\n", .{value});
    }
    {
        const value: u21 = 0xD800;
        try expectFmt("UTF-8: �\n", "UTF-8: {u}\n", .{value});
    }
    {
        const value: u21 = 0x110001;
        try expectFmt("UTF-8: �\n", "UTF-8: {u}\n", .{value});
    }
}

test "int.padded" {
    try expectFmt("u8: '   1'", "u8: '{:4}'", .{@as(u8, 1)});
    try expectFmt("u8: '1000'", "u8: '{:0<4}'", .{@as(u8, 1)});
    try expectFmt("u8: '0001'", "u8: '{:0>4}'", .{@as(u8, 1)});
    try expectFmt("u8: '0100'", "u8: '{:0^4}'", .{@as(u8, 1)});
    try expectFmt("i8: '-1  '", "i8: '{:<4}'", .{@as(i8, -1)});
    try expectFmt("i8: '  -1'", "i8: '{:>4}'", .{@as(i8, -1)});
    try expectFmt("i8: ' -1 '", "i8: '{:^4}'", .{@as(i8, -1)});
    try expectFmt("i16: '-1234'", "i16: '{:4}'", .{@as(i16, -1234)});
    try expectFmt("i16: '+1234'", "i16: '{:4}'", .{@as(i16, 1234)});
    try expectFmt("i16: '-12345'", "i16: '{:4}'", .{@as(i16, -12345)});
    try expectFmt("i16: '+12345'", "i16: '{:4}'", .{@as(i16, 12345)});
    try expectFmt("u16: '12345'", "u16: '{:4}'", .{@as(u16, 12345)});

    try expectFmt("UTF-8: 'ü   '", "UTF-8: '{u:<4}'", .{'ü'});
    try expectFmt("UTF-8: '   ü'", "UTF-8: '{u:>4}'", .{'ü'});
    try expectFmt("UTF-8: ' ü  '", "UTF-8: '{u:^4}'", .{'ü'});
}

test "buffer" {
    {
        var buf1: [32]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf1);
        var bw = fbs.writer();
        try bw.printValue("", .{}, 1234, std.options.fmt_max_depth);
        try std.testing.expectEqualStrings("1234", fbs.getWritten());

        fbs.reset();
        try bw.printValue("c", .{}, 'a', std.options.fmt_max_depth);
        try std.testing.expectEqualStrings("a", fbs.getWritten());

        fbs.reset();
        try bw.printValue("b", .{}, 0b1100, std.options.fmt_max_depth);
        try std.testing.expectEqualStrings("1100", fbs.getWritten());
    }
}

// Test formatting of arrays by value, by single-item pointer, and as a slice
fn expectArrayFmt(expected: []const u8, comptime template: []const u8, comptime array_value: anytype) !void {
    try expectFmt(expected, template, .{array_value});
    try expectFmt(expected, template, .{&array_value});
    var runtime_zero: usize = 0;
    _ = &runtime_zero;
    try expectFmt(expected, template, .{array_value[runtime_zero..]});
}

test "array" {
    {
        const value: [3]u8 = "abc".*;
        try expectArrayFmt("array: abc\n", "array: {s}\n", value);
        try expectArrayFmt("array: { 97, 98, 99 }\n", "array: {d}\n", value);
        try expectArrayFmt("array: { 61, 62, 63 }\n", "array: {x}\n", value);
        try expectArrayFmt("array: { 97, 98, 99 }\n", "array: {any}\n", value);

        var buf: [100]u8 = undefined;
        try expectFmt(
            try bufPrint(buf[0..], "array: [3]u8@{x}\n", .{@intFromPtr(&value)}),
            "array: {*}\n",
            .{&value},
        );
    }

    {
        const value = [2][3]u8{ "abc".*, "def".* };

        try expectArrayFmt("array: { abc, def }\n", "array: {s}\n", value);
        try expectArrayFmt("array: { { 97, 98, 99 }, { 100, 101, 102 } }\n", "array: {d}\n", value);
        try expectArrayFmt("array: { { 61, 62, 63 }, { 64, 65, 66 } }\n", "array: {x}\n", value);
    }
}

test "slice" {
    {
        const value: []const u8 = "abc";
        try expectFmt("slice: abc\n", "slice: {s}\n", .{value});
        try expectFmt("slice: { 97, 98, 99 }\n", "slice: {d}\n", .{value});
        try expectFmt("slice: { 61, 62, 63 }\n", "slice: {x}\n", .{value});
        try expectFmt("slice: { 97, 98, 99 }\n", "slice: {any}\n", .{value});
    }
    {
        var runtime_zero: usize = 0;
        _ = &runtime_zero;
        const value = @as([*]align(1) const []const u8, @ptrFromInt(0xdeadbeef))[runtime_zero..runtime_zero];
        try expectFmt("slice: []const u8@deadbeef\n", "slice: {*}\n", .{value});
    }
    {
        const null_term_slice: [:0]const u8 = "\x00hello\x00";
        try expectFmt("buf: \x00hello\x00\n", "buf: {s}\n", .{null_term_slice});
    }

    try expectFmt("buf:  Test\n", "buf: {s:5}\n", .{"Test"});
    try expectFmt("buf: Test\n Other text", "buf: {s}\n Other text", .{"Test"});

    {
        var int_slice = [_]u32{ 1, 4096, 391891, 1111111111 };
        var runtime_zero: usize = 0;
        _ = &runtime_zero;
        try expectFmt("int: { 1, 4096, 391891, 1111111111 }", "int: {any}", .{int_slice[runtime_zero..]});
        try expectFmt("int: { 1, 4096, 391891, 1111111111 }", "int: {d}", .{int_slice[runtime_zero..]});
        try expectFmt("int: { 1, 1000, 5fad3, 423a35c7 }", "int: {x}", .{int_slice[runtime_zero..]});
        try expectFmt("int: { 00001, 01000, 5fad3, 423a35c7 }", "int: {x:0>5}", .{int_slice[runtime_zero..]});
    }
    {
        const S1 = struct {
            x: u8,
        };
        const struct_slice: []const S1 = &[_]S1{ S1{ .x = 8 }, S1{ .x = 42 } };
        try expectFmt("slice: { fmt.test.slice.S1{ .x = 8 }, fmt.test.slice.S1{ .x = 42 } }", "slice: {any}", .{struct_slice});
    }
    {
        const S2 = struct {
            x: u8,

            pub fn format(s: @This(), comptime _: []const u8, _: std.fmt.Options, writer: anytype) !void {
                try writer.print("S2({})", .{s.x});
            }
        };
        const struct_slice: []const S2 = &[_]S2{ S2{ .x = 8 }, S2{ .x = 42 } };
        try expectFmt("slice: { S2(8), S2(42) }", "slice: {any}", .{struct_slice});
    }
}

test "escape non-printable" {
    try expectFmt("abc 123", "{s}", .{fmtSliceEscapeLower("abc 123")});
    try expectFmt("ab\\xffc", "{s}", .{fmtSliceEscapeLower("ab\xffc")});
    try expectFmt("abc 123", "{s}", .{fmtSliceEscapeUpper("abc 123")});
    try expectFmt("ab\\xFFc", "{s}", .{fmtSliceEscapeUpper("ab\xffc")});
}

test "pointer" {
    {
        const value = @as(*align(1) i32, @ptrFromInt(0xdeadbeef));
        try expectFmt("pointer: i32@deadbeef\n", "pointer: {}\n", .{value});
        try expectFmt("pointer: i32@deadbeef\n", "pointer: {*}\n", .{value});
    }
    const FnPtr = *align(1) const fn () void;
    {
        const value = @as(FnPtr, @ptrFromInt(0xdeadbeef));
        try expectFmt("pointer: fn () void@deadbeef\n", "pointer: {}\n", .{value});
    }
    {
        const value = @as(FnPtr, @ptrFromInt(0xdeadbeef));
        try expectFmt("pointer: fn () void@deadbeef\n", "pointer: {}\n", .{value});
    }
}

test "cstr" {
    try expectFmt(
        "cstr: Test C\n",
        "cstr: {s}\n",
        .{@as([*c]const u8, @ptrCast("Test C"))},
    );
    try expectFmt(
        "cstr:     Test C\n",
        "cstr: {s:10}\n",
        .{@as([*c]const u8, @ptrCast("Test C"))},
    );
}

test "struct" {
    {
        const Struct = struct {
            field: u8,
        };
        const value = Struct{ .field = 42 };
        try expectFmt("struct: fmt.test.struct.Struct{ .field = 42 }\n", "struct: {}\n", .{value});
        try expectFmt("struct: fmt.test.struct.Struct{ .field = 42 }\n", "struct: {}\n", .{&value});
    }
    {
        const Struct = struct {
            a: u0,
            b: u1,
        };
        const value = Struct{ .a = 0, .b = 1 };
        try expectFmt("struct: fmt.test.struct.Struct{ .a = 0, .b = 1 }\n", "struct: {}\n", .{value});
    }

    const S = struct {
        a: u32,
        b: anyerror,
    };

    const inst = S{
        .a = 456,
        .b = error.Unused,
    };

    try expectFmt("fmt.test.struct.S{ .a = 456, .b = error.Unused }", "{}", .{inst});
    // Tuples
    try expectFmt("{ }", "{}", .{.{}});
    try expectFmt("{ -1 }", "{}", .{.{-1}});
    try expectFmt("{ -1, 42, 2.5e4 }", "{}", .{.{ -1, 42, 0.25e5 }});
}

test "enum" {
    const Enum = enum {
        One,
        Two,
    };
    const value = Enum.Two;
    try expectFmt("enum: fmt.test.enum.Enum.Two\n", "enum: {}\n", .{value});
    try expectFmt("enum: fmt.test.enum.Enum.Two\n", "enum: {}\n", .{&value});
    try expectFmt("enum: fmt.test.enum.Enum.One\n", "enum: {}\n", .{Enum.One});
    try expectFmt("enum: fmt.test.enum.Enum.Two\n", "enum: {}\n", .{Enum.Two});

    // test very large enum to verify ct branch quota is large enough
    // TODO: https://github.com/ziglang/zig/issues/15609
    if (!((builtin.cpu.arch == .wasm32) and builtin.mode == .Debug)) {
        try expectFmt("enum: os.windows.win32error.Win32Error.INVALID_FUNCTION\n", "enum: {}\n", .{std.os.windows.Win32Error.INVALID_FUNCTION});
    }

    const E = enum {
        One,
        Two,
        Three,
    };

    const inst = E.Two;

    try expectFmt("fmt.test.enum.E.Two", "{}", .{inst});
}

test "non-exhaustive enum" {
    const Enum = enum(u16) {
        One = 0x000f,
        Two = 0xbeef,
        _,
    };
    try expectFmt("enum: fmt.test.non-exhaustive enum.Enum.One\n", "enum: {}\n", .{Enum.One});
    try expectFmt("enum: fmt.test.non-exhaustive enum.Enum.Two\n", "enum: {}\n", .{Enum.Two});
    try expectFmt("enum: fmt.test.non-exhaustive enum.Enum(4660)\n", "enum: {}\n", .{@as(Enum, @enumFromInt(0x1234))});
    try expectFmt("enum: fmt.test.non-exhaustive enum.Enum.One\n", "enum: {x}\n", .{Enum.One});
    try expectFmt("enum: fmt.test.non-exhaustive enum.Enum.Two\n", "enum: {x}\n", .{Enum.Two});
    try expectFmt("enum: fmt.test.non-exhaustive enum.Enum.Two\n", "enum: {X}\n", .{Enum.Two});
    try expectFmt("enum: fmt.test.non-exhaustive enum.Enum(1234)\n", "enum: {x}\n", .{@as(Enum, @enumFromInt(0x1234))});
}

test "float.scientific" {
    try expectFmt("f32: 1.34e0", "f32: {e}", .{@as(f32, 1.34)});
    try expectFmt("f32: 1.234e1", "f32: {e}", .{@as(f32, 12.34)});
    try expectFmt("f64: -1.234e11", "f64: {e}", .{@as(f64, -12.34e10)});
    try expectFmt("f64: 9.99996e-40", "f64: {e}", .{@as(f64, 9.999960e-40)});
}

test "float.scientific.precision" {
    try expectFmt("f64: 1.40971e-42", "f64: {e:.5}", .{@as(f64, 1.409706e-42)});
    try expectFmt("f64: 1.00000e-9", "f64: {e:.5}", .{@as(f64, @as(f32, @bitCast(@as(u32, 814313563))))});
    try expectFmt("f64: 7.81250e-3", "f64: {e:.5}", .{@as(f64, @as(f32, @bitCast(@as(u32, 1006632960))))});
    // libc rounds 1.000005e5 to 1.00000e5 but zig does 1.00001e5.
    // In fact, libc doesn't round a lot of 5 cases up when one past the precision point.
    try expectFmt("f64: 1.00001e5", "f64: {e:.5}", .{@as(f64, @as(f32, @bitCast(@as(u32, 1203982400))))});
}

test "float.special" {
    try expectFmt("f64: nan", "f64: {}", .{math.nan(f64)});
    // negative nan is not defined by IEE 754,
    // and ARM thus normalizes it to positive nan
    if (builtin.target.cpu.arch != .arm) {
        try expectFmt("f64: -nan", "f64: {}", .{-math.nan(f64)});
    }
    try expectFmt("f64: inf", "f64: {}", .{math.inf(f64)});
    try expectFmt("f64: -inf", "f64: {}", .{-math.inf(f64)});
}

test "float.hexadecimal.special" {
    try expectFmt("f64: nan", "f64: {x}", .{math.nan(f64)});
    // negative nan is not defined by IEE 754,
    // and ARM thus normalizes it to positive nan
    if (builtin.target.cpu.arch != .arm) {
        try expectFmt("f64: -nan", "f64: {x}", .{-math.nan(f64)});
    }
    try expectFmt("f64: inf", "f64: {x}", .{math.inf(f64)});
    try expectFmt("f64: -inf", "f64: {x}", .{-math.inf(f64)});

    try expectFmt("f64: 0x0.0p0", "f64: {x}", .{@as(f64, 0)});
    try expectFmt("f64: -0x0.0p0", "f64: {x}", .{-@as(f64, 0)});
}

test "float.hexadecimal" {
    try expectFmt("f16: 0x1.554p-2", "f16: {x}", .{@as(f16, 1.0 / 3.0)});
    try expectFmt("f32: 0x1.555556p-2", "f32: {x}", .{@as(f32, 1.0 / 3.0)});
    try expectFmt("f64: 0x1.5555555555555p-2", "f64: {x}", .{@as(f64, 1.0 / 3.0)});
    try expectFmt("f80: 0x1.5555555555555556p-2", "f80: {x}", .{@as(f80, 1.0 / 3.0)});
    try expectFmt("f128: 0x1.5555555555555555555555555555p-2", "f128: {x}", .{@as(f128, 1.0 / 3.0)});

    try expectFmt("f16: 0x1p-14", "f16: {x}", .{math.floatMin(f16)});
    try expectFmt("f32: 0x1p-126", "f32: {x}", .{math.floatMin(f32)});
    try expectFmt("f64: 0x1p-1022", "f64: {x}", .{math.floatMin(f64)});
    try expectFmt("f80: 0x1p-16382", "f80: {x}", .{math.floatMin(f80)});
    try expectFmt("f128: 0x1p-16382", "f128: {x}", .{math.floatMin(f128)});

    try expectFmt("f16: 0x0.004p-14", "f16: {x}", .{math.floatTrueMin(f16)});
    try expectFmt("f32: 0x0.000002p-126", "f32: {x}", .{math.floatTrueMin(f32)});
    try expectFmt("f64: 0x0.0000000000001p-1022", "f64: {x}", .{math.floatTrueMin(f64)});
    try expectFmt("f80: 0x0.0000000000000002p-16382", "f80: {x}", .{math.floatTrueMin(f80)});
    try expectFmt("f128: 0x0.0000000000000000000000000001p-16382", "f128: {x}", .{math.floatTrueMin(f128)});

    try expectFmt("f16: 0x1.ffcp15", "f16: {x}", .{math.floatMax(f16)});
    try expectFmt("f32: 0x1.fffffep127", "f32: {x}", .{math.floatMax(f32)});
    try expectFmt("f64: 0x1.fffffffffffffp1023", "f64: {x}", .{math.floatMax(f64)});
    try expectFmt("f80: 0x1.fffffffffffffffep16383", "f80: {x}", .{math.floatMax(f80)});
    try expectFmt("f128: 0x1.ffffffffffffffffffffffffffffp16383", "f128: {x}", .{math.floatMax(f128)});
}

test "float.hexadecimal.precision" {
    try expectFmt("f16: 0x1.5p-2", "f16: {x:.1}", .{@as(f16, 1.0 / 3.0)});
    try expectFmt("f32: 0x1.555p-2", "f32: {x:.3}", .{@as(f32, 1.0 / 3.0)});
    try expectFmt("f64: 0x1.55555p-2", "f64: {x:.5}", .{@as(f64, 1.0 / 3.0)});
    try expectFmt("f80: 0x1.5555555p-2", "f80: {x:.7}", .{@as(f80, 1.0 / 3.0)});
    try expectFmt("f128: 0x1.555555555p-2", "f128: {x:.9}", .{@as(f128, 1.0 / 3.0)});

    try expectFmt("f16: 0x1.00000p0", "f16: {x:.5}", .{@as(f16, 1.0)});
    try expectFmt("f32: 0x1.00000p0", "f32: {x:.5}", .{@as(f32, 1.0)});
    try expectFmt("f64: 0x1.00000p0", "f64: {x:.5}", .{@as(f64, 1.0)});
    try expectFmt("f80: 0x1.00000p0", "f80: {x:.5}", .{@as(f80, 1.0)});
    try expectFmt("f128: 0x1.00000p0", "f128: {x:.5}", .{@as(f128, 1.0)});
}

test "float.decimal" {
    try expectFmt("f64: 152314000000000000000000000000", "f64: {d}", .{@as(f64, 1.52314e29)});
    try expectFmt("f32: 0", "f32: {d}", .{@as(f32, 0.0)});
    try expectFmt("f32: 0", "f32: {d:.0}", .{@as(f32, 0.0)});
    try expectFmt("f32: 1.1", "f32: {d:.1}", .{@as(f32, 1.1234)});
    try expectFmt("f32: 1234.57", "f32: {d:.2}", .{@as(f32, 1234.567)});
    // -11.1234 is converted to f64 -11.12339... internally (errol3() function takes f64).
    // -11.12339... is rounded back up to -11.1234
    try expectFmt("f32: -11.1234", "f32: {d:.4}", .{@as(f32, -11.1234)});
    try expectFmt("f32: 91.12345", "f32: {d:.5}", .{@as(f32, 91.12345)});
    try expectFmt("f64: 91.1234567890", "f64: {d:.10}", .{@as(f64, 91.12345678901235)});
    try expectFmt("f64: 0.00000", "f64: {d:.5}", .{@as(f64, 0.0)});
    try expectFmt("f64: 6", "f64: {d:.0}", .{@as(f64, 5.700)});
    try expectFmt("f64: 10.0", "f64: {d:.1}", .{@as(f64, 9.999)});
    try expectFmt("f64: 1.000", "f64: {d:.3}", .{@as(f64, 1.0)});
    try expectFmt("f64: 0.00030000", "f64: {d:.8}", .{@as(f64, 0.0003)});
    try expectFmt("f64: 0.00000", "f64: {d:.5}", .{@as(f64, 1.40130e-45)});
    try expectFmt("f64: 0.00000", "f64: {d:.5}", .{@as(f64, 9.999960e-40)});
    try expectFmt("f64: 10000000000000.00", "f64: {d:.2}", .{@as(f64, 9999999999999.999)});
    try expectFmt("f64: 10000000000000000000000000000000000000", "f64: {d}", .{@as(f64, 1e37)});
    try expectFmt("f64: 100000000000000000000000000000000000000", "f64: {d}", .{@as(f64, 1e38)});
}

test "float.libc.sanity" {
    try expectFmt("f64: 0.00001", "f64: {d:.5}", .{@as(f64, @as(f32, @bitCast(@as(u32, 916964781))))});
    try expectFmt("f64: 0.00001", "f64: {d:.5}", .{@as(f64, @as(f32, @bitCast(@as(u32, 925353389))))});
    try expectFmt("f64: 0.10000", "f64: {d:.5}", .{@as(f64, @as(f32, @bitCast(@as(u32, 1036831278))))});
    try expectFmt("f64: 1.00000", "f64: {d:.5}", .{@as(f64, @as(f32, @bitCast(@as(u32, 1065353133))))});
    try expectFmt("f64: 10.00000", "f64: {d:.5}", .{@as(f64, @as(f32, @bitCast(@as(u32, 1092616192))))});

    // libc differences
    //
    // This is 0.015625 exactly according to gdb. We thus round down,
    // however glibc rounds up for some reason. This occurs for all
    // floats of the form x.yyyy25 on a precision point.
    try expectFmt("f64: 0.01563", "f64: {d:.5}", .{@as(f64, @as(f32, @bitCast(@as(u32, 1015021568))))});
    // errol3 rounds to ... 630 but libc rounds to ...632. Grisu3
    // also rounds to 630 so I'm inclined to believe libc is not
    // optimal here.
    try expectFmt("f64: 18014400656965630.00000", "f64: {d:.5}", .{@as(f64, @as(f32, @bitCast(@as(u32, 1518338049))))});
}

test "custom" {
    const Vec2 = struct {
        const SelfType = @This();
        x: f32,
        y: f32,

        pub fn format(
            self: SelfType,
            comptime fmt: []const u8,
            options: Options,
            writer: anytype,
        ) !void {
            _ = options;
            if (fmt.len == 0 or comptime std.mem.eql(u8, fmt, "p")) {
                return std.fmt.format(writer, "({d:.3},{d:.3})", .{ self.x, self.y });
            } else if (comptime std.mem.eql(u8, fmt, "d")) {
                return std.fmt.format(writer, "{d:.3}x{d:.3}", .{ self.x, self.y });
            } else {
                @compileError("unknown format character: '" ++ fmt ++ "'");
            }
        }
    };

    var value = Vec2{
        .x = 10.2,
        .y = 2.22,
    };
    try expectFmt("point: (10.200,2.220)\n", "point: {}\n", .{&value});
    try expectFmt("dim: 10.200x2.220\n", "dim: {d}\n", .{&value});

    // same thing but not passing a pointer
    try expectFmt("point: (10.200,2.220)\n", "point: {}\n", .{value});
    try expectFmt("dim: 10.200x2.220\n", "dim: {d}\n", .{value});
}

test "union" {
    const TU = union(enum) {
        float: f32,
        int: u32,
    };

    const UU = union {
        float: f32,
        int: u32,
    };

    const EU = extern union {
        float: f32,
        int: u32,
    };

    const tu_inst = TU{ .int = 123 };
    const uu_inst = UU{ .int = 456 };
    const eu_inst = EU{ .float = 321.123 };

    try expectFmt("fmt.test.union.TU{ .int = 123 }", "{}", .{tu_inst});

    var buf: [100]u8 = undefined;
    const uu_result = try bufPrint(buf[0..], "{}", .{uu_inst});
    try std.testing.expectEqualStrings("fmt.test.union.UU@", uu_result[0..18]);

    const eu_result = try bufPrint(buf[0..], "{}", .{eu_inst});
    try std.testing.expectEqualStrings("fmt.test.union.EU@", eu_result[0..18]);
}

test "struct.self-referential" {
    const S = struct {
        const SelfType = @This();
        a: ?*SelfType,
    };

    var inst = S{
        .a = null,
    };
    inst.a = &inst;

    try expectFmt("fmt.test.struct.self-referential.S{ .a = fmt.test.struct.self-referential.S{ .a = fmt.test.struct.self-referential.S{ .a = fmt.test.struct.self-referential.S{ ... } } } }", "{}", .{inst});
}

test "struct.zero-size" {
    const A = struct {
        fn foo() void {}
    };
    const B = struct {
        a: A,
        c: i32,
    };

    const a = A{};
    const b = B{ .a = a, .c = 0 };

    try expectFmt("fmt.test.struct.zero-size.B{ .a = fmt.test.struct.zero-size.A{ }, .c = 0 }", "{}", .{b});
}

/// Encodes a sequence of bytes as hexadecimal digits.
/// Returns an array containing the encoded bytes.
pub fn bytesToHex(input: anytype, case: Case) [input.len * 2]u8 {
    if (input.len == 0) return [_]u8{};
    comptime assert(@TypeOf(input[0]) == u8); // elements to encode must be unsigned bytes

    const charset = "0123456789" ++ if (case == .upper) "ABCDEF" else "abcdef";
    var result: [input.len * 2]u8 = undefined;
    for (input, 0..) |b, i| {
        result[i * 2 + 0] = charset[b >> 4];
        result[i * 2 + 1] = charset[b & 15];
    }
    return result;
}

/// Decodes the sequence of bytes represented by the specified string of
/// hexadecimal characters.
/// Returns a slice of the output buffer containing the decoded bytes.
pub fn hexToBytes(out: []u8, input: []const u8) ![]u8 {
    // Expect 0 or n pairs of hexadecimal digits.
    if (input.len & 1 != 0)
        return error.InvalidLength;
    if (out.len * 2 < input.len)
        return error.NoSpaceLeft;

    var in_i: usize = 0;
    while (in_i < input.len) : (in_i += 2) {
        const hi = try charToDigit(input[in_i], 16);
        const lo = try charToDigit(input[in_i + 1], 16);
        out[in_i / 2] = (hi << 4) | lo;
    }

    return out[0 .. in_i / 2];
}

test bytesToHex {
    const input = "input slice";
    const encoded = bytesToHex(input, .lower);
    var decoded: [input.len]u8 = undefined;
    try std.testing.expectEqualSlices(u8, input, try hexToBytes(&decoded, &encoded));
}

test hexToBytes {
    var buf: [32]u8 = undefined;
    try expectFmt("90" ** 32, "{X}", .{try hexToBytes(&buf, "90" ** 32)});
    try expectFmt("ABCD", "{X}", .{try hexToBytes(&buf, "ABCD")});
    try expectFmt("", "{X}", .{try hexToBytes(&buf, "")});
    try std.testing.expectError(error.InvalidCharacter, hexToBytes(&buf, "012Z"));
    try std.testing.expectError(error.InvalidLength, hexToBytes(&buf, "AAA"));
    try std.testing.expectError(error.NoSpaceLeft, hexToBytes(buf[0..1], "ABAB"));
}

test "positional" {
    try expectFmt("2 1 0", "{2} {1} {0}", .{ @as(usize, 0), @as(usize, 1), @as(usize, 2) });
    try expectFmt("2 1 0", "{2} {1} {}", .{ @as(usize, 0), @as(usize, 1), @as(usize, 2) });
    try expectFmt("0 0", "{0} {0}", .{@as(usize, 0)});
    try expectFmt("0 1", "{} {1}", .{ @as(usize, 0), @as(usize, 1) });
    try expectFmt("1 0 0 1", "{1} {} {0} {}", .{ @as(usize, 0), @as(usize, 1) });
}

test "positional with specifier" {
    try expectFmt("10.0", "{0d:.1}", .{@as(f64, 9.999)});
}

test "positional/alignment/width/precision" {
    try expectFmt("10.0", "{0d: >3.1}", .{@as(f64, 9.999)});
}

test "vector" {
    if ((builtin.cpu.arch == .armeb or builtin.cpu.arch == .thumbeb) and builtin.zig_backend == .stage2_llvm) return error.SkipZigTest; // https://github.com/ziglang/zig/issues/22060
    if (builtin.target.cpu.arch == .riscv64) {
        // https://github.com/ziglang/zig/issues/4486
        return error.SkipZigTest;
    }

    const vbool: @Vector(4, bool) = [_]bool{ true, false, true, false };
    const vi64: @Vector(4, i64) = [_]i64{ -2, -1, 0, 1 };
    const vu64: @Vector(4, u64) = [_]u64{ 1000, 2000, 3000, 4000 };

    try expectFmt("{ true, false, true, false }", "{}", .{vbool});
    try expectFmt("{ -2, -1, 0, 1 }", "{}", .{vi64});
    try expectFmt("{    -2,    -1,    +0,    +1 }", "{d:5}", .{vi64});
    try expectFmt("{ 1000, 2000, 3000, 4000 }", "{}", .{vu64});
    try expectFmt("{ 3e8, 7d0, bb8, fa0 }", "{x}", .{vu64});

    const x: [4]u64 = undefined;
    const vp: @Vector(4, *const u64) = [_]*const u64{ &x[0], &x[1], &x[2], &x[3] };
    const vop: @Vector(4, ?*const u64) = [_]?*const u64{ &x[0], null, null, &x[3] };

    var expect_buffer: [@sizeOf(usize) * 2 * 4 + 64]u8 = undefined;
    try expectFmt(try bufPrint(
        &expect_buffer,
        "{{ {}, {}, {}, {} }}",
        .{ &x[0], &x[1], &x[2], &x[3] },
    ), "{}", .{vp});
    try expectFmt(try bufPrint(
        &expect_buffer,
        "{{ {?}, null, null, {?} }}",
        .{ &x[0], &x[3] },
    ), "{any}", .{vop});
}

test "enum-literal" {
    try expectFmt(".hello_world", "{}", .{.hello_world});
}

test "padding" {
    try expectFmt("Simple", "{s}", .{"Simple"});
    try expectFmt("      true", "{:10}", .{true});
    try expectFmt("      true", "{:>10}", .{true});
    try expectFmt("======true", "{:=>10}", .{true});
    try expectFmt("true======", "{:=<10}", .{true});
    try expectFmt("   true   ", "{:^10}", .{true});
    try expectFmt("===true===", "{:=^10}", .{true});
    try expectFmt("           Minimum width", "{s:18} width", .{"Minimum"});
    try expectFmt("==================Filled", "{s:=>24}", .{"Filled"});
    try expectFmt("        Centered        ", "{s:^24}", .{"Centered"});
    try expectFmt("-", "{s:-^1}", .{""});
    try expectFmt("==crêpe===", "{s:=^10}", .{"crêpe"});
    try expectFmt("=====crêpe", "{s:=>10}", .{"crêpe"});
    try expectFmt("crêpe=====", "{s:=<10}", .{"crêpe"});
    try expectFmt("====a", "{c:=>5}", .{'a'});
    try expectFmt("==a==", "{c:=^5}", .{'a'});
    try expectFmt("a====", "{c:=<5}", .{'a'});
}

test "padding fill char utf" {
    try expectFmt("──crêpe───", "{s:─^10}", .{"crêpe"});
    try expectFmt("─────crêpe", "{s:─>10}", .{"crêpe"});
    try expectFmt("crêpe─────", "{s:─<10}", .{"crêpe"});
    try expectFmt("────a", "{c:─>5}", .{'a'});
    try expectFmt("──a──", "{c:─^5}", .{'a'});
    try expectFmt("a────", "{c:─<5}", .{'a'});
}

test "decimal float padding" {
    const number: f32 = 3.1415;
    try expectFmt("left-pad:   **3.142\n", "left-pad:   {d:*>7.3}\n", .{number});
    try expectFmt("center-pad: *3.142*\n", "center-pad: {d:*^7.3}\n", .{number});
    try expectFmt("right-pad:  3.142**\n", "right-pad:  {d:*<7.3}\n", .{number});
}

test "sci float padding" {
    const number: f32 = 3.1415;
    try expectFmt("left-pad:   ****3.142e0\n", "left-pad:   {e:*>11.3}\n", .{number});
    try expectFmt("center-pad: **3.142e0**\n", "center-pad: {e:*^11.3}\n", .{number});
    try expectFmt("right-pad:  3.142e0****\n", "right-pad:  {e:*<11.3}\n", .{number});
}

test "padding.zero" {
    try expectFmt("zero-pad: '0042'", "zero-pad: '{:04}'", .{42});
    try expectFmt("std-pad: '        42'", "std-pad: '{:10}'", .{42});
    try expectFmt("std-pad-1: '001'", "std-pad-1: '{:0>3}'", .{1});
    try expectFmt("std-pad-2: '911'", "std-pad-2: '{:1<03}'", .{9});
    try expectFmt("std-pad-3: '  1'", "std-pad-3: '{:>03}'", .{1});
    try expectFmt("center-pad: '515'", "center-pad: '{:5^03}'", .{1});
}

test "null" {
    const inst = null;
    try expectFmt("null", "{}", .{inst});
}

test "type" {
    try expectFmt("u8", "{}", .{u8});
    try expectFmt("?f32", "{}", .{?f32});
    try expectFmt("[]const u8", "{}", .{[]const u8});
}

test "named arguments" {
    try expectFmt("hello world!", "{s} world{c}", .{ "hello", '!' });
    try expectFmt("hello world!", "{[greeting]s} world{[punctuation]c}", .{ .punctuation = '!', .greeting = "hello" });
    try expectFmt("hello world!", "{[1]s} world{[0]c}", .{ '!', "hello" });
}

test "runtime width specifier" {
    const width: usize = 9;
    try expectFmt("~~hello~~", "{s:~^[1]}", .{ "hello", width });
    try expectFmt("~~hello~~", "{s:~^[width]}", .{ .string = "hello", .width = width });
    try expectFmt("    hello", "{s:[1]}", .{ "hello", width });
    try expectFmt("42     hello", "{d} {s:[2]}", .{ 42, "hello", width });
}

test "runtime precision specifier" {
    const number: f32 = 3.1415;
    const precision: usize = 2;
    try expectFmt("3.14e0", "{:1.[1]}", .{ number, precision });
    try expectFmt("3.14e0", "{:1.[precision]}", .{ .number = number, .precision = precision });
}

test "recursive format function" {
    const R = union(enum) {
        const R = @This();
        Leaf: i32,
        Branch: struct { left: *const R, right: *const R },

        pub fn format(self: R, comptime _: []const u8, _: std.fmt.Options, writer: anytype) !void {
            return switch (self) {
                .Leaf => |n| std.fmt.format(writer, "Leaf({})", .{n}),
                .Branch => |b| std.fmt.format(writer, "Branch({}, {})", .{ b.left, b.right }),
            };
        }
    };

    var r = R{ .Leaf = 1 };
    try expectFmt("Leaf(1)\n", "{}\n", .{&r});
}

pub const hex_charset = "0123456789abcdef";

/// Converts an unsigned integer of any multiple of u8 to an array of lowercase
/// hex bytes, little endian.
pub fn hex(x: anytype) [@sizeOf(@TypeOf(x)) * 2]u8 {
    comptime assert(@typeInfo(@TypeOf(x)).int.signedness == .unsigned);
    var result: [@sizeOf(@TypeOf(x)) * 2]u8 = undefined;
    var i: usize = 0;
    while (i < result.len / 2) : (i += 1) {
        const byte: u8 = @truncate(x >> @intCast(8 * i));
        result[i * 2 + 0] = hex_charset[byte >> 4];
        result[i * 2 + 1] = hex_charset[byte & 15];
    }
    return result;
}

test hex {
    {
        const x = hex(@as(u32, 0xdeadbeef));
        try std.testing.expect(x.len == 8);
        try std.testing.expectEqualStrings("efbeadde", &x);
    }
    {
        const s = "[" ++ hex(@as(u64, 0x12345678_abcdef00)) ++ "]";
        try std.testing.expect(s.len == 18);
        try std.testing.expectEqualStrings("[00efcdab78563412]", s);
    }
}

test "parser until" {
    { // return substring till ':'
        var parser: Parser = .{
            .iter = .{ .bytes = "abc:1234", .i = 0 },
        };
        try testing.expectEqualStrings("abc", parser.until(':'));
    }

    { // return the entire string - `ch` not found
        var parser: Parser = .{
            .iter = .{ .bytes = "abc1234", .i = 0 },
        };
        try testing.expectEqualStrings("abc1234", parser.until(':'));
    }

    { // substring is empty - `ch` is the only character
        var parser: Parser = .{
            .iter = .{ .bytes = ":", .i = 0 },
        };
        try testing.expectEqualStrings("", parser.until(':'));
    }

    { // empty string and `ch` not found
        var parser: Parser = .{
            .iter = .{ .bytes = "", .i = 0 },
        };
        try testing.expectEqualStrings("", parser.until(':'));
    }

    { // substring starts at index 2 and goes upto `ch`
        var parser: Parser = .{
            .iter = .{ .bytes = "abc:1234", .i = 2 },
        };
        try testing.expectEqualStrings("c", parser.until(':'));
    }

    { // substring starts at index 4 and goes upto the end - `ch` not found
        var parser: Parser = .{
            .iter = .{ .bytes = "abc1234", .i = 4 },
        };
        try testing.expectEqualStrings("234", parser.until(':'));
    }
}

test "parser peek" {
    { // start iteration from the first index
        var parser: Parser = .{
            .iter = .{ .bytes = "hello world", .i = 0 },
        };

        try testing.expectEqual('h', parser.peek(0));
        try testing.expectEqual('e', parser.peek(1));
        try testing.expectEqual(' ', parser.peek(5));
        try testing.expectEqual('d', parser.peek(10));
        try testing.expectEqual(null, parser.peek(11));
    }

    { // start iteration from the second last index
        var parser: Parser = .{
            .iter = .{ .bytes = "hello world!", .i = 10 },
        };

        try testing.expectEqual('d', parser.peek(0));
        try testing.expectEqual('!', parser.peek(1));
        try testing.expectEqual(null, parser.peek(5));
    }

    { // start iteration beyond the length of the string
        var parser: Parser = .{
            .iter = .{ .bytes = "hello", .i = 5 },
        };

        try testing.expectEqual(null, parser.peek(0));
        try testing.expectEqual(null, parser.peek(1));
    }

    { // empty string
        var parser: Parser = .{
            .iter = .{ .bytes = "", .i = 0 },
        };

        try testing.expectEqual(null, parser.peek(0));
        try testing.expectEqual(null, parser.peek(2));
    }
}

test "parser char" {
    // character exists - iterator at 0
    var parser: Parser = .{ .iter = .{ .bytes = "~~hello", .i = 0 } };
    try testing.expectEqual('~', parser.char());

    // character exists - iterator in the middle
    parser = .{ .iter = .{ .bytes = "~~hello", .i = 3 } };
    try testing.expectEqual('e', parser.char());

    // character exists - iterator at the end
    parser = .{ .iter = .{ .bytes = "~~hello", .i = 6 } };
    try testing.expectEqual('o', parser.char());

    // character doesn't exist - iterator beyond the length of the string
    parser = .{ .iter = .{ .bytes = "~~hello", .i = 7 } };
    try testing.expectEqual(null, parser.char());
}

test "parser maybe" {
    // character exists - iterator at 0
    var parser: Parser = .{ .iter = .{ .bytes = "hello world", .i = 0 } };
    try testing.expect(parser.maybe('h'));

    // character exists - iterator at space
    parser = .{ .iter = .{ .bytes = "hello world", .i = 5 } };
    try testing.expect(parser.maybe(' '));

    // character exists - iterator at the end
    parser = .{ .iter = .{ .bytes = "hello world", .i = 10 } };
    try testing.expect(parser.maybe('d'));

    // character doesn't exist - iterator beyond the length of the string
    parser = .{ .iter = .{ .bytes = "hello world", .i = 11 } };
    try testing.expect(!parser.maybe('e'));
}

test "parser number" {
    // input is a single digit natural number - iterator at 0
    var parser: Parser = .{ .iter = .{ .bytes = "7", .i = 0 } };
    try testing.expect(7 == parser.number());

    // input is a two digit natural number - iterator at 1
    parser = .{ .iter = .{ .bytes = "29", .i = 1 } };
    try testing.expect(9 == parser.number());

    // input is a two digit natural number - iterator beyond the length of the string
    parser = .{ .iter = .{ .bytes = "32", .i = 2 } };
    try testing.expectEqual(null, parser.number());

    // input is an integer
    parser = .{ .iter = .{ .bytes = "0", .i = 0 } };
    try testing.expect(0 == parser.number());

    // input is a negative integer
    parser = .{ .iter = .{ .bytes = "-2", .i = 0 } };
    try testing.expectEqual(null, parser.number());

    // input is a string
    parser = .{ .iter = .{ .bytes = "no_number", .i = 2 } };
    try testing.expectEqual(null, parser.number());

    // input is a single character string
    parser = .{ .iter = .{ .bytes = "n", .i = 0 } };
    try testing.expectEqual(null, parser.number());

    // input is an empty string
    parser = .{ .iter = .{ .bytes = "", .i = 0 } };
    try testing.expectEqual(null, parser.number());
}

test "parser specifier" {
    { // input string is a digit; iterator at 0
        const expected: Specifier = Specifier{ .number = 1 };
        var parser: Parser = .{ .iter = .{ .bytes = "1", .i = 0 } };

        const result = try parser.specifier();
        try testing.expect(expected.number == result.number);
    }

    { // input string is a two digit number; iterator at 0
        const digit: Specifier = Specifier{ .number = 42 };
        var parser: Parser = .{ .iter = .{ .bytes = "42", .i = 0 } };

        const result = try parser.specifier();
        try testing.expect(digit.number == result.number);
    }

    { // input string is a two digit number digit; iterator at 1
        const digit: Specifier = Specifier{ .number = 8 };
        var parser: Parser = .{ .iter = .{ .bytes = "28", .i = 1 } };

        const result = try parser.specifier();
        try testing.expect(digit.number == result.number);
    }

    { // input string is a two digit number with square brackets; iterator at 0
        const digit: Specifier = Specifier{ .named = "15" };
        var parser: Parser = .{ .iter = .{ .bytes = "[15]", .i = 0 } };

        const result = try parser.specifier();
        try testing.expectEqualStrings(digit.named, result.named);
    }

    { // input string is not a number and contains square brackets; iterator at 0
        const digit: Specifier = Specifier{ .named = "hello" };
        var parser: Parser = .{ .iter = .{ .bytes = "[hello]", .i = 0 } };

        const result = try parser.specifier();
        try testing.expectEqualStrings(digit.named, result.named);
    }

    { // input string is not a number and doesn't contain closing square bracket; iterator at 0
        var parser: Parser = .{ .iter = .{ .bytes = "[hello", .i = 0 } };

        const result = parser.specifier();
        try testing.expectError(@field(anyerror, "Expected closing ]"), result);
    }

    { // input string is not a number and doesn't contain closing square bracket; iterator at 2
        var parser: Parser = .{ .iter = .{ .bytes = "[[[[hello", .i = 2 } };

        const result = parser.specifier();
        try testing.expectError(@field(anyerror, "Expected closing ]"), result);
    }

    { // input string is not a number and contains unbalanced square brackets; iterator at 0
        const digit: Specifier = Specifier{ .named = "[[hello" };
        var parser: Parser = .{ .iter = .{ .bytes = "[[[hello]", .i = 0 } };

        const result = try parser.specifier();
        try testing.expectEqualStrings(digit.named, result.named);
    }

    { // input string is not a number and contains unbalanced square brackets; iterator at 1
        const digit: Specifier = Specifier{ .named = "[[hello" };
        var parser: Parser = .{ .iter = .{ .bytes = "[[[[hello]]]]]", .i = 1 } };

        const result = try parser.specifier();
        try testing.expectEqualStrings(digit.named, result.named);
    }

    { // input string is neither a digit nor a named argument
        const char: Specifier = Specifier{ .none = {} };
        var parser: Parser = .{ .iter = .{ .bytes = "hello", .i = 0 } };

        const result = try parser.specifier();
        try testing.expectEqual(char.none, result.none);
    }
}
