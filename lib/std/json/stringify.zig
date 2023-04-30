
pub const StringifyOptions = struct {
    pub const Whitespace = struct {
        /// How many indentation levels deep are we?
        indent_level: usize = 0,

        /// What character(s) should be used for indentation?
        indent: union(enum) {
            Space: u8,
            Tab: void,
            None: void,
        } = .{ .Space = 4 },

        /// After a colon, should whitespace be inserted?
        separator: bool = true,

        pub fn outputIndent(
            whitespace: @This(),
            out_stream: anytype,
        ) @TypeOf(out_stream).Error!void {
            var char: u8 = undefined;
            var n_chars: usize = undefined;
            switch (whitespace.indent) {
                .Space => |n_spaces| {
                    char = ' ';
                    n_chars = n_spaces;
                },
                .Tab => {
                    char = '\t';
                    n_chars = 1;
                },
                .None => return,
            }
            try out_stream.writeByte('\n');
            n_chars *= whitespace.indent_level;
            try out_stream.writeByteNTimes(char, n_chars);
        }
    };

    /// Controls the whitespace emitted
    whitespace: ?Whitespace = null,

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
                    const codepoint = std.unicode.utf8Decode(chars[i .. i + ulen]) catch unreachable;
                    try outputUnicodeEscape(codepoint, writer);
                } else {
                    try writer.writeAll(chars[i .. i + ulen]);
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
                if (child_options.whitespace) |*whitespace| {
                    whitespace.indent_level += 1;
                }
                inline for (info.fields) |u_field| {
                    if (value == @field(UnionTagType, u_field.name)) {
                        if (child_options.whitespace) |child_whitespace| {
                            try child_whitespace.outputIndent(out_stream);
                        }
                        try encodeJsonString(u_field.name, options, out_stream);
                        try out_stream.writeByte(':');
                        if (child_options.whitespace) |child_whitespace| {
                            if (child_whitespace.separator) {
                                try out_stream.writeByte(' ');
                            }
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
                if (options.whitespace) |whitespace| {
                    try whitespace.outputIndent(out_stream);
                }
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
            if (child_options.whitespace) |*child_whitespace| {
                child_whitespace.indent_level += 1;
            }
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
                    if (child_options.whitespace) |child_whitespace| {
                        try child_whitespace.outputIndent(out_stream);
                    }
                    if (!S.is_tuple) {
                        try encodeJsonString(Field.name, options, out_stream);
                        try out_stream.writeByte(':');
                        if (child_options.whitespace) |child_whitespace| {
                            if (child_whitespace.separator) {
                                try out_stream.writeByte(' ');
                            }
                        }
                    }
                    try stringify(@field(value, Field.name), child_options, out_stream);
                }
            }
            if (field_output) {
                if (options.whitespace) |whitespace| {
                    try whitespace.outputIndent(out_stream);
                }
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
                if (child_options.whitespace) |*whitespace| {
                    whitespace.indent_level += 1;
                }
                for (slice, 0..) |x, i| {
                    if (i != 0) {
                        try out_stream.writeByte(',');
                    }
                    if (child_options.whitespace) |child_whitespace| {
                        try child_whitespace.outputIndent(out_stream);
                    }
                    try stringify(x, child_options, out_stream);
                }
                if (slice.len != 0) {
                    if (options.whitespace) |whitespace| {
                        try whitespace.outputIndent(out_stream);
                    }
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
    _ = @import("json/test.zig");
    _ = @import("json/scanner.zig");
    _ = @import("json/write_stream.zig");
    _ = @import("json/dynamic.zig");
}

const testing = std.testing;

test "stringify null optional fields" {
    const MyStruct = struct {
        optional: ?[]const u8 = null,
        required: []const u8 = "something",
        another_optional: ?[]const u8 = null,
        another_required: []const u8 = "something else",
    };
    try teststringify(
        \\{"optional":null,"required":"something","another_optional":null,"another_required":"something else"}
    ,
        MyStruct{},
        StringifyOptions{},
    );
    try teststringify(
        \\{"required":"something","another_required":"something else"}
    ,
        MyStruct{},
        StringifyOptions{ .emit_null_optional_fields = false },
    );
}

test "stringify basic types" {
    try teststringify("false", false, StringifyOptions{});
    try teststringify("true", true, StringifyOptions{});
    try teststringify("null", @as(?u8, null), StringifyOptions{});
    try teststringify("null", @as(?*u32, null), StringifyOptions{});
    try teststringify("42", 42, StringifyOptions{});
    try teststringify("4.2e+01", 42.0, StringifyOptions{});
    try teststringify("42", @as(u8, 42), StringifyOptions{});
    try teststringify("42", @as(u128, 42), StringifyOptions{});
    try teststringify("4.2e+01", @as(f32, 42), StringifyOptions{});
    try teststringify("4.2e+01", @as(f64, 42), StringifyOptions{});
    try teststringify("\"ItBroke\"", @as(anyerror, error.ItBroke), StringifyOptions{});
}

test "stringify string" {
    try teststringify("\"hello\"", "hello", StringifyOptions{});
    try teststringify("\"with\\nescapes\\r\"", "with\nescapes\r", StringifyOptions{});
    try teststringify("\"with\\nescapes\\r\"", "with\nescapes\r", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\\u0001\"", "with unicode\u{1}", StringifyOptions{});
    try teststringify("\"with unicode\\u0001\"", "with unicode\u{1}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{80}\"", "with unicode\u{80}", StringifyOptions{});
    try teststringify("\"with unicode\\u0080\"", "with unicode\u{80}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{FF}\"", "with unicode\u{FF}", StringifyOptions{});
    try teststringify("\"with unicode\\u00ff\"", "with unicode\u{FF}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{100}\"", "with unicode\u{100}", StringifyOptions{});
    try teststringify("\"with unicode\\u0100\"", "with unicode\u{100}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{800}\"", "with unicode\u{800}", StringifyOptions{});
    try teststringify("\"with unicode\\u0800\"", "with unicode\u{800}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{8000}\"", "with unicode\u{8000}", StringifyOptions{});
    try teststringify("\"with unicode\\u8000\"", "with unicode\u{8000}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{D799}\"", "with unicode\u{D799}", StringifyOptions{});
    try teststringify("\"with unicode\\ud799\"", "with unicode\u{D799}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{10000}\"", "with unicode\u{10000}", StringifyOptions{});
    try teststringify("\"with unicode\\ud800\\udc00\"", "with unicode\u{10000}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\u{10FFFF}\"", "with unicode\u{10FFFF}", StringifyOptions{});
    try teststringify("\"with unicode\\udbff\\udfff\"", "with unicode\u{10FFFF}", StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"/\"", "/", StringifyOptions{});
    try teststringify("\"\\/\"", "/", StringifyOptions{ .string = .{ .String = .{ .escape_solidus = true } } });
}

test "stringify many-item sentinel-terminated string" {
    try teststringify("\"hello\"", @as([*:0]const u8, "hello"), StringifyOptions{});
    try teststringify("\"with\\nescapes\\r\"", @as([*:0]const u8, "with\nescapes\r"), StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
    try teststringify("\"with unicode\\u0001\"", @as([*:0]const u8, "with unicode\u{1}"), StringifyOptions{ .string = .{ .String = .{ .escape_unicode = true } } });
}

test "stringify tagged unions" {
    const T = union(enum) {
        nothing,
        foo: u32,
        bar: bool,
    };
    try teststringify("{\"nothing\":{}}", T{ .nothing = {}}, StringifyOptions{});
    try teststringify("{\"foo\":42}", T{ .foo = 42 }, StringifyOptions{});
    try teststringify("{\"bar\":true}", T{ .bar = true }, StringifyOptions{});
}

test "stringify struct" {
    try teststringify("{\"foo\":42}", struct {
        foo: u32,
    }{ .foo = 42 }, StringifyOptions{});
}

test "stringify struct with string as array" {
    try teststringify("{\"foo\":\"bar\"}", .{ .foo = "bar" }, StringifyOptions{});
    try teststringify("{\"foo\":[98,97,114]}", .{ .foo = "bar" }, StringifyOptions{ .string = .Array });
}

test "stringify struct with indentation" {
    try teststringify(
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
        StringifyOptions{
            .whitespace = .{},
        },
    );
    try teststringify(
        "{\n\t\"foo\":42,\n\t\"bar\":[\n\t\t1,\n\t\t2,\n\t\t3\n\t]\n}",
        struct {
            foo: u32,
            bar: [3]u32,
        }{
            .foo = 42,
            .bar = .{ 1, 2, 3 },
        },
        StringifyOptions{
            .whitespace = .{
                .indent = .Tab,
                .separator = false,
            },
        },
    );
    try teststringify(
        \\{"foo":42,"bar":[1,2,3]}
    ,
        struct {
            foo: u32,
            bar: [3]u32,
        }{
            .foo = 42,
            .bar = .{ 1, 2, 3 },
        },
        StringifyOptions{
            .whitespace = .{
                .indent = .None,
                .separator = false,
            },
        },
    );
}

test "stringify struct with void field" {
    try teststringify("{\"foo\":42}", struct {
        foo: u32,
        bar: void = {},
    }{ .foo = 42 }, StringifyOptions{});
}

test "stringify array of structs" {
    const MyStruct = struct {
        foo: u32,
    };
    try teststringify("[{\"foo\":42},{\"foo\":100},{\"foo\":1000}]", [_]MyStruct{
        MyStruct{ .foo = 42 },
        MyStruct{ .foo = 100 },
        MyStruct{ .foo = 1000 },
    }, StringifyOptions{});
}

test "stringify struct with custom stringifier" {
    try teststringify("[\"something special\",42]", struct {
        foo: u32,
        const Self = @This();
        pub fn jsonStringify(
            value: Self,
            options: StringifyOptions,
            out_stream: anytype,
        ) !void {
            _ = value;
            try out_stream.writeAll("[\"something special\",");
            try stringify(42, options, out_stream);
            try out_stream.writeByte(']');
        }
    }{ .foo = 42 }, StringifyOptions{});
}

test "stringify vector" {
    try teststringify("[1,1]", @splat(2, @as(u32, 1)), StringifyOptions{});
}

test "stringify tuple" {
    try teststringify("[\"foo\",42]", std.meta.Tuple(&.{ []const u8, usize }){ "foo", 42 }, StringifyOptions{});
}

fn teststringify(expected: []const u8, value: anytype, options: StringifyOptions) !void {
    const ValidationWriter = struct {
        const Self = @This();
        pub const Writer = std.io.Writer(*Self, Error, write);
        pub const Error = error{
            TooMuchData,
            DifferentData,
        };

        expected_remaining: []const u8,

        fn init(exp: []const u8) Self {
            return .{ .expected_remaining = exp };
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        fn write(self: *Self, bytes: []const u8) Error!usize {
            if (self.expected_remaining.len < bytes.len) {
                std.debug.print(
                    \\====== expected this output: =========
                    \\{s}
                    \\======== instead found this: =========
                    \\{s}
                    \\======================================
                , .{
                    self.expected_remaining,
                    bytes,
                });
                return error.TooMuchData;
            }
            if (!mem.eql(u8, self.expected_remaining[0..bytes.len], bytes)) {
                std.debug.print(
                    \\====== expected this output: =========
                    \\{s}
                    \\======== instead found this: =========
                    \\{s}
                    \\======================================
                , .{
                    self.expected_remaining[0..bytes.len],
                    bytes,
                });
                return error.DifferentData;
            }
            self.expected_remaining = self.expected_remaining[bytes.len..];
            return bytes.len;
        }
    };

    var vos = ValidationWriter.init(expected);
    try stringify(value, options, vos.writer());
    if (vos.expected_remaining.len > 0) return error.NotEnoughData;
}

test "stringify struct with custom stringify that returns a custom error" {
    var ret = stringify(struct {
        field: Field = .{},

        pub const Field = struct {
            field: ?[]*Field = null,

            const Self = @This();
            pub fn jsonStringify(_: Self, _: StringifyOptions, _: anytype) error{CustomError}!void {
                return error.CustomError;
            }
        };
    }{}, StringifyOptions{}, std.io.null_writer);

    try std.testing.expectError(error.CustomError, ret);
}
