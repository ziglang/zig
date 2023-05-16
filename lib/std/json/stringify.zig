const std = @import("std");
const mem = std.mem;
const assert = std.debug.assert;

pub const StringifyOptions = struct {
    pub const Whitespace = struct {
        /// How many indentation levels deep are we?
        indent_level: usize = 0,

        /// What character(s) should be used for indentation?
        indent: union(enum) {
            space: u8,
            tab: void,
            none: void,
        } = .{ .space = 4 },

        /// After a colon, should whitespace be inserted?
        separator: bool = true,

        pub fn outputIndent(
            whitespace: @This(),
            out_stream: anytype,
        ) @TypeOf(out_stream).Error!void {
            var char: u8 = undefined;
            var n_chars: usize = undefined;
            switch (whitespace.indent) {
                .space => |n_spaces| {
                    char = ' ';
                    n_chars = n_spaces;
                },
                .tab => {
                    char = '\t';
                    n_chars = 1;
                },
                .none => return,
            }
            try out_stream.writeByte('\n');
            n_chars *= whitespace.indent_level;
            try out_stream.writeByteNTimes(char, n_chars);
        }
    };

    /// Controls the whitespace emitted
    whitespace: Whitespace = .{ .indent = .none, .separator = false },

    /// Should optional fields with null value be written?
    emit_null_optional_fields: bool = true,

    string: StringOptions = StringOptions{ .String = .{} },

    /// Should []u8 be serialised as a string? or an array?
    pub const StringOptions = union(enum) {
        Array,
        String: StringOutputOptions,

        /// String output options
        const StringOutputOptions = struct {
            /// Should '/' be escaped in strings?
            escape_solidus: bool = false,

            /// Should unicode characters be escaped in strings?
            escape_unicode: bool = false,
        };
    };
};

fn outputUnicodeEscape(
    codepoint: u21,
    out_stream: anytype,
) !void {
    if (codepoint <= 0xFFFF) {
        // If the character is in the Basic Multilingual Plane (U+0000 through U+FFFF),
        // then it may be represented as a six-character sequence: a reverse solidus, followed
        // by the lowercase letter u, followed by four hexadecimal digits that encode the character's code point.
        try out_stream.writeAll("\\u");
        try std.fmt.formatIntValue(codepoint, "x", std.fmt.FormatOptions{ .width = 4, .fill = '0' }, out_stream);
    } else {
        assert(codepoint <= 0x10FFFF);
        // To escape an extended character that is not in the Basic Multilingual Plane,
        // the character is represented as a 12-character sequence, encoding the UTF-16 surrogate pair.
        const high = @intCast(u16, (codepoint - 0x10000) >> 10) + 0xD800;
        const low = @intCast(u16, codepoint & 0x3FF) + 0xDC00;
        try out_stream.writeAll("\\u");
        try std.fmt.formatIntValue(high, "x", std.fmt.FormatOptions{ .width = 4, .fill = '0' }, out_stream);
        try out_stream.writeAll("\\u");
        try std.fmt.formatIntValue(low, "x", std.fmt.FormatOptions{ .width = 4, .fill = '0' }, out_stream);
    }
}

/// Write `string` to `writer` as a JSON encoded string.
pub fn encodeJsonString(string: []const u8, options: StringifyOptions, writer: anytype) !void {
    try writer.writeByte('\"');
    try encodeJsonStringChars(string, options, writer);
    try writer.writeByte('\"');
}

/// Write `chars` to `writer` as JSON encoded string characters.
pub fn encodeJsonStringChars(chars: []const u8, options: StringifyOptions, writer: anytype) !void {
    var i: usize = 0;
    while (i < chars.len) : (i += 1) {
        switch (chars[i]) {
            // normal ascii character
            0x20...0x21, 0x23...0x2E, 0x30...0x5B, 0x5D...0x7F => |c| try writer.writeByte(c),
            // only 2 characters that *must* be escaped
            '\\' => try writer.writeAll("\\\\"),
            '\"' => try writer.writeAll("\\\""),
            // solidus is optional to escape
            '/' => {
                if (options.string.String.escape_solidus) {
                    try writer.writeAll("\\/");
                } else {
                    try writer.writeByte('/');
                }
            },
            // control characters with short escapes
            // TODO: option to switch between unicode and 'short' forms?
            0x8 => try writer.writeAll("\\b"),
            0xC => try writer.writeAll("\\f"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                const ulen = std.unicode.utf8ByteSequenceLength(chars[i]) catch unreachable;
                // control characters (only things left with 1 byte length) should always be printed as unicode escapes
                if (ulen == 1 or options.string.String.escape_unicode) {
                    const codepoint = std.unicode.utf8Decode(chars[i..][0..ulen]) catch unreachable;
                    try outputUnicodeEscape(codepoint, writer);
                } else {
                    try writer.writeAll(chars[i..][0..ulen]);
                }
                i += ulen - 1;
            },
        }
    }
}

