const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const BitStack = std.BitStack;

const OBJECT_MODE = 0;
const ARRAY_MODE = 1;

pub const StringifyOptions = struct {
    /// Controls the whitespace emitted.
    /// The default `.minified` is a compact encoding with no whitespace between tokens.
    /// Any setting other than `.minified` will use newlines, indentation, and a space after each ':'.
    /// `.indent_1` means 1 space for each indentation level, `.indent_2` means 2 spaces, etc.
    /// `.indent_tab` uses a tab for each indentation level.
    whitespace: enum {
        minified,
        indent_1,
        indent_2,
        indent_3,
        indent_4,
        indent_8,
        indent_tab,
    } = .minified,

    /// Should optional fields with null value be written?
    emit_null_optional_fields: bool = true,

    /// Arrays/slices of u8 are typically encoded as JSON strings.
    /// This option emits them as arrays of numbers instead.
    /// Does not affect calls to `objectField*()`.
    emit_strings_as_arrays: bool = false,

    /// Should unicode characters be escaped in strings?
    escape_unicode: bool = false,

    /// When true, renders numbers outside the range `+-1<<53` (the precise integer range of f64) as JSON strings in base 10.
    emit_nonportable_numbers_as_strings: bool = false,
};

/// Writes the given value to the `std.io.Writer` stream.
/// See `WriteStream` for how the given value is serialized into JSON.
/// The maximum nesting depth of the output JSON document is 256.
/// See also `stringifyMaxDepth` and `stringifyArbitraryDepth`.
pub fn stringify(
    value: anytype,
    options: StringifyOptions,
    out_stream: anytype,
) @TypeOf(out_stream).Error!void {
    var jw = writeStream(out_stream, options);
    defer jw.deinit();
    try jw.write(value);
}

/// Like `stringify` with configurable nesting depth.
/// `max_depth` is rounded up to the nearest multiple of 8.
/// Give `null` for `max_depth` to disable some safety checks and allow arbitrary nesting depth.
/// See `writeStreamMaxDepth` for more info.
pub fn stringifyMaxDepth(
    value: anytype,
    options: StringifyOptions,
    out_stream: anytype,
    comptime max_depth: ?usize,
) @TypeOf(out_stream).Error!void {
    var jw = writeStreamMaxDepth(out_stream, options, max_depth);
    try jw.write(value);
}

/// Like `stringify` but takes an allocator to facilitate safety checks while allowing arbitrary nesting depth.
/// These safety checks can be helpful when debugging custom `jsonStringify` implementations;
/// See `WriteStream`.
pub fn stringifyArbitraryDepth(
    allocator: Allocator,
    value: anytype,
    options: StringifyOptions,
    out_stream: anytype,
) WriteStream(@TypeOf(out_stream), .checked_to_arbitrary_depth).Error!void {
    var jw = writeStreamArbitraryDepth(allocator, out_stream, options);
    defer jw.deinit();
    try jw.write(value);
}

/// Calls `stringifyArbitraryDepth` and stores the result in dynamically allocated memory
/// instead of taking a `std.io.Writer`.
///
/// Caller owns returned memory.
pub fn stringifyAlloc(
    allocator: Allocator,
    value: anytype,
    options: StringifyOptions,
) error{OutOfMemory}![]u8 {
    var list = std.ArrayList(u8).init(allocator);
    errdefer list.deinit();
    try stringifyArbitraryDepth(allocator, value, options, list.writer());
    return list.toOwnedSlice();
}

/// See `WriteStream` for documentation.
/// Equivalent to calling `writeStreamMaxDepth` with a depth of `256`.
///
/// The caller does *not* need to call `deinit()` on the returned object.
pub fn writeStream(
    out_stream: anytype,
    options: StringifyOptions,
) WriteStream(@TypeOf(out_stream), .{ .checked_to_fixed_depth = 256 }) {
    return writeStreamMaxDepth(out_stream, options, 256);
}

