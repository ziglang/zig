//! Writes JSON ([RFC8259](https://tools.ietf.org/html/rfc8259)) formatted data
//! to a stream.
//!
//! The sequence of method calls to write JSON content must follow this grammar:
//! ```
//!  <once> = <value>
//!  <value> =
//!    | <object>
//!    | <array>
//!    | write
//!    | print
//!    | <writeRawStream>
//!  <object> = beginObject ( <field> <value> )* endObject
//!  <field> = objectField | objectFieldRaw | <objectFieldRawStream>
//!  <array> = beginArray ( <value> )* endArray
//!  <writeRawStream> = beginWriteRaw ( stream.writeAll )* endWriteRaw
//!  <objectFieldRawStream> = beginObjectFieldRaw ( stream.writeAll )* endObjectFieldRaw
//! ```

const std = @import("../std.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const BitStack = std.BitStack;
const Stringify = @This();

const IndentationMode = enum(u1) {
    object = 0,
    array = 1,
};

writer: *std.io.BufferedWriter,
options: Options = .{},
indent_level: usize = 0,
next_punctuation: enum {
    the_beginning,
    none,
    comma,
    colon,
} = .the_beginning,

nesting_stack: switch (safety_checks) {
    .checked_to_fixed_depth => |fixed_buffer_size| [(fixed_buffer_size + 7) >> 3]u8,
    .assumed_correct => void,
} = switch (safety_checks) {
    .checked_to_fixed_depth => @splat(0),
    .assumed_correct => {},
},

raw_streaming_mode: if (build_mode_has_safety)
    enum { none, value, objectField }
else
    void = if (build_mode_has_safety) .none else {},

const build_mode_has_safety = switch (@import("builtin").mode) {
    .Debug, .ReleaseSafe => true,
    .ReleaseFast, .ReleaseSmall => false,
};

/// The `safety_checks_hint` parameter determines how much memory is used to enable assertions that the above grammar is being followed,
/// e.g. tripping an assertion rather than allowing `endObject` to emit the final `}` in `[[[]]}`.
/// "Depth" in this context means the depth of nested `[]` or `{}` expressions
/// (or equivalently the amount of recursion on the `<value>` grammar expression above).
/// For example, emitting the JSON `[[[]]]` requires a depth of 3.
/// If `.checked_to_fixed_depth` is used, there is additionally an assertion that the nesting depth never exceeds the given limit.
/// `.checked_to_fixed_depth` embeds the storage required in the `Stringify` struct.
/// `.assumed_correct` requires no space and performs none of these assertions.
/// In `ReleaseFast` and `ReleaseSmall` mode, the given `safety_checks_hint` is ignored and is always treated as `.assumed_correct`.
const safety_checks_hint: union(enum) {
    /// Rounded up to the nearest multiple of 8.
    checked_to_fixed_depth: usize,
    assumed_correct,
} = .{ .checked_to_fixed_depth = 256 };

const safety_checks: @TypeOf(safety_checks_hint) = if (build_mode_has_safety)
    safety_checks_hint
else
    .assumed_correct;

pub fn beginArray(self: *Stringify) anyerror!void {
    if (build_mode_has_safety) assert(self.raw_streaming_mode == .none);
    try self.valueStart();
    try self.writer.writeByte('[');
    try self.pushIndentation(.array);
    self.next_punctuation = .none;
}

pub fn beginObject(self: *Stringify) anyerror!void {
    if (build_mode_has_safety) assert(self.raw_streaming_mode == .none);
    try self.valueStart();
    try self.writer.writeByte('{');
    try self.pushIndentation(.object);
    self.next_punctuation = .none;
}

pub fn endArray(self: *Stringify) anyerror!void {
    if (build_mode_has_safety) assert(self.raw_streaming_mode == .none);
    self.popIndentation(.array);
    switch (self.next_punctuation) {
        .none => {},
        .comma => {
            try self.indent();
        },
        .the_beginning, .colon => unreachable,
    }
    try self.writer.writeByte(']');
    self.valueDone();
}

pub fn endObject(self: *Stringify) anyerror!void {
    if (build_mode_has_safety) assert(self.raw_streaming_mode == .none);
    self.popIndentation(.object);
    switch (self.next_punctuation) {
        .none => {},
        .comma => {
            try self.indent();
        },
        .the_beginning, .colon => unreachable,
    }
    try self.writer.writeByte('}');
    self.valueDone();
}

fn pushIndentation(self: *Stringify, mode: IndentationMode) !void {
    switch (safety_checks) {
        .checked_to_fixed_depth => {
            BitStack.pushWithStateAssumeCapacity(&self.nesting_stack, &self.indent_level, @intFromEnum(mode));
        },
        .assumed_correct => {
            self.indent_level += 1;
        },
    }
}
fn popIndentation(self: *Stringify, expected_mode: IndentationMode) void {
    switch (safety_checks) {
        .checked_to_fixed_depth => {
            assert(BitStack.popWithState(&self.nesting_stack, &self.indent_level) == @intFromEnum(expected_mode));
        },
        .assumed_correct => {
            self.indent_level -= 1;
        },
    }
}

fn indent(self: *Stringify) !void {
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
    try self.writer.writeByte('\n');
    try self.writer.splatByteAll(char, n_chars);
}

fn valueStart(self: *Stringify) !void {
    if (self.isObjectKeyExpected()) |is_it| assert(!is_it); // Call objectField*(), not write(), for object keys.
    return self.valueStartAssumeTypeOk();
}
fn objectFieldStart(self: *Stringify) !void {
    if (self.isObjectKeyExpected()) |is_it| assert(is_it); // Expected write(), not objectField*().
    return self.valueStartAssumeTypeOk();
}
fn valueStartAssumeTypeOk(self: *Stringify) !void {
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
            try self.writer.writeByte(',');
            try self.indent();
        },
        .colon => {
            try self.writer.writeByte(':');
            if (self.options.whitespace != .minified) {
                try self.writer.writeByte(' ');
            }
        },
    }
}
fn valueDone(self: *Stringify) void {
    self.next_punctuation = .comma;
}

