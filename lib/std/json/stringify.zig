const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Value = @import("./dynamic.zig").Value;

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
    };

    /// Controls the whitespace emitted
    whitespace: Whitespace = .{ .indent = .none, .separator = false },

    /// Should optional fields with null value be written?
    emit_null_optional_fields: bool = true,

    emit_strings_as_arrays: bool = false,

    /// Should '/' be escaped in strings?
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
) WriteStream(@TypeOf(out_stream)).Error!void {
    var jw = writeStream(allocator, out_stream);
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

pub fn stringifyMaxDepth(
    value: anytype,
    options: StringifyOptions,
    out_stream: anytype,
    comptime max_depth: usize,
) WriteStream(@TypeOf(out_stream)).Error!void {
    var jw_stack = WriteStreamFixedStack(max_depth){};
    var jw = jw_stack.init(out_stream);
    jw.options = options;
    try jw.write(value);
}

pub fn WriteStreamFixedStack(comptime max_depth: usize) type {
    return struct {
        fixed_buffer_allocator: std.heap.FixedBufferAllocator = undefined,
        fixed_stack: [max_depth]u8 = undefined,

        pub fn init(self: *@This(), out_stream: anytype) WriteStream(@TypeOf(out_stream)) {
            self.fixed_buffer_allocator = std.heap.FixedBufferAllocator.init(self.fixed_stack[0..]);
            var jws = WriteStream(@TypeOf(out_stream)).init(self.fixed_buffer_allocator.allocator(), out_stream);
            jws.state_stack.ensureTotalCapacityPrecise(max_depth) catch unreachable;
            return jws;
        }
    };
}

pub fn writeStream(allocator: Allocator, out_stream: anytype) WriteStream(@TypeOf(out_stream)) {
    return WriteStream(@TypeOf(out_stream)).init(allocator, out_stream);
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
///  <object> = beginObject ( <string> <value> )* endObject
///  <array> = beginArray ( <value> )* endArray
///  <string> = <it's a <value> which must be just a string>
/// ```
pub fn WriteStream(comptime OutStream: type) type {
    return struct {
        const Self = @This();

        pub const Stream = OutStream;
        pub const Error = Stream.Error || error{OutOfMemory};

        // TODO: why is this the default?
        options: StringifyOptions = .{
            .whitespace = .{
                .indent = .{ .space = 1 },
            },
        },

        stream: OutStream,
        state_stack: ArrayList(State),
        is_complete: bool = false,

        pub fn init(allocator: Allocator, stream: OutStream) Self {
            return .{
                .stream = stream,
                .state_stack = ArrayList(State).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.state_stack.deinit();
            self.* = undefined;
        }

        pub fn beginArray(self: *Self) Error!void {
            try self.valueStart();
            try self.state_stack.append(.array_start);
            try self.stream.writeByte('[');
        }

        pub fn beginObject(self: *Self) Error!void {
            try self.valueStart();
            try self.state_stack.append(.object_start);
            try self.stream.writeByte('{');
        }

        pub fn endArray(self: *Self) Error!void {
            switch (self.state_stack.pop()) {
                .array_start => {},
                .array_post_value => {
                    try self.indent();
                },
                else => unreachable,
            }
            try self.stream.writeByte(']');
            self.valueDone();
        }

        pub fn endObject(self: *Self) Error!void {
            switch (self.state_stack.pop()) {
                .object_start => {},
                .object_post_value => {
                    try self.indent();
                },
                else => unreachable,
            }
            try self.stream.writeByte('}');
            self.valueDone();
        }

        fn indent(self: *Self) !void {
            const indent_level = self.options.whitespace.indent_level + self.state_stack.items.len;
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
            // Non-strings are banned as object keys.
            switch (self.state_stack.getLastOrNull() orelse .array_start) {
                .object_start, .object_post_value => unreachable, // Illegal object key type.
                else => {},
            }
            return self.valueStartAssumeTypeOk();
        }
        fn stringValueStart(self: *Self) !void {
            // Strings are allowed as values in every position.
            return self.valueStartAssumeTypeOk();
        }
        fn valueStartAssumeTypeOk(self: *Self) !void {
            assert(!self.is_complete); // JSON document already complete.
            if (self.state_stack.items.len == 0) return;
            switch (self.state_stack.getLast()) {
                .array_start, .object_start => {
                    // First item in the container.
                    try self.indent();
                },
                .array_post_value, .object_post_value => {
                    // Subsequent item in the container.
                    try self.stream.writeByte(',');
                    try self.indent();
                },
                .object_post_key => {
                    try self.stream.writeByte(':');
                    if (self.options.whitespace.separator) {
                        try self.stream.writeByte(' ');
                    }
                },
            }
        }
        fn valueDone(self: *Self) void {
            assert(!self.is_complete); // JSON document already complete.
            if (self.state_stack.items.len == 0) {
                // Done with everything.
                self.is_complete = true;
                return;
            }
            // Keep track of whether we need a comma, a colon, indentation, etc. the next time we output something.
            self.state_stack.items[self.state_stack.items.len - 1] = switch (self.state_stack.getLast()) {
                .array_start => .array_post_value,
                .array_post_value => return, // stay in the same state.
                .object_start => .object_post_key,
                .object_post_key => .object_post_value,
                .object_post_value => .object_post_key,
            };
        }

        /// TODO: docs
        pub fn writePreformatted(self: *Self, value_slice: []const u8) Error!void {
            try self.valueStart(); // TODO: is_string = value_slice.len > 0 and value_slice[0] == '"';
            try self.stream.writeAll(value_slice);
            self.valueDone();
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

                    try self.stringValueStart();
                    try encodeJsonString(@tagName(value), self.options, self.stream);
                    self.valueDone();
                    return;
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
                                try self.write(u_field.name);
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
                                try self.write(Field.name);
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
                            var render_as_string = !self.options.emit_strings_as_arrays;
                            switch (self.state_stack.getLastOrNull() orelse .array_start) {
                                .object_start, .object_post_value => {
                                    // Object keys must always be rendered as strings.
                                    render_as_string = true;
                                    assert(std.unicode.utf8ValidateSlice(slice)); // Object keys must be valid UTF-8 strings.
                                },
                                else => {
                                    // Fallback to array representation for non-UTF-8, even if .String mode was desired.
                                    render_as_string = render_as_string and std.unicode.utf8ValidateSlice(slice);
                                },
                            }
                            if (render_as_string) {
                                try self.stringValueStart();
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
        pub const objectField = @compileError("Deprecated; Call write() for object keys instead.");
        pub const emitNull = @compileError("Deprecated; Use .write(null) instead.");
        pub const emitBool = @compileError("Deprecated; Use .write() instead.");
        pub const emitNumber = @compileError("Deprecated; Use .write() instead.");
        pub const emitString = @compileError("Deprecated; Use .write() instead.");
        pub const emitJson = @compileError("Deprecated; Use .write() instead.");
    };
}

const State = enum(u8) {
    array_start,
    array_post_value,
    object_start,
    object_post_key,
    object_post_value,
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
            // TODO: option to switch between unicode and 'short' forms?
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