pub fn stringify(
    value: anytype,
    options: StringifyOptions,
    out_stream: anytype,
) !void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .Float, .ComptimeFloat => {
            return std.fmt.formatFloatScientific(value, std.fmt.FormatOptions{}, out_stream);
        },
        .Int, .ComptimeInt => {
            return std.fmt.formatIntValue(value, "", std.fmt.FormatOptions{}, out_stream);
        },
        .Bool => {
            return out_stream.writeAll(if (value) "true" else "false");
        },
        .Null => {
            return out_stream.writeAll("null");
        },
        .Optional => {
            if (value) |payload| {
                return try stringify(payload, options, out_stream);
            } else {
                return try stringify(null, options, out_stream);
            }
        },
        .Enum => {
            if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                return value.jsonStringify(options, out_stream);
            }

            @compileError("Unable to stringify enum '" ++ @typeName(T) ++ "'");
        },
        .Union => {
            if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                return value.jsonStringify(options, out_stream);
            }

            const info = @typeInfo(T).Union;
            if (info.tag_type) |UnionTagType| {
                try out_stream.writeByte('{');
                var child_options = options;
                child_options.whitespace.indent_level += 1;
                inline for (info.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        try child_options.whitespace.outputIndent(out_stream);
                        try encodeJsonString(u_field.name, options, out_stream);
                        try out_stream.writeByte(':');
                        if (child_options.whitespace.separator) {
                            try out_stream.writeByte(' ');
                        }
                        if (u_field.type == void) {
                            try out_stream.writeAll("{}");
                        } else {
                            try stringify(@field(value, u_field.name), child_options, out_stream);
                        }
                        break;
                    }
                } else {
                    unreachable; // No active tag?
                }
                try options.whitespace.outputIndent(out_stream);
                try out_stream.writeByte('}');
                return;
            } else {
                @compileError("Unable to stringify untagged union '" ++ @typeName(T) ++ "'");
            }
        },
        .Struct => |S| {
            if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                return value.jsonStringify(options, out_stream);
            }

            try out_stream.writeByte(if (S.is_tuple) '[' else '{');
            var field_output = false;
            var child_options = options;
            child_options.whitespace.indent_level += 1;
            inline for (S.fields) |Field| {
                // don't include void fields
                if (Field.type == void) continue;

                var emit_field = true;

                // don't include optional fields that are null when emit_null_optional_fields is set to false
                if (@typeInfo(Field.type) == .Optional) {
                    if (options.emit_null_optional_fields == false) {
                        if (@field(value, Field.name) == null) {
                            emit_field = false;
                        }
                    }
                }

                if (emit_field) {
                    if (!field_output) {
                        field_output = true;
                    } else {
                        try out_stream.writeByte(',');
                    }
                    try child_options.whitespace.outputIndent(out_stream);
                    if (!S.is_tuple) {
                        try encodeJsonString(Field.name, options, out_stream);
                        try out_stream.writeByte(':');
                        if (child_options.whitespace.separator) {
                            try out_stream.writeByte(' ');
                        }
                    }
                    try stringify(@field(value, Field.name), child_options, out_stream);
                }
            }
            if (field_output) {
                try options.whitespace.outputIndent(out_stream);
            }
            try out_stream.writeByte(if (S.is_tuple) ']' else '}');
            return;
        },
        .ErrorSet => return stringify(@as([]const u8, @errorName(value)), options, out_stream),
        .Pointer => |ptr_info| switch (ptr_info.size) {
            .One => switch (@typeInfo(ptr_info.child)) {
                .Array => {
                    const Slice = []const std.meta.Elem(ptr_info.child);
                    return stringify(@as(Slice, value), options, out_stream);
                },
                else => {
                    // TODO: avoid loops?
                    return stringify(value.*, options, out_stream);
                },
            },
            .Many, .Slice => {
                if (ptr_info.size == .Many and ptr_info.sentinel == null)
                    @compileError("unable to stringify type '" ++ @typeName(T) ++ "' without sentinel");
                const slice = if (ptr_info.size == .Many) mem.span(value) else value;

                if (ptr_info.child == u8 and options.string == .String and std.unicode.utf8ValidateSlice(slice)) {
                    try encodeJsonString(slice, options, out_stream);
                    return;
                }

                try out_stream.writeByte('[');
                var child_options = options;
                child_options.whitespace.indent_level += 1;
                for (slice, 0..) |x, i| {
                    if (i != 0) {
                        try out_stream.writeByte(',');
                    }
                    try child_options.whitespace.outputIndent(out_stream);
                    try stringify(x, child_options, out_stream);
                }
                if (slice.len != 0) {
                    try options.whitespace.outputIndent(out_stream);
                }
                try out_stream.writeByte(']');
                return;
            },
            else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
        },
        .Array => return stringify(&value, options, out_stream),
        .Vector => |info| {
            const array: [info.len]info.child = value;
            return stringify(&array, options, out_stream);
        },
        else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
    }
    unreachable;
}

// Same as `stringify` but accepts an Allocator and stores result in dynamically allocated memory instead of using a Writer.
// Caller owns returned memory.
pub fn stringifyAlloc(allocator: std.mem.Allocator, value: anytype, options: StringifyOptions) ![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();
    try stringify(value, options, list.writer());
    return list.toOwnedSlice();
}

test {
    _ = @import("./stringify_test.zig");
}