// Only when safety is enabled:
fn isObjectKeyExpected(self: *const Stringify) ?bool {
    switch (safety_checks) {
        .checked_to_fixed_depth => return self.indent_level > 0 and
            BitStack.peekWithState(&self.nesting_stack, self.indent_level) == @intFromEnum(IndentationMode.object) and
            self.next_punctuation != .colon,
        .assumed_correct => return null,
    }
}
fn isComplete(self: *const Stringify) bool {
    return self.indent_level == 0 and self.next_punctuation == .comma;
}

/// An alternative to calling `write` that formats a value with `std.fmt`.
/// This function does the usual punctuation and indentation formatting
/// assuming the resulting formatted string represents a single complete value;
/// e.g. `"1"`, `"[]"`, `"[1,2]"`, not `"1,2"`.
/// This function may be useful for doing your own number formatting.
pub fn print(self: *Stringify, comptime fmt: []const u8, args: anytype) anyerror!void {
    if (build_mode_has_safety) assert(self.raw_streaming_mode == .none);
    try self.valueStart();
    try self.writer.print(fmt, args);
    self.valueDone();
}

test print {
    var out_buf: [1024]u8 = undefined;
    var out: std.io.BufferedWriter = undefined;
    out.initFixed(&out_buf);

    var w: Stringify = .{ .writer = &out, .options = .{ .whitespace = .indent_2 } };

    try w.beginObject();
    try w.objectField("a");
    try w.print("[  ]", .{});
    try w.objectField("b");
    try w.beginArray();
    try w.print("[{s}] ", .{"[]"});
    try w.print("  {}", .{12345});
    try w.endArray();
    try w.endObject();

    const expected =
        \\{
        \\  "a": [  ],
        \\  "b": [
        \\    [[]] ,
        \\      12345
        \\  ]
        \\}
    ;
    try std.testing.expectEqualStrings(expected, out.getWritten());
}