/// See `WriteStream` for documentation.
/// The returned object includes 1 bit of size per `max_depth` to enable safety checks on the order of method calls;
/// see the grammar in the `WriteStream` documentation.
/// `max_depth` is rounded up to the nearest multiple of 8.
/// If the nesting depth exceeds `max_depth`, it is detectable illegal behavior.
/// Give `null` for `max_depth` to disable safety checks for the grammar and allow arbitrary nesting depth.
/// In `ReleaseFast` and `ReleaseSmall`, `max_depth` is ignored, effectively equivalent to passing `null`.
/// Alternatively, see `writeStreamArbitraryDepth` to do safety checks to arbitrary depth.
///
/// The caller does *not* need to call `deinit()` on the returned object.
pub fn writeStreamMaxDepth(
    out_stream: anytype,
    options: StringifyOptions,
    comptime max_depth: ?usize,
) WriteStream(
    @TypeOf(out_stream),
    if (max_depth) |d| .{ .checked_to_fixed_depth = d } else .assumed_correct,
) {
    return WriteStream(
        @TypeOf(out_stream),
        if (max_depth) |d| .{ .checked_to_fixed_depth = d } else .assumed_correct,
    ).init(undefined, out_stream, options);
}

/// See `WriteStream` for documentation.
/// This version of the write stream enables safety checks to arbitrarily deep nesting levels
/// by using the given allocator.
/// The caller should call `deinit()` on the returned object to free allocated memory.
///
/// In `ReleaseFast` and `ReleaseSmall` mode, this function is effectively equivalent to calling `writeStreamMaxDepth(..., null)`;
/// in those build modes, the allocator is *not used*.
pub fn writeStreamArbitraryDepth(
    allocator: Allocator,
    out_stream: anytype,
    options: StringifyOptions,
) WriteStream(@TypeOf(out_stream), .checked_to_arbitrary_depth) {
    return WriteStream(@TypeOf(out_stream), .checked_to_arbitrary_depth).init(allocator, out_stream, options);
}

