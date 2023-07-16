const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Value = @import("./dynamic.zig").Value;
const BitStack = @import("scanner.zig").BitStack;
const OBJECT_MODE = @import("scanner.zig").OBJECT_MODE;
const ARRAY_MODE = @import("scanner.zig").ARRAY_MODE;

pub const StringifyOptions = struct {
    pub const Whitespace = struct {
        /// Additional levels of indentation to prefix every line.
        indent_level: usize = 0,

        /// What character(s) should be used for indentation?
        indent: union(enum) {
            space: u8,
            tab: void,
            none: void,
        } = .{ .space = 4 },

        /// After a colon, should whitespace be inserted?
        separator: bool = true,
    };

    /// Controls the whitespace emitted
    whitespace: Whitespace = .{ .indent = .none, .separator = false },

    /// Should optional fields with null value be written?
    emit_null_optional_fields: bool = true,

    /// Arrays/slices of u8 are typically encoded as JSON strings.
    /// This option emits them as arrays of numbers instead.
    /// Does not affect calls to objectField().
    emit_strings_as_arrays: bool = false,

    /// Should '/' be escaped in strings?
    /// TODO: Remove this option.
    escape_solidus: bool = false,

    /// Should unicode characters be escaped in strings?
    escape_unicode: bool = false,
};

/// If `value` has a method called `jsonStringify`, this will call that method instead of the
/// default implementation, passing it the `options` and `out_stream` parameters.
pub fn stringify(
    allocator: Allocator,
    value: anytype,
    options: StringifyOptions,
    out_stream: anytype,
) WriteStream(@TypeOf(out_stream), .safe).Error!void {
    var jw = writeStream(allocator, out_stream);
    defer jw.deinit();
    jw.options = options;
    try jw.write(value);
}

// TODO: docs
pub fn stringifyUnsafe(
    value: anytype,
    options: StringifyOptions,
    out_stream: anytype,
) WriteStream(@TypeOf(out_stream), .unsafe).Error!void {
    var jw = writeStreamUnsafe(out_stream);
    defer jw.deinit();
    jw.options = options;
    try jw.write(value);
}

// Same as `stringify` but accepts an Allocator and stores result in dynamically allocated memory instead of using a Writer.
// Caller owns returned memory.
pub fn stringifyAlloc(
    allocator: Allocator,
    value: anytype,
    options: StringifyOptions,
) error{OutOfMemory}![]const u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();
    try stringify(allocator, value, options, list.writer());
    return list.toOwnedSlice();
}

// TODO: docs
pub fn writeStream(allocator: Allocator, out_stream: anytype) WriteStream(@TypeOf(out_stream), .safe) {
    return WriteStream(@TypeOf(out_stream), .safe).init(allocator, out_stream);
}

// TODO: docs
pub fn writeStreamUnsafe(out_stream: anytype) WriteStream(@TypeOf(out_stream), .unsafe) {
    return WriteStream(@TypeOf(out_stream), .unsafe).init(undefined, out_stream);
}