/// An alternative to calling `write` that allows you to write directly to the `.writer` field, e.g. with `.writer.writeAll()`.
/// Call `beginWriteRaw()`, then write a complete value (including any quotes if necessary) directly to the `.writer` field,
/// then call `endWriteRaw()`.
/// This can be useful for streaming very long strings into the output without needing it all buffered in memory.
pub fn beginWriteRaw(self: *Stringify) !void {
    if (build_mode_has_safety) {
        assert(self.raw_streaming_mode == .none);
        self.raw_streaming_mode = .value;
    }
    try self.valueStart();
}

/// See `beginWriteRaw`.
pub fn endWriteRaw(self: *Stringify) void {
    if (build_mode_has_safety) {
        assert(self.raw_streaming_mode == .value);
        self.raw_streaming_mode = .none;
    }
    self.valueDone();
}

/// See `Stringify` for when to call this method.
/// `key` is the string content of the property name.
/// Surrounding quotes will be added and any special characters will be escaped.
/// See also `objectFieldRaw`.
pub fn objectField(self: *Stringify, key: []const u8) anyerror!void {
    if (build_mode_has_safety) assert(self.raw_streaming_mode == .none);
    try self.objectFieldStart();
    try encodeJsonString(key, self.options, self.writer);
    self.next_punctuation = .colon;
}
/// See `Stringify` for when to call this method.
/// `quoted_key` is the complete bytes of the key including quotes and any necessary escape sequences.
/// A few assertions are performed on the given value to ensure that the caller of this function understands the API contract.
/// See also `objectField`.
pub fn objectFieldRaw(self: *Stringify, quoted_key: []const u8) anyerror!void {
    if (build_mode_has_safety) assert(self.raw_streaming_mode == .none);
    assert(quoted_key.len >= 2 and quoted_key[0] == '"' and quoted_key[quoted_key.len - 1] == '"'); // quoted_key should be "quoted".
    try self.objectFieldStart();
    try self.writer.writeAll(quoted_key);
    self.next_punctuation = .colon;
}

/// In the rare case that you need to write very long object field names,
/// this is an alternative to `objectField` and `objectFieldRaw` that allows you to write directly to the `.writer` field
/// similar to `beginWriteRaw`.
/// Call `endObjectFieldRaw()` when you're done.
pub fn beginObjectFieldRaw(self: *Stringify) !void {
    if (build_mode_has_safety) {
        assert(self.raw_streaming_mode == .none);
        self.raw_streaming_mode = .objectField;
    }
    try self.objectFieldStart();
}

/// See `beginObjectFieldRaw`.
pub fn endObjectFieldRaw(self: *Stringify) void {
    if (build_mode_has_safety) {
        assert(self.raw_streaming_mode == .objectField);
        self.raw_streaming_mode = .none;
    }
    self.next_punctuation = .colon;
}