/// Writes JSON ([RFC8259](https://tools.ietf.org/html/rfc8259)) formatted data
/// to a stream.
///
/// The sequence of method calls to write JSON content must follow this grammar:
/// ```
///  <once> = <value>
///  <value> =
///    | <object>
///    | <array>
///    | write
///    | print
///  <object> = beginObject ( <field> <value> )* endObject
///  <field> = objectField | objectFieldRaw
///  <array> = beginArray ( <value> )* endArray
/// ```
///
/// Supported types:
///  * Zig `bool` -> JSON `true` or `false`.
///  * Zig `?T` -> `null` or the rendering of `T`.
///  * Zig `i32`, `u64`, etc. -> JSON number or string.
///      * When option `emit_nonportable_numbers_as_strings` is true, if the value is outside the range `+-1<<53` (the precise integer range of f64), it is rendered as a JSON string in base 10. Otherwise, it is rendered as JSON number.
///  * Zig floats -> JSON number or string.
///      * If the value cannot be precisely represented by an f64, it is rendered as a JSON string. Otherwise, it is rendered as JSON number.
///      * TODO: Float rendering will likely change in the future, e.g. to remove the unnecessary "e+00".
///  * Zig `[]const u8`, `[]u8`, `*[N]u8`, `@Vector(N, u8)`, and similar -> JSON string.
///      * See `StringifyOptions.emit_strings_as_arrays`.
///      * If the content is not valid UTF-8, rendered as an array of numbers instead.
///  * Zig `[]T`, `[N]T`, `*[N]T`, `@Vector(N, T)`, and similar -> JSON array of the rendering of each item.
///  * Zig tuple -> JSON array of the rendering of each item.
///  * Zig `struct` -> JSON object with each field in declaration order.
///      * If the struct declares a method `pub fn jsonStringify(self: *@This(), jw: anytype) !void`, it is called to do the serialization instead of the default behavior. The given `jw` is a pointer to this `WriteStream`. See `std.json.Value` for an example.
///      * See `StringifyOptions.emit_null_optional_fields`.
///  * Zig `union(enum)` -> JSON object with one field named for the active tag and a value representing the payload.
///      * If the payload is `void`, then the emitted value is `{}`.
///      * If the union declares a method `pub fn jsonStringify(self: *@This(), jw: anytype) !void`, it is called to do the serialization instead of the default behavior. The given `jw` is a pointer to this `WriteStream`.
///  * Zig `enum` -> JSON string naming the active tag.
///      * If the enum declares a method `pub fn jsonStringify(self: *@This(), jw: anytype) !void`, it is called to do the serialization instead of the default behavior. The given `jw` is a pointer to this `WriteStream`.
///  * Zig untyped enum literal -> JSON string naming the active tag.
///  * Zig error -> JSON string naming the error.
///  * Zig `*T` -> the rendering of `T`. Note there is no guard against circular-reference infinite recursion.
///
/// In `ReleaseFast` and `ReleaseSmall` mode, the given `safety_checks_hint` is ignored and is always treated as `.assumed_correct`.
pub fn WriteStream(
    comptime OutStream: type,
    comptime safety_checks_hint: union(enum) {
        checked_to_arbitrary_depth,
        checked_to_fixed_depth: usize, // Rounded up to the nearest multiple of 8.
        assumed_correct,
    },
) type {
    return struct {
        const Self = @This();
        const safety_checks: @TypeOf(safety_checks_hint) = switch (@import("builtin").mode) {
            .Debug, .ReleaseSafe => safety_checks_hint,
            .ReleaseFast, .ReleaseSmall => .assumed_correct,
        };

        pub const Stream = OutStream;
        pub const Error = switch (safety_checks) {
            .checked_to_arbitrary_depth => Stream.Error || error{OutOfMemory},
            .checked_to_fixed_depth, .assumed_correct => Stream.Error,
        };

        options: StringifyOptions,

        stream: OutStream,
        indent_level: usize = 0,
        next_punctuation: enum {
            the_beginning,
            none,
            comma,
            colon,
        } = .the_beginning,

        nesting_stack: switch (safety_checks) {
            .checked_to_arbitrary_depth => BitStack,
            .checked_to_fixed_depth => |fixed_buffer_size| [(fixed_buffer_size + 7) >> 3]u8,
            .assumed_correct => void,
        },

        pub fn init(safety_allocator: Allocator, stream: OutStream, options: StringifyOptions) Self {
            return .{
                .options = options,
                .stream = stream,
                .nesting_stack = switch (safety_checks) {
                    .checked_to_arbitrary_depth => BitStack.init(safety_allocator),
                    .checked_to_fixed_depth => |fixed_buffer_size| [_]u8{0} ** ((fixed_buffer_size + 7) >> 3),
                    .assumed_correct => {},
                },
            };
        }

        pub fn deinit(self: *Self) void {
            switch (safety_checks) {
                .checked_to_arbitrary_depth => self.nesting_stack.deinit(),
                .checked_to_fixed_depth, .assumed_correct => {},
            }
            self.* = undefined;
        }

        pub fn beginArray(self: *Self) Error!void {
            try self.valueStart();
            try self.stream.writeByte('[');
            try self.pushIndentation(ARRAY_MODE);
            self.next_punctuation = .none;
        }

        pub fn beginObject(self: *Self) Error!void {
            try self.valueStart();
            try self.stream.writeByte('{');
            try self.pushIndentation(OBJECT_MODE);
            self.next_punctuation = .none;
        }

        pub fn endArray(self: *Self) Error!void {
            self.popIndentation(ARRAY_MODE);
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
            self.popIndentation(OBJECT_MODE);
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

        fn pushIndentation(self: *Self, mode: u1) !void {
            switch (safety_checks) {
                .checked_to_arbitrary_depth => {
                    try self.nesting_stack.push(mode);
                    self.indent_level += 1;
                },
                .checked_to_fixed_depth => {
                    BitStack.pushWithStateAssumeCapacity(&self.nesting_stack, &self.indent_level, mode);
                },
                .assumed_correct => {
                    self.indent_level += 1;
                },
            }
        }
        fn popIndentation(self: *Self, assert_its_this_one: u1) void {
            switch (safety_checks) {
                .checked_to_arbitrary_depth => {
                    assert(self.nesting_stack.pop() == assert_its_this_one);
                    self.indent_level -= 1;
                },
                .checked_to_fixed_depth => {
                    assert(BitStack.popWithState(&self.nesting_stack, &self.indent_level) == assert_its_this_one);
                },
                .assumed_correct => {
                    self.indent_level -= 1;
                },
            }
        }

        fn indent(self: *Self) !void {
            var char: u8 = ' ';
            const n_chars = switch (self.options.whitespace) {
                .minified => return,
                .indent_1 => 1 * self.indent_level,
                .indent_2 => 2 * self.indent_level,
                .indent_3 => 3 * self.indent_level,
                .indent_4 => 4 * self.indent_level,
                .indent_8 => 8 * self.indent_level,
                .indent_tab => blk: {
                    char = '\t';
                    break :blk self.indent_level;
                },
            };
            try self.stream.writeByte('\n');
            try self.stream.writeByteNTimes(char, n_chars);
        }

        fn valueStart(self: *Self) !void {
            if (self.isObjectKeyExpected()) |is_it| assert(!is_it); // Call objectField*(), not write(), for object keys.
            return self.valueStartAssumeTypeOk();
        }
        fn objectFieldStart(self: *Self) !void {
            if (self.isObjectKeyExpected()) |is_it| assert(is_it); // Expected write(), not objectField*().
            return self.valueStartAssumeTypeOk();
        }
        fn valueStartAssumeTypeOk(self: *Self) !void {
            assert(!self.isComplete()); // JSON document already complete.
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
                    if (self.options.whitespace != .minified) {
                        try self.stream.writeByte(' ');
                    }
                },
            }
        }
        fn valueDone(self: *Self) void {
            self.next_punctuation = .comma;
        }

        // Only when safety is enabled:
        fn isObjectKeyExpected(self: *const Self) ?bool {
            switch (safety_checks) {
                .checked_to_arbitrary_depth => return self.indent_level > 0 and
                    self.nesting_stack.peek() == OBJECT_MODE and
                    self.next_punctuation != .colon,
                .checked_to_fixed_depth => return self.indent_level > 0 and
                    BitStack.peekWithState(&self.nesting_stack, self.indent_level) == OBJECT_MODE and
                    self.next_punctuation != .colon,
                .assumed_correct => return null,
            }
        }
        fn isComplete(self: *const Self) bool {
            return self.indent_level == 0 and self.next_punctuation == .comma;
        }

        /// An alternative to calling `write` that formats a value with `std.fmt`.
        /// This function does the usual punctuation and indentation formatting
        /// assuming the resulting formatted string represents a single complete value;
        /// e.g. `"1"`, `"[]"`, `"[1,2]"`, not `"1,2"`.
        /// This function may be useful for doing your own number formatting.
        pub fn print(self: *Self, comptime fmt: []const u8, args: anytype) Error!void {
            try self.valueStart();
            try self.stream.print(fmt, args);
            self.valueDone();
        }

        /// See `WriteStream` for when to call this method.
        /// `key` is the string content of the property name.
        /// Surrounding quotes will be added and any special characters will be escaped.
        /// See also `objectFieldRaw`.
        pub fn objectField(self: *Self, key: []const u8) Error!void {
            try self.objectFieldStart();
            try encodeJsonString(key, self.options, self.stream);
            self.next_punctuation = .colon;
        }
        /// See `WriteStream` for when to call this method.
        /// `quoted_key` is the complete bytes of the key including quotes and any necessary escape sequences.
        /// A few assertions are performed on the given value to ensure that the caller of this function understands the API contract.
        /// See also `objectField`.
        pub fn objectFieldRaw(self: *Self, quoted_key: []const u8) Error!void {
            assert(quoted_key.len >= 2 and quoted_key[0] == '"' and quoted_key[quoted_key.len - 1] == '"'); // quoted_key should be "quoted".
            try self.objectFieldStart();
            try self.stream.writeAll(quoted_key);
            self.next_punctuation = .colon;
        }

        /// See `WriteStream`.
        pub fn write(self: *Self, value: anytype) Error!void {
            const T = @TypeOf(value);
            switch (@typeInfo(T)) {
                .Int => {
                    try self.valueStart();
                    if (self.options.emit_nonportable_numbers_as_strings and
                        (value <= -(1 << 53) or value >= (1 << 53)))
                    {
                        try self.stream.print("\"{}\"", .{value});
                    } else {
                        try self.stream.print("{}", .{value});
                    }
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
                .Enum, .EnumLiteral => {
                    if (std.meta.hasFn(T, "jsonStringify")) {
                        return value.jsonStringify(self);
                    }

                    return self.stringValue(@tagName(value));
                },
                .Union => {
                    if (std.meta.hasFn(T, "jsonStringify")) {
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
                    if (std.meta.hasFn(T, "jsonStringify")) {
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
                .ErrorSet => return self.stringValue(@errorName(value)),
                .Pointer => |ptr_info| switch (ptr_info.size) {
                    .One => switch (@typeInfo(ptr_info.child)) {
                        .Array => {
                            // Coerce `*[N]T` to `[]const T`.
                            const Slice = []const std.meta.Elem(ptr_info.child);
                            return self.write(@as(Slice, value));
                        },
                        else => {
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
                                return self.stringValue(slice);
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

        fn stringValue(self: *Self, s: []const u8) !void {
            try self.valueStart();
            try encodeJsonString(s, self.options, self.stream);
            self.valueDone();
        }

        pub const arrayElem = @compileError("Deprecated; You don't need to call this anymore.");
        pub const emitNull = @compileError("Deprecated; Use .write(null) instead.");
        pub const emitBool = @compileError("Deprecated; Use .write() instead.");
        pub const emitNumber = @compileError("Deprecated; Use .write() instead.");
        pub const emitString = @compileError("Deprecated; Use .write() instead.");
        pub const emitJson = @compileError("Deprecated; Use .write() instead.");
        pub const writePreformatted = @compileError("Deprecated; Use .print(\"{s}\", .{s}) instead.");
    };
}

fn outputUnicodeEscape(codepoint: u21, out_stream: anytype) !void {
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

fn outputSpecialEscape(c: u8, writer: anytype) !void {
    switch (c) {
        '\\' => try writer.writeAll("\\\\"),
        '\"' => try writer.writeAll("\\\""),
        0x08 => try writer.writeAll("\\b"),
        0x0C => try writer.writeAll("\\f"),
        '\n' => try writer.writeAll("\\n"),
        '\r' => try writer.writeAll("\\r"),
        '\t' => try writer.writeAll("\\t"),
        else => try outputUnicodeEscape(c, writer),
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
    var write_cursor: usize = 0;
    var i: usize = 0;
    if (options.escape_unicode) {
        while (i < chars.len) : (i += 1) {
            switch (chars[i]) {
                // normal ascii character
                0x20...0x21, 0x23...0x5B, 0x5D...0x7E => {},
                0x00...0x1F, '\\', '\"' => {
                    // Always must escape these.
                    try writer.writeAll(chars[write_cursor..i]);
                    try outputSpecialEscape(chars[i], writer);
                    write_cursor = i + 1;
                },
                0x7F...0xFF => {
                    try writer.writeAll(chars[write_cursor..i]);
                    const ulen = std.unicode.utf8ByteSequenceLength(chars[i]) catch unreachable;
                    const codepoint = std.unicode.utf8Decode(chars[i..][0..ulen]) catch unreachable;
                    try outputUnicodeEscape(codepoint, writer);
                    i += ulen - 1;
                    write_cursor = i + 1;
                },
            }
        }
    } else {
        while (i < chars.len) : (i += 1) {
            switch (chars[i]) {
                // normal bytes
                0x20...0x21, 0x23...0x5B, 0x5D...0xFF => {},
                0x00...0x1F, '\\', '\"' => {
                    // Always must escape these.
                    try writer.writeAll(chars[write_cursor..i]);
                    try outputSpecialEscape(chars[i], writer);
                    write_cursor = i + 1;
                },
            }
        }
    }
    try writer.writeAll(chars[write_cursor..chars.len]);
}

test {
    _ = @import("./stringify_test.zig");
}