/// Writes JSON ([RFC8259](https://tools.ietf.org/html/rfc8259)) formatted data
/// to a stream.
///
/// The seqeunce of method calls to write JSON content must follow this grammar:
/// ```
///  <once> = <value>
///  <value> =
///    | <object>
///    | <array>
///    | write
///    | writePreformatted
///  <object> = beginObject ( objectField <value> )* endObject
///  <array> = beginArray ( <value> )* endArray
/// ```
pub fn WriteStream(comptime OutStream: type, comptime safety_mode: enum { safe, unsafe }) type {
    return struct {
        const enable_safety = safety_mode == .safe;
        const Self = @This();

        pub const Stream = OutStream;
        pub const Error = if (enable_safety) Stream.Error || error{OutOfMemory} else Stream.Error;

        // TODO: why is this the default?
        options: StringifyOptions = .{
            .whitespace = .{
                .indent = .{ .space = 1 },
            },
        },

        stream: OutStream,
        nesting_stack: if (enable_safety) BitStack else void,
        is_complete: if (enable_safety) bool else void = if (enable_safety) false else {},
        next_punctuation: enum {
            the_beginning,
            none,
            comma,
            colon,
        } = .the_beginning,

        pub fn init(safety_allocator: Allocator, stream: OutStream) Self {
            return .{
                .stream = stream,
                .nesting_stack = if (enable_safety) BitStack.init(safety_allocator) else {},
            };
        }

        pub fn deinit(self: *Self) void {
            if (enable_safety) self.nesting_stack.deinit();
            self.* = undefined;
        }

        pub fn beginArray(self: *Self) Error!void {
            try self.valueStart();
            try self.stream.writeByte('[');
            if (enable_safety) try self.nesting_stack.push(ARRAY_MODE);
            self.options.whitespace.indent_level += 1;
            self.next_punctuation = .none;
        }

        pub fn beginObject(self: *Self) Error!void {
            try self.valueStart();
            try self.stream.writeByte('{');
            if (enable_safety) try self.nesting_stack.push(OBJECT_MODE);
            self.options.whitespace.indent_level += 1;
            self.next_punctuation = .none;
        }

        pub fn endArray(self: *Self) Error!void {
            if (enable_safety) assert(self.nesting_stack.pop() == ARRAY_MODE);
            self.options.whitespace.indent_level -= 1;
            switch (self.next_punctuation) {
                .none => {},
                .comma => {
                    try self.indent();
                },
                .the_beginning, .colon => unreachable,
            }
            try self.stream.writeByte(']');
            self.valueDone();
        }

        pub fn endObject(self: *Self) Error!void {
            if (enable_safety) assert(self.nesting_stack.pop() == OBJECT_MODE);
            self.options.whitespace.indent_level -= 1;
            switch (self.next_punctuation) {
                .none => {},
                .comma => {
                    try self.indent();
                },
                .the_beginning, .colon => unreachable,
            }
            try self.stream.writeByte('}');
            self.valueDone();
        }

        fn indent(self: *Self) !void {
            const indent_level = self.options.whitespace.indent_level;
            var char: u8 = undefined;
            var n_chars: usize = undefined;
            switch (self.options.whitespace.indent) {
                .space => |n_spaces| {
                    char = ' ';
                    n_chars = n_spaces * indent_level;
                },
                .tab => {
                    char = '\t';
                    n_chars = indent_level;
                },
                .none => return,
            }
            try self.stream.writeByte('\n');
            try self.stream.writeByteNTimes(char, n_chars);
        }

        fn valueStart(self: *Self) !void {
            if (enable_safety) assert(!self.expectObjectKey()); // Call objectField(), not write(), for object keys.
            return self.valueStartAssumeTypeOk();
        }
        fn objectFieldStart(self: *Self) !void {
            if (enable_safety) assert(self.expectObjectKey()); // Expected write(), not objectField().
            return self.valueStartAssumeTypeOk();
        }
        fn valueStartAssumeTypeOk(self: *Self) !void {
            if (enable_safety) assert(!self.is_complete); // JSON document already complete.
            switch (self.next_punctuation) {
                .the_beginning => {
                    // No indentation for the very beginning.
                },
                .none => {
                    // First item in a container.
                    try self.indent();
                },
                .comma => {
                    // Subsequent item in a container.
                    try self.stream.writeByte(',');
                    try self.indent();
                },
                .colon => {
                    try self.stream.writeByte(':');
                    if (self.options.whitespace.separator) {
                        try self.stream.writeByte(' ');
                    }
                },
            }
        }
        fn valueDone(self: *Self) void {
            if (enable_safety and self.nesting_stack.bit_len == 0) {
                // Done with everything.
                self.is_complete = true;
            }
            self.next_punctuation = .comma;
        }
        fn expectObjectKey(self: *const Self) bool {
            return self.nesting_stack.bit_len > 0 and self.nesting_stack.peek() == OBJECT_MODE and self.next_punctuation != .colon;
        }

        /// TODO: docs
        pub fn writePreformatted(self: *Self, value_slice: []const u8) Error!void {
            try self.valueStart();
            try self.stream.writeAll(value_slice);
            self.valueDone();
        }

        pub fn objectField(self: *Self, key: []const u8) Error!void {
            try self.objectFieldStart();
            try encodeJsonString(key, self.options, self.stream);
            self.next_punctuation = .colon;
        }

        /// Supported types:
        ///
        /// Number: An integer, float, or `std.math.BigInt`. Emitted as a bare number if it fits losslessly
        /// in a IEEE 754 double float, otherwise emitted as a string to the full precision.
        ///
        /// TODO: more docs.
        pub fn write(self: *Self, value: anytype) Error!void {
            const T = @TypeOf(value);
            switch (@typeInfo(T)) {
                .Int => |info| {
                    if (info.bits < 53) {
                        try self.valueStart();
                        try self.stream.print("{}", .{value});
                        self.valueDone();
                        return;
                    }
                    if (value < 4503599627370496 and (info.signedness == .unsigned or value > -4503599627370496)) {
                        try self.valueStart();
                        try self.stream.print("{}", .{value});
                        self.valueDone();
                        return;
                    }
                    try self.valueStart();
                    try self.stream.print("\"{}\"", .{value});
                    self.valueDone();
                    return;
                },
                .ComptimeInt => {
                    return self.write(@as(std.math.IntFittingRange(value, value), value));
                },
                .Float, .ComptimeFloat => {
                    if (@as(f64, @floatCast(value)) == value) {
                        try self.valueStart();
                        try self.stream.print("{}", .{@as(f64, @floatCast(value))});
                        self.valueDone();
                        return;
                    }
                    try self.valueStart();
                    try self.stream.print("\"{}\"", .{value});
                    self.valueDone();
                    return;
                },

                .Bool => {
                    try self.valueStart();
                    try self.stream.writeAll(if (value) "true" else "false");
                    self.valueDone();
                    return;
                },
                .Null => {
                    try self.valueStart();
                    try self.stream.writeAll("null");
                    self.valueDone();
                    return;
                },
                .Optional => {
                    if (value) |payload| {
                        return try self.write(payload);
                    } else {
                        return try self.write(null);
                    }
                },
                .Enum => {
                    if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                        return value.jsonStringify(self);
                    }

                    return self.write(@tagName(value));
                },
                .Union => {
                    if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                        return value.jsonStringify(self);
                    }

                    const info = @typeInfo(T).Union;
                    if (info.tag_type) |UnionTagType| {
                        try self.beginObject();
                        inline for (info.fields) |u_field| {
                            if (value == @field(UnionTagType, u_field.name)) {
                                try self.objectField(u_field.name);
                                if (u_field.type == void) {
                                    // void value is {}
                                    try self.beginObject();
                                    try self.endObject();
                                } else {
                                    try self.write(@field(value, u_field.name));
                                }
                                break;
                            }
                        } else {
                            unreachable; // No active tag?
                        }
                        try self.endObject();
                        return;
                    } else {
                        @compileError("Unable to stringify untagged union '" ++ @typeName(T) ++ "'");
                    }
                },
                .Struct => |S| {
                    if (comptime std.meta.trait.hasFn("jsonStringify")(T)) {
                        return value.jsonStringify(self);
                    }

                    if (S.is_tuple) {
                        try self.beginArray();
                    } else {
                        try self.beginObject();
                    }
                    inline for (S.fields) |Field| {
                        // don't include void fields
                        if (Field.type == void) continue;

                        var emit_field = true;

                        // don't include optional fields that are null when emit_null_optional_fields is set to false
                        if (@typeInfo(Field.type) == .Optional) {
                            if (self.options.emit_null_optional_fields == false) {
                                if (@field(value, Field.name) == null) {
                                    emit_field = false;
                                }
                            }
                        }

                        if (emit_field) {
                            if (!S.is_tuple) {
                                try self.objectField(Field.name);
                            }
                            try self.write(@field(value, Field.name));
                        }
                    }
                    if (S.is_tuple) {
                        try self.endArray();
                    } else {
                        try self.endObject();
                    }
                    return;
                },
                .ErrorSet => return self.write(@as([]const u8, @errorName(value))),
                .Pointer => |ptr_info| switch (ptr_info.size) {
                    .One => switch (@typeInfo(ptr_info.child)) {
                        .Array => {
                            // Coerce `*[N]T` to `[]const T`.
                            const Slice = []const std.meta.Elem(ptr_info.child);
                            return self.write(@as(Slice, value));
                        },
                        else => {
                            // TODO: avoid loops?
                            return self.write(value.*);
                        },
                    },
                    .Many, .Slice => {
                        if (ptr_info.size == .Many and ptr_info.sentinel == null)
                            @compileError("unable to stringify type '" ++ @typeName(T) ++ "' without sentinel");
                        const slice = if (ptr_info.size == .Many) std.mem.span(value) else value;

                        if (ptr_info.child == u8) {
                            // This is a []const u8, or some similar Zig string.
                            if (!self.options.emit_strings_as_arrays and std.unicode.utf8ValidateSlice(slice)) {
                                try self.valueStart();
                                try encodeJsonString(slice, self.options, self.stream);
                                self.valueDone();
                                return;
                            }
                        }

                        try self.beginArray();
                        for (slice) |x| {
                            try self.write(x);
                        }
                        try self.endArray();
                        return;
                    },
                    else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
                },
                .Array => {
                    // Coerce `[N]T` to `*const [N]T` (and then to `[]const T`).
                    return self.write(&value);
                },
                .Vector => |info| {
                    const array: [info.len]info.child = value;
                    return self.write(&array);
                },
                else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
            }
            unreachable;
        }

        pub const arrayElem = @compileError("Deprecated; You don't need to call this anymore.");
        pub const emitNull = @compileError("Deprecated; Use .write(null) instead.");
        pub const emitBool = @compileError("Deprecated; Use .write() instead.");
        pub const emitNumber = @compileError("Deprecated; Use .write() instead.");
        pub const emitString = @compileError("Deprecated; Use .write() instead.");
        pub const emitJson = @compileError("Deprecated; Use .write() instead.");
    };
}

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
        const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xD800;
        const low = @as(u16, @intCast(codepoint & 0x3FF)) + 0xDC00;
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
                if (options.escape_solidus) {
                    try writer.writeAll("\\/");
                } else {
                    try writer.writeByte('/');
                }
            },
            // control characters with short escapes
            0x8 => try writer.writeAll("\\b"),
            0xC => try writer.writeAll("\\f"),
            '\n' => try writer.writeAll("\\n"),
            '\r' => try writer.writeAll("\\r"),
            '\t' => try writer.writeAll("\\t"),
            else => {
                const ulen = std.unicode.utf8ByteSequenceLength(chars[i]) catch unreachable;
                // control characters (only things left with 1 byte length) should always be printed as unicode escapes
                if (ulen == 1 or options.escape_unicode) {
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

test {
    _ = @import("./stringify_test.zig");
}