/// Renders the given Zig value as JSON.
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
///      * See `Options.emit_strings_as_arrays`.
///      * If the content is not valid UTF-8, rendered as an array of numbers instead.
///  * Zig `[]T`, `[N]T`, `*[N]T`, `@Vector(N, T)`, and similar -> JSON array of the rendering of each item.
///  * Zig tuple -> JSON array of the rendering of each item.
///  * Zig `struct` -> JSON object with each field in declaration order.
///      * If the struct declares a method `pub fn jsonStringify(self: *@This(), jw: anytype) !void`, it is called to do the serialization instead of the default behavior. The given `jw` is a pointer to this `Stringify`. See `std.json.Value` for an example.
///      * See `Options.emit_null_optional_fields`.
///  * Zig `union(enum)` -> JSON object with one field named for the active tag and a value representing the payload.
///      * If the payload is `void`, then the emitted value is `{}`.
///      * If the union declares a method `pub fn jsonStringify(self: *@This(), jw: anytype) !void`, it is called to do the serialization instead of the default behavior. The given `jw` is a pointer to this `Stringify`.
///  * Zig `enum` -> JSON string naming the active tag.
///      * If the enum declares a method `pub fn jsonStringify(self: *@This(), jw: anytype) !void`, it is called to do the serialization instead of the default behavior. The given `jw` is a pointer to this `Stringify`.
///      * If the enum is non-exhaustive, unnamed values are rendered as integers.
///  * Zig untyped enum literal -> JSON string naming the active tag.
///  * Zig error -> JSON string naming the error.
///  * Zig `*T` -> the rendering of `T`. Note there is no guard against circular-reference infinite recursion.
///
/// See also alternative functions `print` and `beginWriteRaw`.
/// For writing object field names, use `objectField` instead.
pub fn write(self: *Stringify, v: anytype) anyerror!void {
    if (build_mode_has_safety) assert(self.raw_streaming_mode == .none);
    const T = @TypeOf(v);
    switch (@typeInfo(T)) {
        .int => {
            try self.valueStart();
            if (self.options.emit_nonportable_numbers_as_strings and
                (v <= -(1 << 53) or v >= (1 << 53)))
            {
                try self.writer.print("\"{}\"", .{v});
            } else {
                try self.writer.print("{}", .{v});
            }
            self.valueDone();
            return;
        },
        .comptime_int => {
            return self.write(@as(std.math.IntFittingRange(v, v), v));
        },
        .float, .comptime_float => {
            if (@as(f64, @floatCast(v)) == v) {
                try self.valueStart();
                try self.writer.print("{}", .{@as(f64, @floatCast(v))});
                self.valueDone();
                return;
            }
            try self.valueStart();
            try self.writer.print("\"{}\"", .{v});
            self.valueDone();
            return;
        },

        .bool => {
            try self.valueStart();
            try self.writer.writeAll(if (v) "true" else "false");
            self.valueDone();
            return;
        },
        .null => {
            try self.valueStart();
            try self.writer.writeAll("null");
            self.valueDone();
            return;
        },
        .optional => {
            if (v) |payload| {
                return try self.write(payload);
            } else {
                return try self.write(null);
            }
        },
        .@"enum" => |enum_info| {
            if (std.meta.hasFn(T, "jsonStringify")) {
                return v.jsonStringify(self);
            }

            if (!enum_info.is_exhaustive) {
                inline for (enum_info.fields) |field| {
                    if (v == @field(T, field.name)) {
                        break;
                    }
                } else {
                    return self.write(@intFromEnum(v));
                }
            }

            return self.stringValue(@tagName(v));
        },
        .enum_literal => {
            return self.stringValue(@tagName(v));
        },
        .@"union" => {
            if (std.meta.hasFn(T, "jsonStringify")) {
                return v.jsonStringify(self);
            }

            const info = @typeInfo(T).@"union";
            if (info.tag_type) |UnionTagType| {
                try self.beginObject();
                inline for (info.fields) |u_field| {
                    if (v == @field(UnionTagType, u_field.name)) {
                        try self.objectField(u_field.name);
                        if (u_field.type == void) {
                            // void v is {}
                            try self.beginObject();
                            try self.endObject();
                        } else {
                            try self.write(@field(v, u_field.name));
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
        .@"struct" => |S| {
            if (std.meta.hasFn(T, "jsonStringify")) {
                return v.jsonStringify(self);
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
                if (@typeInfo(Field.type) == .optional) {
                    if (self.options.emit_null_optional_fields == false) {
                        if (@field(v, Field.name) == null) {
                            emit_field = false;
                        }
                    }
                }

                if (emit_field) {
                    if (!S.is_tuple) {
                        try self.objectField(Field.name);
                    }
                    try self.write(@field(v, Field.name));
                }
            }
            if (S.is_tuple) {
                try self.endArray();
            } else {
                try self.endObject();
            }
            return;
        },
        .error_set => return self.stringValue(@errorName(v)),
        .pointer => |ptr_info| switch (ptr_info.size) {
            .one => switch (@typeInfo(ptr_info.child)) {
                .array => {
                    // Coerce `*[N]T` to `[]const T`.
                    const Slice = []const std.meta.Elem(ptr_info.child);
                    return self.write(@as(Slice, v));
                },
                else => {
                    return self.write(v.*);
                },
            },
            .many, .slice => {
                if (ptr_info.size == .many and ptr_info.sentinel() == null)
                    @compileError("unable to stringify type '" ++ @typeName(T) ++ "' without sentinel");
                const slice = if (ptr_info.size == .many) std.mem.span(v) else v;

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
        .array => {
            // Coerce `[N]T` to `*const [N]T` (and then to `[]const T`).
            return self.write(&v);
        },
        .vector => |info| {
            const array: [info.len]info.child = v;
            return self.write(&array);
        },
        else => @compileError("Unable to stringify type '" ++ @typeName(T) ++ "'"),
    }
    unreachable;
}

fn stringValue(self: *Stringify, s: []const u8) !void {
    try self.valueStart();
    try encodeJsonString(s, self.options, self.writer);
    self.valueDone();
}

pub const Options = struct {
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

/// Writes the given value to the `std.io.Writer` writer.
/// See `Stringify` for how the given value is serialized into JSON.
/// The maximum nesting depth of the output JSON document is 256.
pub fn value(v: anytype, options: Options, writer: *std.io.BufferedWriter) anyerror!void {
    var s: Stringify = .{ .writer = writer, .options = options };
    try s.write(v);
}

test value {
    var out: std.io.AllocatingWriter = undefined;
    const writer = out.init(std.testing.allocator);
    defer out.deinit();

    const T = struct { a: i32, b: []const u8 };
    try value(T{ .a = 123, .b = "xy" }, .{}, writer);
    try std.testing.expectEqualSlices(u8, "{\"a\":123,\"b\":\"xy\"}", out.getWritten());

    try testStringify("9999999999999999", 9999999999999999, .{});
    try testStringify("\"9999999999999999\"", 9999999999999999, .{ .emit_nonportable_numbers_as_strings = true });

    try testStringify("[1,1]", @as(@Vector(2, u32), @splat(1)), .{});
    try testStringify("\"AA\"", @as(@Vector(2, u8), @splat('A')), .{});
    try testStringify("[65,65]", @as(@Vector(2, u8), @splat('A')), .{ .emit_strings_as_arrays = true });

    // void field
    try testStringify("{\"foo\":42}", struct {
        foo: u32,
        bar: void = {},
    }{ .foo = 42 }, .{});

    const Tuple = struct { []const u8, usize };
    try testStringify("[\"foo\",42]", Tuple{ "foo", 42 }, .{});

    comptime {
        testStringify("false", false, .{}) catch unreachable;
        const MyStruct = struct { foo: u32 };
        testStringify("[{\"foo\":42},{\"foo\":100},{\"foo\":1000}]", [_]MyStruct{
            MyStruct{ .foo = 42 },
            MyStruct{ .foo = 100 },
            MyStruct{ .foo = 1000 },
        }, .{}) catch unreachable;
    }
}

/// Calls `value` and stores the result in dynamically allocated memory instead
/// of taking a writer.
///
/// Caller owns returned memory.
pub fn valueAlloc(gpa: Allocator, v: anytype, options: Options) error{OutOfMemory}![]u8 {
    var aw: std.io.AllocatingWriter = undefined;
    const writer = aw.init(gpa);
    defer aw.deinit();
    value(v, options, writer) catch return error.OutOfMemory; // TODO: try @errorCast(...)
    return aw.toOwnedSlice();
}

test valueAlloc {
    const allocator = std.testing.allocator;
    const expected =
        \\{"foo":"bar","answer":42,"my_friend":"sammy"}
    ;
    const actual = try valueAlloc(allocator, .{ .foo = "bar", .answer = 42, .my_friend = "sammy" }, .{});
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

fn outputUnicodeEscape(codepoint: u21, bw: *std.io.BufferedWriter) anyerror!void {
    if (codepoint <= 0xFFFF) {
        // If the character is in the Basic Multilingual Plane (U+0000 through U+FFFF),
        // then it may be represented as a six-character sequence: a reverse solidus, followed
        // by the lowercase letter u, followed by four hexadecimal digits that encode the character's code point.
        try bw.writeAll("\\u");
        try bw.printInt("x", .{ .width = 4, .fill = '0' }, codepoint);
    } else {
        assert(codepoint <= 0x10FFFF);
        // To escape an extended character that is not in the Basic Multilingual Plane,
        // the character is represented as a 12-character sequence, encoding the UTF-16 surrogate pair.
        const high = @as(u16, @intCast((codepoint - 0x10000) >> 10)) + 0xD800;
        const low = @as(u16, @intCast(codepoint & 0x3FF)) + 0xDC00;
        try bw.writeAll("\\u");
        try bw.printInt("x", .{ .width = 4, .fill = '0' }, high);
        try bw.writeAll("\\u");
        try bw.printInt("x", .{ .width = 4, .fill = '0' }, low);
    }
}

fn outputSpecialEscape(c: u8, writer: *std.io.BufferedWriter) anyerror!void {
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
pub fn encodeJsonString(string: []const u8, options: Options, writer: *std.io.BufferedWriter) anyerror!void {
    try writer.writeByte('\"');
    try encodeJsonStringChars(string, options, writer);
    try writer.writeByte('\"');
}

/// Write `chars` to `writer` as JSON encoded string characters.
pub fn encodeJsonStringChars(chars: []const u8, options: Options, writer: *std.io.BufferedWriter) anyerror!void {
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

test "json write stream" {
    var out_buf: [1024]u8 = undefined;
    var out: std.io.BufferedWriter = undefined;
    out.initFixed(&out_buf);
    var w: Stringify = .{ .writer = &out, .options = .{ .whitespace = .indent_2 } };
    try testBasicWriteStream(&w);
}

fn testBasicWriteStream(w: *Stringify) anyerror!void {
    w.writer.reset();

    try w.beginObject();

    try w.objectField("object");
    var arena_allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena_allocator.deinit();
    try w.write(try getJsonObject(arena_allocator.allocator()));

    try w.objectFieldRaw("\"string\"");
    try w.write("This is a string");

    try w.objectField("array");
    try w.beginArray();
    try w.write("Another string");
    try w.write(@as(i32, 1));
    try w.write(@as(f32, 3.5));
    try w.endArray();

    try w.objectField("int");
    try w.write(@as(i32, 10));

    try w.objectField("float");
    try w.write(@as(f32, 3.5));

    try w.endObject();

    const expected =
        \\{
        \\  "object": {
        \\    "one": 1,
        \\    "two": 2e0
        \\  },
        \\  "string": "This is a string",
        \\  "array": [
        \\    "Another string",
        \\    1,
        \\    3.5e0
        \\  ],
        \\  "int": 10,
        \\  "float": 3.5e0
        \\}
    ;
    try std.testing.expectEqualStrings(expected, w.writer.getWritten());
}

fn getJsonObject(allocator: std.mem.Allocator) !std.json.Value {
    var v: std.json.Value = .{ .object = std.json.ObjectMap.init(allocator) };
    try v.object.put("one", std.json.Value{ .integer = @as(i64, @intCast(1)) });
    try v.object.put("two", std.json.Value{ .float = 2.0 });
    return v;
}

test "stringify null optional fields" {
    const MyStruct = struct {
        optional: ?[]const u8 = null,
        required: []const u8 = "something",
        another_optional: ?[]const u8 = null,
        another_required: []const u8 = "something else",
    };
    try testStringify(
        \\{"optional":null,"required":"something","another_optional":null,"another_required":"something else"}
    ,
        MyStruct{},
        .{},
    );
    try testStringify(
        \\{"required":"something","another_required":"something else"}
    ,
        MyStruct{},
        .{ .emit_null_optional_fields = false },
    );
}

test "stringify basic types" {
    try testStringify("false", false, .{});
    try testStringify("true", true, .{});
    try testStringify("null", @as(?u8, null), .{});
    try testStringify("null", @as(?*u32, null), .{});
    try testStringify("42", 42, .{});
    try testStringify("4.2e1", 42.0, .{});
    try testStringify("42", @as(u8, 42), .{});
    try testStringify("42", @as(u128, 42), .{});
    try testStringify("9999999999999999", 9999999999999999, .{});
    try testStringify("4.2e1", @as(f32, 42), .{});
    try testStringify("4.2e1", @as(f64, 42), .{});
    try testStringify("\"ItBroke\"", @as(anyerror, error.ItBroke), .{});
    try testStringify("\"ItBroke\"", error.ItBroke, .{});
}

test "stringify string" {
    try testStringify("\"hello\"", "hello", .{});
    try testStringify("\"with\\nescapes\\r\"", "with\nescapes\r", .{});
    try testStringify("\"with\\nescapes\\r\"", "with\nescapes\r", .{ .escape_unicode = true });
    try testStringify("\"with unicode\\u0001\"", "with unicode\u{1}", .{});
    try testStringify("\"with unicode\\u0001\"", "with unicode\u{1}", .{ .escape_unicode = true });
    try testStringify("\"with unicode\u{80}\"", "with unicode\u{80}", .{});
    try testStringify("\"with unicode\\u0080\"", "with unicode\u{80}", .{ .escape_unicode = true });
    try testStringify("\"with unicode\u{FF}\"", "with unicode\u{FF}", .{});
    try testStringify("\"with unicode\\u00ff\"", "with unicode\u{FF}", .{ .escape_unicode = true });
    try testStringify("\"with unicode\u{100}\"", "with unicode\u{100}", .{});
    try testStringify("\"with unicode\\u0100\"", "with unicode\u{100}", .{ .escape_unicode = true });
    try testStringify("\"with unicode\u{800}\"", "with unicode\u{800}", .{});
    try testStringify("\"with unicode\\u0800\"", "with unicode\u{800}", .{ .escape_unicode = true });
    try testStringify("\"with unicode\u{8000}\"", "with unicode\u{8000}", .{});
    try testStringify("\"with unicode\\u8000\"", "with unicode\u{8000}", .{ .escape_unicode = true });
    try testStringify("\"with unicode\u{D799}\"", "with unicode\u{D799}", .{});
    try testStringify("\"with unicode\\ud799\"", "with unicode\u{D799}", .{ .escape_unicode = true });
    try testStringify("\"with unicode\u{10000}\"", "with unicode\u{10000}", .{});
    try testStringify("\"with unicode\\ud800\\udc00\"", "with unicode\u{10000}", .{ .escape_unicode = true });
    try testStringify("\"with unicode\u{10FFFF}\"", "with unicode\u{10FFFF}", .{});
    try testStringify("\"with unicode\\udbff\\udfff\"", "with unicode\u{10FFFF}", .{ .escape_unicode = true });
}

test "stringify many-item sentinel-terminated string" {
    try testStringify("\"hello\"", @as([*:0]const u8, "hello"), .{});
    try testStringify("\"with\\nescapes\\r\"", @as([*:0]const u8, "with\nescapes\r"), .{ .escape_unicode = true });
    try testStringify("\"with unicode\\u0001\"", @as([*:0]const u8, "with unicode\u{1}"), .{ .escape_unicode = true });
}

test "stringify enums" {
    const E = enum {
        foo,
        bar,
    };
    try testStringify("\"foo\"", E.foo, .{});
    try testStringify("\"bar\"", E.bar, .{});
}

test "stringify non-exhaustive enum" {
    const E = enum(u8) {
        foo = 0,
        _,
    };
    try testStringify("\"foo\"", E.foo, .{});
    try testStringify("1", @as(E, @enumFromInt(1)), .{});
}

test "stringify enum literals" {
    try testStringify("\"foo\"", .foo, .{});
    try testStringify("\"bar\"", .bar, .{});
}

test "stringify tagged unions" {
    const T = union(enum) {
        nothing,
        foo: u32,
        bar: bool,
    };
    try testStringify("{\"nothing\":{}}", T{ .nothing = {} }, .{});
    try testStringify("{\"foo\":42}", T{ .foo = 42 }, .{});
    try testStringify("{\"bar\":true}", T{ .bar = true }, .{});
}

test "stringify struct" {
    try testStringify("{\"foo\":42}", struct {
        foo: u32,
    }{ .foo = 42 }, .{});
}

test "emit_strings_as_arrays" {
    // Should only affect string values, not object keys.
    try testStringify("{\"foo\":\"bar\"}", .{ .foo = "bar" }, .{});
    try testStringify("{\"foo\":[98,97,114]}", .{ .foo = "bar" }, .{ .emit_strings_as_arrays = true });
    // Should *not* affect these types:
    try testStringify("\"foo\"", @as(enum { foo, bar }, .foo), .{ .emit_strings_as_arrays = true });
    try testStringify("\"ItBroke\"", error.ItBroke, .{ .emit_strings_as_arrays = true });
    // Should work on these:
    try testStringify("\"bar\"", @Vector(3, u8){ 'b', 'a', 'r' }, .{});
    try testStringify("[98,97,114]", @Vector(3, u8){ 'b', 'a', 'r' }, .{ .emit_strings_as_arrays = true });
    try testStringify("\"bar\"", [3]u8{ 'b', 'a', 'r' }, .{});
    try testStringify("[98,97,114]", [3]u8{ 'b', 'a', 'r' }, .{ .emit_strings_as_arrays = true });
}

test "stringify struct with indentation" {
    try testStringify(
        \\{
        \\    "foo": 42,
        \\    "bar": [
        \\        1,
        \\        2,
        \\        3
        \\    ]
        \\}
    ,
        struct {
            foo: u32,
            bar: [3]u32,
        }{
            .foo = 42,
            .bar = .{ 1, 2, 3 },
        },
        .{ .whitespace = .indent_4 },
    );
    try testStringify(
        "{\n\t\"foo\": 42,\n\t\"bar\": [\n\t\t1,\n\t\t2,\n\t\t3\n\t]\n}",
        struct {
            foo: u32,
            bar: [3]u32,
        }{
            .foo = 42,
            .bar = .{ 1, 2, 3 },
        },
        .{ .whitespace = .indent_tab },
    );
    try testStringify(
        \\{"foo":42,"bar":[1,2,3]}
    ,
        struct {
            foo: u32,
            bar: [3]u32,
        }{
            .foo = 42,
            .bar = .{ 1, 2, 3 },
        },
        .{ .whitespace = .minified },
    );
}

test "stringify array of structs" {
    const MyStruct = struct {
        foo: u32,
    };
    try testStringify("[{\"foo\":42},{\"foo\":100},{\"foo\":1000}]", [_]MyStruct{
        MyStruct{ .foo = 42 },
        MyStruct{ .foo = 100 },
        MyStruct{ .foo = 1000 },
    }, .{});
}

test "stringify struct with custom stringifier" {
    try testStringify("[\"something special\",42]", struct {
        foo: u32,
        const Self = @This();
        pub fn jsonStringify(v: @This(), jws: anytype) !void {
            _ = v;
            try jws.beginArray();
            try jws.write("something special");
            try jws.write(42);
            try jws.endArray();
        }
    }{ .foo = 42 }, .{});
}

fn testStringify(expected: []const u8, v: anytype, options: Options) !void {
    var buffer: [4096]u8 = undefined;
    var bw: std.io.BufferedWriter = undefined;
    bw.initFixed(&buffer);
    try value(v, options, &bw);
    try std.testing.expectEqualStrings(expected, bw.getWritten());
}

test "raw streaming" {
    var out_buf: [1024]u8 = undefined;
    var out: std.io.BufferedWriter = undefined;
    out.initFixed(&out_buf);

    var w: Stringify = .{ .writer = &out, .options = .{ .whitespace = .indent_2 } };
    try w.beginObject();
    try w.beginObjectFieldRaw();
    try w.writer.writeAll("\"long");
    try w.writer.writeAll(" key\"");
    w.endObjectFieldRaw();
    try w.beginWriteRaw();
    try w.writer.writeAll("\"long");
    try w.writer.writeAll(" value\"");
    w.endWriteRaw();
    try w.endObject();

    const expected =
        \\{
        \\  "long key": "long value"
        \\}
    ;
    try std.testing.expectEqualStrings(expected, w.writer.getWritten());
}
