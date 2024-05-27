const std = @import("std");

/// Configuration for stringification.
///
/// See `StringifyOptions` for more details.
pub const StringifierOptions = struct {
    /// If false, only syntactically necessary whitespace is emitted.
    whitespace: bool = true,
};

/// Options for stringification of an individual value.
///
/// See `StringifyOptions` for more details.
pub const StringifyValueOptions = struct {
    emit_utf8_codepoints: bool = false,
    emit_strings_as_containers: bool = false,
    emit_default_optional_fields: bool = true,
};

/// All stringify options.
pub const StringifyOptions = struct {
    /// If false, all whitespace is emitted. Otherwise, whitespace is emitted in the standard Zig
    /// style when possible.
    whitespace: bool = true,
    /// If true, unsigned integers with <= 21 bits are written as their corresponding UTF8 codepoint
    /// instead of a numeric literal if one exists.
    emit_utf8_codepoints: bool = false,
    /// If true, slices of u8s, and pointers to arrays of u8s are serialized as containers.
    /// Otherwise they are serialized as string literals.
    emit_strings_as_containers: bool = false,
    /// If false, struct fields are not written if they are equal to their default value. Comparison
    /// is done by `std.meta.eql`.
    emit_default_optional_fields: bool = true,
};

/// Options for manual serializaation of container types.
pub const StringifyContainerOptions = struct {
    /// The whitespace style that should be used for this container. Ignored if whitespace is off.
    whitespace_style: union(enum) {
        /// If true, wrap every field/item. If false do not.
        wrap: bool,
        /// Automatically decide whether to wrap or not based on the number of fields. Following
        /// the standard rule of thumb, containers with more than two fields are wrapped.
        fields: usize,
    } = .{ .wrap = true },

    fn shouldWrap(self: StringifyContainerOptions) bool {
        return switch (self.whitespace_style) {
            .wrap => |wrap| wrap,
            .fields => |fields| fields > 2,
        };
    }
};

/// Serialize the given value to ZON.
///
/// It is asserted at comptime that `@TypeOf(val)` is not a recursive type.
pub fn stringify(
    /// The value to serialize. May only transitively contain the following supported types:
    /// * bools
    /// * fixed sized numeric types
    /// * exhaustive enums, enum literals
    ///     * Non-exhaustive enums may hold values that have no literal representation, and
    ///       therefore cannot be stringified in a way that allows round trips back through the
    ///       parser. There are plans to resolve this in the future.
    /// * slices
    /// * arrays
    /// * structures
    /// * tagged unions
    /// * optionals
    /// * null
    val: anytype,
    comptime options: StringifyOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    var serializer = stringifier(writer, .{
        .whitespace = options.whitespace,
    });
    try serializer.value(val, .{
        .emit_utf8_codepoints = options.emit_utf8_codepoints,
        .emit_strings_as_containers = options.emit_strings_as_containers,
        .emit_default_optional_fields = options.emit_default_optional_fields,
    });
}

/// Like `stringify`, but recursive types are allowed.
///
/// Returns `error.MaxDepth` if `depth` is exceeded.
pub fn stringifyMaxDepth(val: anytype, comptime options: StringifyOptions, writer: anytype, depth: usize) Stringifier(@TypeOf(writer)).MaxDepthError!void {
    var serializer = stringifier(writer, .{
        .whitespace = options.whitespace,
    });
    try serializer.valueMaxDepth(val, .{
        .emit_utf8_codepoints = options.emit_utf8_codepoints,
        .emit_strings_as_containers = options.emit_strings_as_containers,
        .emit_default_optional_fields = options.emit_default_optional_fields,
    }, depth);
}

/// Like `stringify`, but recursive types are allowed.
///
/// It is the caller's responsibility to ensure that `val` does not contain cycles.
pub fn stringifyArbitraryDepth(val: anytype, comptime options: StringifyOptions, writer: anytype) @TypeOf(writer).Error!void {
    var serializer = stringifier(writer, .{
        .whitespace = options.whitespace,
    });
    try serializer.valueArbitraryDepth(val, .{
        .emit_utf8_codepoints = options.emit_utf8_codepoints,
        .emit_strings_as_containers = options.emit_strings_as_containers,
        .emit_default_optional_fields = options.emit_default_optional_fields,
    });
}

const RecursiveTypeBuffer = [32]type;

fn typeIsRecursive(comptime T: type) bool {
    comptime var buf: RecursiveTypeBuffer = undefined;
    return comptime typeIsRecursiveImpl(T, buf[0..0]);
}

fn typeIsRecursiveImpl(comptime T: type, comptime visited_arg: []type) bool {
    comptime var visited = visited_arg;

    // Check if we've already seen this type
    inline for (visited) |found| {
        if (T == found) {
            return true;
        }
    }

    // Add this type to the stack
    if (visited.len >= @typeInfo(RecursiveTypeBuffer).Array.len) {
        @compileError("recursion limit");
    }
    visited.ptr[visited.len] = T;
    visited.len += 1;

    // Recurse
    switch (@typeInfo(T)) {
        .Pointer => |Pointer| return typeIsRecursiveImpl(Pointer.child, visited),
        .Array => |Array| return typeIsRecursiveImpl(Array.child, visited),
        .Struct => |Struct| inline for (Struct.fields) |field| {
            if (typeIsRecursiveImpl(field.type, visited)) {
                return true;
            }
        },
        .Union => |Union| inline for (Union.fields) |field| {
            if (typeIsRecursiveImpl(field.type, visited)) {
                return true;
            }
        },
        .Optional => |Optional| return typeIsRecursiveImpl(Optional.child, visited),
        else => {},
    }
    return false;
}

test "typeIsRecursive" {
    try std.testing.expect(!typeIsRecursive(bool));
    try std.testing.expect(!typeIsRecursive(struct { x: i32, y: i32 }));
    try std.testing.expect(!typeIsRecursive(struct { i32, i32 }));
    try std.testing.expect(typeIsRecursive(struct { x: i32, y: i32, z: *@This() }));
    try std.testing.expect(typeIsRecursive(struct {
        a: struct {
            const A = @This();
            b: struct {
                c: *struct {
                    a: ?A,
                },
            },
        },
    }));
    try std.testing.expect(typeIsRecursive(struct {
        a: [3]*@This(),
    }));
    try std.testing.expect(typeIsRecursive(struct {
        a: union { a: i32, b: *@This() },
    }));
}

fn checkValueDepth(val: anytype, depth: usize) error { MaxDepth }!void {
    if (depth == 0) return error.MaxDepth;
    const child_depth = depth - 1;

    switch (@typeInfo(@TypeOf(val))) {
        .Pointer => |Pointer| switch (Pointer.size) {
            .One => try checkValueDepth(val.*, child_depth),
            .Slice => for (val) |item| {
                try checkValueDepth(item, child_depth);
            },
            .C, .Many => {},
        },
        .Array => for (val) |item| {
            try checkValueDepth(item, child_depth);
        },
        .Struct => |Struct| inline for (Struct.fields) |field_info| {
            try checkValueDepth(@field(val, field_info.name), child_depth);
        },
        .Union => |Union| if (Union.tag_type == null) {
            return;
        } else switch (val) {
            inline else => |payload| {
                return checkValueDepth(payload, child_depth);
            },
        },
        .Optional => if (val) |inner| try checkValueDepth(inner, child_depth),
        else => {},
    }
}

fn expectValueDepthEquals(expected: usize, value: anytype) !void {
    try checkValueDepth(value, expected);
    try std.testing.expectError(error.MaxDepth, checkValueDepth(value, expected - 1));
}

test "checkValueDepth" {
    try expectValueDepthEquals(1, 10);
    try expectValueDepthEquals(2, .{ .x = 1, .y = 2 });
    try expectValueDepthEquals(2, .{ 1, 2 });
    try expectValueDepthEquals(3, .{ 1, .{ 2, 3 } });
    try expectValueDepthEquals(3, .{ .{ 1, 2 }, 3 });
    try expectValueDepthEquals(3, .{ .x = 0, .y = 1, .z = .{ .x = 3 } });
    try expectValueDepthEquals(3, .{ .x = 0, .y = .{ .x = 1 }, .z = 2 });
    try expectValueDepthEquals(3, .{ .x = .{ .x = 0 }, .y = 1, .z = 2 });
    try expectValueDepthEquals(2, @as(?u32, 1));
    try expectValueDepthEquals(1, @as(?u32, null));
    try expectValueDepthEquals(1, null);
    try expectValueDepthEquals(2, &1);
    try expectValueDepthEquals(3, &@as(?u32, 1));

    const Union = union(enum) {
        x: u32,
        y: struct { x: u32 },
    };
    try expectValueDepthEquals(2, Union{.x = 1});
    try expectValueDepthEquals(3, Union{.y = .{.x = 1 }});

    const Recurse = struct { r: ?*const @This() };
    try expectValueDepthEquals(2, Recurse { .r = null });
    try expectValueDepthEquals(5, Recurse { .r = &Recurse { .r = null } });
    try expectValueDepthEquals(8, Recurse { .r = &Recurse { .r = &Recurse { .r = null }} });

    try expectValueDepthEquals(2, @as([]const u8, &.{1, 2, 3}));
    try expectValueDepthEquals(3, @as([]const []const u8, &.{&.{1, 2, 3}}));
}

/// Lower level control over stringification, you can create a new instance with `stringifier`.
///
/// Useful when you want control over which fields/items are stringified, how they're represented,
/// or want to write a ZON object that does not exist in memory.
///
/// You can serialize values with `value`. To serialize recursive types, the following are provided:
/// * `valueMaxDepth`
/// * `valueArbitraryDepth`
///
/// You can also serialize values using specific notations:
/// * `int`
/// * `float`
/// * `utf8Codepoint`
/// * `slice`
/// * `sliceMaxDepth`
/// * `sliceArbitraryDepth`
/// * `string`
/// * `multilineString`
///
/// For manual serialization of containers, see:
/// * `startStruct`
/// * `startTuple`
/// * `startSlice`
///
/// # Example
/// ```zig
/// var serializer = stringifier(writer, .{});
/// var vec2 = try serializer.startStruct(.{});
/// try vec2.field("x", 1.5, .{});
/// try vec2.fieldPrefix();
/// try serializer.value(2.5);
/// try vec2.finish();
/// ```
pub fn Stringifier(comptime Writer: type) type {
    return struct {
        const Self = @This();

        pub const MaxDepthError = error { MaxDepth } || Writer.Error;

        options: StringifierOptions,
        indent_level: u8,
        writer: Writer,

        /// Initialize a stringifier.
        fn init(writer: Writer, options: StringifierOptions) Self {
            return .{
                .options = options,
                .writer = writer,
                .indent_level = 0,
            };
        }

        /// Serialize a value, similar to `stringify`.
        pub fn value(self: *Self, val: anytype, options: StringifyValueOptions) Writer.Error!void {
            comptimeAssertNoRecursion(@TypeOf(val));
            return self.valueArbitraryDepth(val, options);
        }

        /// Serialize a value, similar to `stringifyMaxDepth`.
        pub fn valueMaxDepth(self: *Self, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
            try checkValueDepth(val, depth);
            return self.valueArbitraryDepth(val, options);
        }

        /// Serialize a value, similar to `stringifyArbitraryDepth`.
        pub fn valueArbitraryDepth(self: *Self, val: anytype, options: StringifyValueOptions) Writer.Error!void {
            switch (@typeInfo(@TypeOf(val))) {
                .Int => |Int| if (options.emit_utf8_codepoints and
                    Int.signedness == .unsigned and
                    Int.bits <= 21 and std.unicode.utf8ValidCodepoint(val))
                {
                    self.utf8Codepoint(val) catch |err| switch (err) {
                        error.InvalidCodepoint => unreachable, // Already validated
                        else => |e| return e,
                    };
                } else {
                    try self.int(val);
                },
                .ComptimeInt => if (options.emit_utf8_codepoints and
                    val > 0 and
                    val <= std.math.maxInt(u21) and
                    std.unicode.utf8ValidCodepoint(val))
                {
                    self.utf8Codepoint(val) catch |err| switch (err) {
                        error.InvalidCodepoint => unreachable, // Already validated
                        else => |e| return e,
                    };
                } else {
                    try self.int(val);
                },
                .Float, .ComptimeFloat => try self.float(val),
                .Bool, .Null => try std.fmt.format(self.writer, "{}", .{val}),
                .EnumLiteral => {
                    try self.writer.writeByte('.');
                    try self.ident(@tagName(val));
                },
                .Enum => |Enum| if (Enum.is_exhaustive) {
                    try self.writer.writeByte('.');
                    try self.ident(@tagName(val));
                } else {
                    @compileError(@typeName(@TypeOf(val)) ++ ": cannot stringify non-exhaustive enums");
                },
                .Void => try self.writer.writeAll("{}"),
                .Pointer => |Pointer| {
                    const child_type = switch (@typeInfo(Pointer.child)) {
                        .Array => |Array| Array.child,
                        else => if (Pointer.size != .Slice) @compileError(@typeName(@TypeOf(val)) ++ ": cannot stringify pointer to this type") else Pointer.child,
                    };
                    if (child_type == u8 and !options.emit_strings_as_containers) {
                        try self.string(val);
                    } else {
                        try self.sliceImpl(val, options);
                    }
                },
                .Array => {
                    var container = try self.startTuple(.{ .whitespace_style = .{ .fields = val.len } });
                    for (val) |item_val| {
                        try container.fieldArbitraryDepth(item_val, options);
                    }
                    try container.finish();
                },
                .Struct => |StructInfo| if (StructInfo.is_tuple) {
                    var container = try self.startTuple(.{ .whitespace_style = .{ .fields = StructInfo.fields.len } });
                    inline for (val) |field_value| {
                        try container.fieldArbitraryDepth(field_value, options);
                    }
                    try container.finish();
                } else {
                    // Decide which fields to emit
                    const fields, const skipped = if (options.emit_default_optional_fields) b: {
                        break :b .{ StructInfo.fields.len, [1]bool{false} ** StructInfo.fields.len};
                    } else b: {
                        var fields = StructInfo.fields.len;
                        var skipped = [1]bool {false} ** StructInfo.fields.len;
                        inline for (StructInfo.fields, &skipped) |field_info, *skip| {
                            if (field_info.default_value) |default_field_value_opaque| {
                                const field_value = @field(val, field_info.name);
                                const default_field_value: *const @TypeOf(field_value) = @ptrCast(@alignCast(default_field_value_opaque));
                                if (std.meta.eql(field_value, default_field_value.*)) {
                                    skip.* = true;
                                    fields -= 1;
                                }
                            }
                        }
                        break :b .{ fields, skipped };
                    };

                    // Emit those fields
                    var container = try self.startStruct(.{ .whitespace_style = .{ .fields = fields } });
                    inline for (StructInfo.fields, skipped) |field_info, skip| {
                        if (!skip) {
                            try container.fieldArbitraryDepth(field_info.name, @field(val, field_info.name), options);
                        }
                    }
                    try container.finish();
                },
                .Union => |Union| if (Union.tag_type == null) {
                    @compileError(@typeName(@TypeOf(val)) ++ ": cannot stringify untagged unions");
                } else {
                    var container = try self.startStruct(.{ .whitespace_style = .{ .fields = 1 } });
                    switch (val) {
                        inline else => |pl, tag| try container.fieldArbitraryDepth(@tagName(tag), pl, options),
                    }
                    try container.finish();
                },
                .Optional => if (val) |inner| {
                    try self.valueArbitraryDepth(inner, options);
                } else {
                    try self.writer.writeAll("null");
                },

                else => @compileError(@typeName(@TypeOf(val)) ++ ": cannot stringify this type"),
            }
        }

        /// Serialize an integer.
        pub fn int(self: *Self, val: anytype) Writer.Error!void {
            try std.fmt.formatInt(val, 10, .lower, .{}, self.writer);
        }

        /// Serialize a float.
        pub fn float(self: *Self, val: anytype) Writer.Error!void {
            switch (@typeInfo(@TypeOf(val))) {
                .Float, .ComptimeFloat => if (std.math.isNan(val)) {
                    return self.writer.writeAll("nan");
                } else if (@as(f128, val) == std.math.inf(f128)) {
                    return self.writer.writeAll("inf");
                } else if (@as(f128, val) == -std.math.inf(f128)) {
                    return self.writer.writeAll("-inf");
                } else {
                    // XXX: don't need to cast to f64 anymore!
                    try std.fmt.format(self.writer, "{d}", .{@as(f64, @floatCast(val))});
                },
                else => @compileError(@typeName(@TypeOf(val)) ++ ": expected float"),
            }
        }

        fn identNeedsEscape(name: []const u8) bool {
            std.debug.assert(name.len != 0);
            for (name, 0..) |c, i| {
                switch (c) {
                    'A'...'Z', 'a'...'z', '_' => {},
                    '0'...'9' => if (i == 0) return true,
                    else => return true,
                }
            }
            return std.zig.Token.keywords.has(name);
        }

        /// Serialize `name` as an identifier.
        ///
        /// Escapes the identifier if necessary.
        pub fn ident(self: *Self, name: []const u8) Writer.Error!void {
            if (identNeedsEscape(name)) {
                try self.writer.writeAll("@\"");
                try self.writer.writeAll(name);
                try self.writer.writeByte('"');
            } else {
                try self.writer.writeAll(name);
            }
        }

        /// Serialize `val` as a UTF8 codepoint.
        ///
        /// Returns `error.InvalidCodepoint` if `val` is not a valid UTF8 codepoint.
        pub fn utf8Codepoint(self: *Self, val: u21) (Writer.Error || error{InvalidCodepoint})!void {
            var buf: [8]u8 = undefined;
            const len = std.unicode.utf8Encode(val, &buf) catch return error.InvalidCodepoint;
            const str = buf[0..len];
            try std.fmt.format(self.writer, "'{'}'", .{std.zig.fmtEscapes(str)});
        }

        /// Like `value`, but always serializes `val` as a slice.
        ///
        /// Will fail at comptime if `val` is not an array or slice.
        pub fn slice(self: *Self, val: anytype, options: StringifyValueOptions) Writer.Error!void {
            comptimeAssertNoRecursion(@TypeOf(val));
            try self.sliceArbitraryDepth(val, options);
        }

        /// Like `value`, but recursive types are allowed.
        ///
        /// Returns `error.MaxDepthError` if `depth` is exceeded.
        pub fn sliceMaxDepth(self: *Self, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
            try checkValueDepth(val, depth);
            try self.sliceArbitraryDepth(val, options);
        }

        /// Like `value`, but recursive types are allowed.
        ///
        /// It is the caller's responsibility to ensure that `val` does not contain cycles.
        pub fn sliceArbitraryDepth(self: *Self, val: anytype, options: StringifyValueOptions) Writer.Error!void {
            try self.sliceImpl(val, options);
        }

        fn sliceImpl(self: *Self, val: anytype, options: StringifyValueOptions) Writer.Error!void {
            var container = try self.startSlice(.{ .whitespace_style = .{ .fields = val.len } });
            for (val) |item_val| {
                try container.itemArbitraryDepth(item_val, options);
            }
            try container.finish();
        }

        /// Like `value`, but always serializes `val` as a string.
        pub fn string(self: *Self, val: []const u8) Writer.Error!void {
            try std.fmt.format(self.writer, "\"{}\"", .{std.zig.fmtEscapes(val)});
        }

        /// Options for formatting multiline strings.
        pub const MultilineStringOptions = struct {
            /// If top level is true, whitespace before and after the multiline string is elided.
            /// If it is true, a newline is printed, then the value, followed by a newline, and if
            /// whitespace is true any necessary indentation follows.
            top_level: bool = false,
        };

        /// Like `value`, but always serializes to a multiline string literal.
        ///
        /// Returns `error.InnerCarriageReturn` if `val` contains a CR not followed by a newline,
        /// since multiline strings cannot represent CR without a following newline.
        pub fn multilineString(self: *Self, val: []const u8, options: MultilineStringOptions) (Writer.Error || error { InnerCarriageReturn })!void {
            // Make sure the string does not contain any carriage returns not followed by a newline
            var i: usize = 0;
            while (i < val.len) : (i += 1) {
                if (val[i] == '\r') {
                    if (i + 1 < val.len) {
                        if (val[i + 1] == '\n') {
                            i += 1;
                            continue;
                        }
                    }
                    return error.InnerCarriageReturn;
                }
            }

            if (!options.top_level) {
                try self.newline();
                try self.indent();
            }

            try self.writer.writeAll("\\\\");
            for (val) |c| {
                if (c != '\r') {
                    try self.writer.writeByte(c); // We write newlines here even if whitespace off
                    if (c == '\n') {
                        try self.indent();
                        try self.writer.writeAll("\\\\");
                    }
                }
            }

            if (!options.top_level) {
                try self.writer.writeByte('\n'); // Even if whitespace off
                try self.indent();
            }
        }

        /// Create a `Struct` for writing ZON structs field by field.
        pub fn startStruct(self: *Self, options: StringifyContainerOptions) Writer.Error!Struct {
            return Struct.start(self, options);
        }

        /// Creates a `Tuple` for writing ZON tuples field by field.
        pub fn startTuple(self: *Self, options: StringifyContainerOptions) Writer.Error!Tuple {
            return Tuple.start(self, options);
        }

        /// Creates a `Slice` for writing ZON slices item by item.
        pub fn startSlice(self: *Self, options: StringifyContainerOptions) Writer.Error!Slice {
            return Slice.start(self, options);
        }

        fn indent(self: *Self) Writer.Error!void {
            if (self.options.whitespace) {
                try self.writer.writeByteNTimes(' ', 4 * self.indent_level);
            }
        }

        fn newline(self: *Self) Writer.Error!void {
            if (self.options.whitespace) {
                try self.writer.writeByte('\n');
            }
        }

        fn newlineOrSpace(self: *Self, len: usize) Writer.Error!void {
            if (self.containerShouldWrap(len)) {
                try self.newline();
            } else {
                try self.space();
            }
        }

        fn space(self: *Self) Writer.Error!void {
            if (self.options.whitespace) {
                try self.writer.writeByte(' ');
            }
        }

        /// Writes ZON tuples field by field.
        pub const Tuple = struct {
            container: Container,

            fn start(parent: *Self, options: StringifyContainerOptions) Writer.Error!Tuple {
                return .{
                    .container = try Container.start(parent, .anon, options),
                };
            }

            /// Finishes serializing the tuple.
            ///
            /// Prints a trailing comma as configured when appropriate, and the closing bracket.
            pub fn finish(self: *Tuple) Writer.Error!void {
                try self.container.finish();
                self.* = undefined;
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `value`.
            pub fn field(self: *Tuple, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.field(null, val, options);
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `valueMaxDepth`.
            pub fn fieldMaxDepth(self: *Tuple, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
                try self.container.fieldMaxDepth(null, val, options,  depth);
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `valueArbitraryDepth`.
            pub fn fieldArbitraryDepth(self: *Tuple, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.fieldArbitraryDepth(null, val, options);
            }

            /// Print a field prefix. This prints any necessary commas, and whitespace as
            /// configured. Useful if you want to serialize the field value yourself.
            pub fn fieldPrefix(self: *Tuple) Writer.Error!void {
                try self.container.fieldPrefix(null);
            }
        };

        /// Writes ZON structs field by field.
        pub const Struct = struct {
            container: Container,

            fn start(parent: *Self, options: StringifyContainerOptions) Writer.Error!Struct {
                return .{
                    .container = try Container.start(parent, .named, options),
                };
            }

            /// Finishes serializing the struct.
            ///
            /// Prints a trailing comma as configured when appropriate, and the closing bracket.
            pub fn finish(self: *Struct) Writer.Error!void {
                try self.container.finish();
                self.* = undefined;
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `value`.
            pub fn field(self: *Struct, name: []const u8, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.field(name, val, options);
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `valueMaxDepth`.
            pub fn fieldMaxDepth(self: *Struct, name: []const u8, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
                try self.container.fieldMaxDepth(name, val, options, depth);
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `valueArbitraryDepth`.
            pub fn fieldArbitraryDepth(self: *Struct, name: []const u8, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.fieldArbitraryDepth(name, val, options);
            }

            /// Print a field prefix. This prints any necessary commas, the field name (escaped if
            /// necessary) and whitespace as configured. Useful if you want to serialize the field
            /// value yourself.
            pub fn fieldPrefix(self: *Struct, name: []const u8) Writer.Error!void {
                try self.container.fieldPrefix(name);
            }
        };

        /// Writes ZON slices field by field.
        pub const Slice = struct {
            container: Container,

            fn start(parent: *Self, options: StringifyContainerOptions) Writer.Error!Slice {
                try parent.writer.writeByte('&');
                return .{
                    .container = try Container.start(parent, .anon, options),
                };
            }

            /// Finishes serializing the slice.
            ///
            /// Prints a trailing comma as configured when appropriate, and the closing bracket.
            pub fn finish(self: *Slice) Writer.Error!void {
                try self.container.finish();
                self.* = undefined;
            }

            /// Serialize an item. Equivalent to calling `itemPrefix` followed by `value`.
            pub fn item(self: *Slice, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.field(null, val, options);
            }

            /// Serialize an item. Equivalent to calling `itemPrefix` followed by `valueMaxDepth`.
            pub fn itemMaxDepth(self: *Slice, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
                try self.container.fieldMaxDepth(null, val, options, depth);
            }

            /// Serialize an item. Equivalent to calling `itemPrefix` followed by `valueArbitraryDepth`.
            pub fn itemArbitraryDepth(self: *Slice, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.container.fieldArbitraryDepth(null, val, options);
            }

            /// Print a field prefix. This prints any necessary commas, and whitespace as
            /// configured. Useful if you want to serialize the item value yourself.
            pub fn itemPrefix(self: *Slice) Writer.Error!void {
                try self.container.fieldPrefix(null);
            }
        };

        const Container = struct {
            const FieldStyle = enum { named, anon };

            serializer: *Self,
            field_style: FieldStyle,
            options: StringifyContainerOptions,
            empty: bool,

            fn start(serializer: *Self, field_style: FieldStyle, options: StringifyContainerOptions) Writer.Error!Container {
                if (options.shouldWrap()) serializer.indent_level +|= 1;
                try serializer.writer.writeAll(".{");
                return .{
                    .serializer = serializer,
                    .field_style = field_style,
                    .options = options,
                    .empty = true,
                };
            }

            fn finish(self: *Container) Writer.Error!void {
                if (self.options.shouldWrap()) self.serializer.indent_level -|= 1;
                if (!self.empty) {
                    if (self.options.shouldWrap()) {
                        if (self.serializer.options.whitespace) {
                            try self.serializer.writer.writeByte(',');
                        }
                        try self.serializer.newline();
                        try self.serializer.indent();
                    } else if (!self.shouldElideSpaces()) {
                        try self.serializer.space();
                    }
                }
                try self.serializer.writer.writeByte('}');
                self.* = undefined;
            }

            fn fieldPrefix(self: *Container, name: ?[]const u8) Writer.Error!void {
                if (!self.empty) {
                    try self.serializer.writer.writeByte(',');
                }
                self.empty = false;
                if (self.options.shouldWrap()) {
                    try self.serializer.newline();
                } else if (!self.shouldElideSpaces()) {
                    try self.serializer.space();
                }
                if (self.options.shouldWrap()) try self.serializer.indent();
                if (name) |n| {
                    try self.serializer.writer.writeByte('.');
                    try self.serializer.ident(n);
                    try self.serializer.space();
                    try self.serializer.writer.writeByte('=');
                    try self.serializer.space();
                }
            }

            fn field(self: *Container, name: ?[]const u8, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                comptimeAssertNoRecursion(@TypeOf(val));
                try self.fieldArbitraryDepth(name, val, options);
            }

            fn fieldMaxDepth(self: *Container, name: ?[]const u8, val: anytype, options: StringifyValueOptions, depth: usize) MaxDepthError!void {
                try checkValueDepth(val, depth);
                try self.fieldArbitraryDepth(name, val, options);
            }

            fn fieldArbitraryDepth(self: *Container, name: ?[]const u8, val: anytype, options: StringifyValueOptions) Writer.Error!void {
                try self.fieldPrefix(name);
                try self.serializer.valueArbitraryDepth(val, options);
            }

            fn shouldElideSpaces(self: *const Container) bool {
                return switch (self.options.whitespace_style) {
                    .fields => |fields| self.field_style != .named and fields == 1,
                    else => false,
                };
            }
        };

        fn comptimeAssertNoRecursion(comptime T: type) void {
            if (comptime typeIsRecursive(T)) {
                @compileError(@typeName(T) ++ ": recursive type stringified without depth limit");
            }
        }
    };
}

/// Creates an instance of `Stringifier`.
pub fn stringifier(writer: anytype, options: StringifierOptions) Stringifier(@TypeOf(writer)) {
    return Stringifier(@TypeOf(writer)).init(writer, options);
}

fn expectStringifyEqual(expected: []const u8, value: anytype, comptime options: StringifyOptions) !void {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    try stringify(value, options, buf.writer());
    try std.testing.expectEqualStrings(expected, buf.items);
}

test "stringify whitespace, high level API" {
    try expectStringifyEqual(".{}", .{}, .{});
    try expectStringifyEqual(".{}", .{}, .{ .whitespace = false });

    try expectStringifyEqual(".{1}", .{1}, .{});
    try expectStringifyEqual(".{1}", .{1}, .{ .whitespace = false });

    try expectStringifyEqual(".{1}", @as([1]u32, .{1}), .{});
    try expectStringifyEqual(".{1}", @as([1]u32, .{1}), .{ .whitespace = false });

    try expectStringifyEqual("&.{1}", @as([]const u32, &.{1}), .{});
    try expectStringifyEqual("&.{1}", @as([]const u32, &.{1}), .{ .whitespace = false });

    try expectStringifyEqual(".{ .x = 1 }", .{ .x = 1 }, .{});
    try expectStringifyEqual(".{.x=1}", .{ .x = 1 }, .{ .whitespace = false });

    try expectStringifyEqual(".{ 1, 2 }", .{ 1, 2 }, .{});
    try expectStringifyEqual(".{1,2}", .{ 1, 2 }, .{ .whitespace = false });

    try expectStringifyEqual(".{ 1, 2 }", @as([2]u32, .{ 1, 2 }), .{});
    try expectStringifyEqual(".{1,2}", @as([2]u32, .{ 1, 2 }), .{ .whitespace = false });

    try expectStringifyEqual("&.{ 1, 2 }", @as([]const u32, &.{ 1, 2 }), .{});
    try expectStringifyEqual("&.{1,2}", @as([]const u32, &.{ 1, 2 }), .{ .whitespace = false });

    try expectStringifyEqual(".{ .x = 1, .y = 2 }", .{ .x = 1, .y = 2 }, .{});
    try expectStringifyEqual(".{.x=1,.y=2}", .{ .x = 1, .y = 2 }, .{ .whitespace = false });

    try expectStringifyEqual(
        \\.{
        \\    1,
        \\    2,
        \\    3,
        \\}
    , .{ 1, 2, 3 }, .{});
    try expectStringifyEqual(".{1,2,3}", .{ 1, 2, 3 }, .{ .whitespace = false });

    try expectStringifyEqual(
        \\.{
        \\    1,
        \\    2,
        \\    3,
        \\}
    , @as([3]u32, .{ 1, 2, 3 }), .{});
    try expectStringifyEqual(".{1,2,3}", @as([3]u32, .{ 1, 2, 3 }), .{ .whitespace = false });

    try expectStringifyEqual(
        \\&.{
        \\    1,
        \\    2,
        \\    3,
        \\}
    , @as([]const u32, &.{ 1, 2, 3 }), .{});
    try expectStringifyEqual("&.{1,2,3}", @as([]const u32, &.{ 1, 2, 3 }), .{ .whitespace = false });

    try expectStringifyEqual(
        \\.{
        \\    .x = 1,
        \\    .y = 2,
        \\    .z = 3,
        \\}
    , .{ .x = 1, .y = 2, .z = 3 }, .{});
    try expectStringifyEqual(".{.x=1,.y=2,.z=3}", .{ .x = 1, .y = 2, .z = 3 }, .{ .whitespace = false });

    const Union = union(enum) { a: bool, b: i32, c: u8 };

    try expectStringifyEqual(".{ .b = 1 }", Union{ .b = 1 }, .{});
    try expectStringifyEqual(".{.b=1}", Union{ .b = 1 }, .{ .whitespace = false });

    // Nested indentation where outer object doesn't wrap
    try expectStringifyEqual(
        \\.{ .inner = .{
        \\    1,
        \\    2,
        \\    3,
        \\} }
    , .{ .inner = .{ 1, 2, 3 } }, .{});
}

test "stringify whitespace, low level API" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    const writer = buffer.writer();
    var serializer = stringifier(writer, .{});

    inline for (.{ true, false }) |whitespace| {
        serializer.options = .{ .whitespace = whitespace };

        // Empty containers
        {
            var container = try serializer.startStruct(.{});
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startTuple(.{});
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startStruct(.{ .whitespace_style = .{ .fields = 0 } });
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startTuple(.{ .whitespace_style = .{ .fields = 0 } });
            try container.finish();
            try std.testing.expectEqualStrings(".{}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        // Size 1
        {
            var container = try serializer.startStruct(.{});
            try container.field("a", 1, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startTuple(.{});
            try container.field(1, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            // We get extra spaces here, since we didn't know up front that there would only be one
            // field.
            var container = try serializer.startTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startStruct(.{ .whitespace_style = .{ .fields = 1 } });
            try container.field("a", 1, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startTuple(.{ .whitespace_style = .{ .fields = 1 } });
            try container.field(1, .{});
            try container.finish();
            try std.testing.expectEqualStrings(".{1}", buffer.items);
            buffer.clearRetainingCapacity();
        }

        // Size 2
        {
            var container = try serializer.startStruct(.{});
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\    .b = 2,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startTuple(.{});
            try container.field(1, .{});
            try container.field(2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\    2,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startStruct(.{ .whitespace_style = .{ .fields = 2 } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startTuple(.{ .whitespace_style = .{ .fields = 2 } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        // Size 3
        {
            var container = try serializer.startStruct(.{});
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.field("c", 3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\    .b = 2,
                    \\    .c = 3,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startTuple(.{});
            try container.field(1, .{});
            try container.field(2, .{});
            try container.field(3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\    2,
                    \\    3,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.field("c", 3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2, .c = 3 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.field(3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2, 3 }", buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startStruct(.{ .whitespace_style = .{ .fields = 3 } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.field("c", 3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\    .b = 2,
                    \\    .c = 3,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        {
            var container = try serializer.startTuple(.{ .whitespace_style = .{ .fields = 3 } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.field(3, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\    2,
                    \\    3,
                    \\}
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }

        // Nested objects where the outer container doesn't wrap but the inner containers do
        {
            var container = try serializer.startStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("first", .{ 1, 2, 3 }, .{});
            try container.field("second", .{ 4, 5, 6 }, .{});
            try container.finish();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{ .first = .{
                    \\    1,
                    \\    2,
                    \\    3,
                    \\}, .second = .{
                    \\    4,
                    \\    5,
                    \\    6,
                    \\} }
                , buffer.items);
            } else {
                try std.testing.expectEqualStrings(".{.first=.{1,2,3},.second=.{4,5,6}}", buffer.items);
            }
            buffer.clearRetainingCapacity();
        }
    }
}

test "stringify utf8 codepoints" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    const writer = buffer.writer();
    var serializer = stringifier(writer, .{});

    // Minimal case
    try serializer.utf8Codepoint('a');
    try std.testing.expectEqualStrings("'a'", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.int('a');
    try std.testing.expectEqualStrings("97", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value('a', .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings("'a'", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value('a', .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings("97", buffer.items);
    buffer.clearRetainingCapacity();

    // Short escaped codepoint
    try serializer.utf8Codepoint('\n');
    try std.testing.expectEqualStrings("'\\n'", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.int('\n');
    try std.testing.expectEqualStrings("10", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value('\n', .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings("'\\n'", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value('\n', .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings("10", buffer.items);
    buffer.clearRetainingCapacity();

    // Large codepoint
    try serializer.utf8Codepoint('⚡');
    try std.testing.expectEqualStrings("'\\xe2\\x9a\\xa1'", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.int('⚡');
    try std.testing.expectEqualStrings("9889", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value('⚡', .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings("'\\xe2\\x9a\\xa1'", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value('⚡', .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings("9889", buffer.items);
    buffer.clearRetainingCapacity();

    // Invalid codepoint
    try std.testing.expectError(error.InvalidCodepoint, serializer.utf8Codepoint(0x110000 + 1));

    try serializer.int(0x110000 + 1);
    try std.testing.expectEqualStrings("1114113", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value(0x110000 + 1, .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings("1114113", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value(0x110000 + 1, .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings("1114113", buffer.items);
    buffer.clearRetainingCapacity();

    // Valid codepoint, not a codepoint type
    try serializer.value(@as(u22, 'a'), .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings("97", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value(@as(i32, 'a'), .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings("97", buffer.items);
    buffer.clearRetainingCapacity();

    // Make sure value options are passed to children
    try serializer.value(.{ .c = '⚡' }, .{ .emit_utf8_codepoints = true });
    try std.testing.expectEqualStrings(".{ .c = '\\xe2\\x9a\\xa1' }", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value(.{ .c = '⚡' }, .{ .emit_utf8_codepoints = false });
    try std.testing.expectEqualStrings(".{ .c = 9889 }", buffer.items);
    buffer.clearRetainingCapacity();
}

test "stringify strings" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    const writer = buffer.writer();
    var serializer = stringifier(writer, .{});

    // Minimal case
    try serializer.string("abc⚡\n");
    try std.testing.expectEqualStrings("\"abc\\xe2\\x9a\\xa1\\n\"", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.slice("abc⚡\n", .{});
    try std.testing.expectEqualStrings(
        \\&.{
        \\    97,
        \\    98,
        \\    99,
        \\    226,
        \\    154,
        \\    161,
        \\    10,
        \\}
    , buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value("abc⚡\n", .{});
    try std.testing.expectEqualStrings("\"abc\\xe2\\x9a\\xa1\\n\"", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value("abc⚡\n", .{ .emit_strings_as_containers = true });
    try std.testing.expectEqualStrings(
        \\&.{
        \\    97,
        \\    98,
        \\    99,
        \\    226,
        \\    154,
        \\    161,
        \\    10,
        \\}
    , buffer.items);
    buffer.clearRetainingCapacity();

    // Value options are inherited by children
    try serializer.value(.{ .str = "abc" }, .{});
    try std.testing.expectEqualStrings(".{ .str = \"abc\" }", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.value(.{ .str = "abc" }, .{ .emit_strings_as_containers = true });
    try std.testing.expectEqualStrings(
        \\.{ .str = &.{
        \\    97,
        \\    98,
        \\    99,
        \\} }
    , buffer.items);
    buffer.clearRetainingCapacity();

    // Arrays (rather than pointers to arrays) of u8s are not considered strings, so that data can round trip
    // correctly.
    try serializer.value("abc".*, .{});
    try std.testing.expectEqualStrings(
        \\.{
        \\    97,
        \\    98,
        \\    99,
        \\}
    , buffer.items);
    buffer.clearRetainingCapacity();
}

test "stringify multiline strings" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    const writer = buf.writer();
    var serializer = stringifier(writer, .{});

    inline for (.{true, false}) |whitespace| {
        serializer.options.whitespace = whitespace;

        {
            try serializer.multilineString("", .{.top_level = true});
            try std.testing.expectEqualStrings("\\\\", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try serializer.multilineString("abc⚡", .{.top_level = true});
            try std.testing.expectEqualStrings("\\\\abc⚡", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try serializer.multilineString("abc⚡\ndef", .{.top_level = true});
            try std.testing.expectEqualStrings("\\\\abc⚡\n\\\\def", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try serializer.multilineString("abc⚡\r\ndef", .{.top_level = true});
            try std.testing.expectEqualStrings("\\\\abc⚡\n\\\\def", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try serializer.multilineString("\nabc⚡", .{.top_level = true});
            try std.testing.expectEqualStrings("\\\\\n\\\\abc⚡", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try serializer.multilineString("\r\nabc⚡", .{.top_level = true});
            try std.testing.expectEqualStrings("\\\\\n\\\\abc⚡", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try serializer.multilineString("abc\ndef", .{});
            if (whitespace) {
                try std.testing.expectEqualStrings("\n\\\\abc\n\\\\def\n", buf.items);
            } else {
                try std.testing.expectEqualStrings("\\\\abc\n\\\\def\n", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            const str: []const u8 = &.{'a', '\r', 'c'};
            try serializer.string(str);
            try std.testing.expectEqualStrings("\"a\\rc\"", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try std.testing.expectError(error.InnerCarriageReturn, serializer.multilineString(@as([]const u8, &.{'a', '\r', 'c'}), .{}));
            try std.testing.expectError(error.InnerCarriageReturn, serializer.multilineString(@as([]const u8, &.{'a', '\r', 'c', '\n'}), .{}));
            try std.testing.expectError(error.InnerCarriageReturn, serializer.multilineString(@as([]const u8, &.{'a', '\r', 'c', '\r', '\n'}), .{}));
            try std.testing.expectEqualStrings("", buf.items);
            buf.clearRetainingCapacity();
        }
    }
}

test "stringify skip default fields" {
    const Struct = struct {
        x: i32 = 2,
        y: i8,
        z: u32 = 4,
        inner1: struct { a: u8 = 'z', b: u8 = 'y', c: u8 } = .{
            .a = '1',
            .b = '2',
            .c = '3',
        },
        inner2: struct { u8, u8, u8 } = .{
            'a',
            'b',
            'c',
        },
        inner3: struct { u8, u8, u8 } = .{
            'a',
            'b',
            'c',
        },
    };

    // Not skipping if not set
    try expectStringifyEqual(
        \\.{
        \\    .x = 2,
        \\    .y = 3,
        \\    .z = 4,
        \\    .inner1 = .{
        \\        .a = '1',
        \\        .b = '2',
        \\        .c = '3',
        \\    },
        \\    .inner2 = .{
        \\        'a',
        \\        'b',
        \\        'c',
        \\    },
        \\    .inner3 = .{
        \\        'a',
        \\        'b',
        \\        'd',
        \\    },
        \\}
        , Struct{
            .y = 3,
            .z = 4,
            .inner1 = .{
                .a = '1',
                .b = '2',
                .c = '3',
            },
            .inner3 = .{
                'a',
                'b',
                'd',
            },
        },
        .{ .emit_utf8_codepoints = true },
    );

    // Top level defaults
    try expectStringifyEqual(
        \\.{ .y = 3, .inner3 = .{
        \\    'a',
        \\    'b',
        \\    'd',
        \\} }
        , Struct{
            .y = 3,
            .z = 4,
            .inner1 = .{
                .a = '1',
                .b = '2',
                .c = '3',
            },
            .inner3 = .{
                'a',
                'b',
                'd',
            },
        },
        .{
            .emit_default_optional_fields = false,
            .emit_utf8_codepoints = true,
        },
    );

    // Inner types having defaults, and defaults changing the number of fields affecting the formatting
    try expectStringifyEqual(
        \\.{
        \\    .y = 3,
        \\    .inner1 = .{ .b = '2', .c = '3' },
        \\    .inner3 = .{
        \\        'a',
        \\        'b',
        \\        'd',
        \\    },
        \\}
        , Struct{
            .y = 3,
            .z = 4,
            .inner1 = .{
                .a = 'z',
                .b = '2',
                .c = '3',
            },
            .inner3 = .{
                'a',
                'b',
                'd',
            },
        },
        .{
            .emit_default_optional_fields = false,
            .emit_utf8_codepoints = true,
        },
    );

    const DefaultStrings = struct {
        foo: []const u8 = "abc",
    };
    try expectStringifyEqual(
        \\.{}
        , DefaultStrings { .foo = "abc" },
        .{.emit_default_optional_fields = false},
    );
    try expectStringifyEqual(
        \\.{ .foo = "abcd" }
        , DefaultStrings { .foo = "abcd" },
        .{.emit_default_optional_fields = false},
    );
}

test "depth limits" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    const Recurse = struct { r: []const @This() };

    // Normal operation
    try stringifyMaxDepth(.{ 1, .{ 2, 3 } }, .{}, buf.writer(), 16);
    try std.testing.expectEqualStrings(".{ 1, .{ 2, 3 } }", buf.items);
    buf.clearRetainingCapacity();

    try stringifyArbitraryDepth(.{ 1, .{ 2, 3 } }, .{}, buf.writer());
    try std.testing.expectEqualStrings(".{ 1, .{ 2, 3 } }", buf.items);
    buf.clearRetainingCapacity();

    // Max depth failing on non recursive type
    try std.testing.expectError(error.MaxDepth, stringifyMaxDepth(.{ 1, .{ 2, .{ 3, 4 } } }, .{}, buf.writer(), 3));
    try std.testing.expectEqualStrings("", buf.items);
    buf.clearRetainingCapacity();

    // Max depth passing on recursive type
    {
        const maybe_recurse = Recurse { .r = &.{} };
        try stringifyMaxDepth(maybe_recurse, .{}, buf.writer(), 2);
        try std.testing.expectEqualStrings(".{ .r = &.{} }", buf.items);
        buf.clearRetainingCapacity();
    }

    // Unchecked passing on recursive type
    {
        const maybe_recurse = Recurse { .r = &.{} };
        try stringifyArbitraryDepth(maybe_recurse, .{}, buf.writer());
        try std.testing.expectEqualStrings(".{ .r = &.{} }", buf.items);
        buf.clearRetainingCapacity();
    }

    // Max depth failing on recursive type due to depth
    {
        var maybe_recurse = Recurse { .r = &.{} };
        maybe_recurse.r = &.{ .{ .r = &.{} } };
        try std.testing.expectError(error.MaxDepth, stringifyMaxDepth(maybe_recurse, .{}, buf.writer(), 2));
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();
    }

    // Same but for a slice
    {
        var temp: [1]Recurse = .{ .{ .r = &.{} } };
        const maybe_recurse: []const Recurse = &temp;

        try std.testing.expectError(error.MaxDepth, stringifyMaxDepth(maybe_recurse, .{}, buf.writer(), 2));
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();

        var serializer = stringifier(buf.writer(), .{});

        try std.testing.expectError(error.MaxDepth, serializer.sliceMaxDepth(maybe_recurse, .{}, 2));
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();

        try serializer.sliceArbitraryDepth(maybe_recurse, .{});
        try std.testing.expectEqualStrings("&.{.{ .r = &.{} }}", buf.items);
        buf.clearRetainingCapacity();
    }

    // A slice succeeding
    {
        var temp: [1]Recurse = .{ .{ .r = &.{} } };
        const maybe_recurse: []const Recurse = &temp;

        try stringifyMaxDepth(maybe_recurse, .{}, buf.writer(), 3);
        try std.testing.expectEqualStrings("&.{.{ .r = &.{} }}", buf.items);
        buf.clearRetainingCapacity();

        var serializer = stringifier(buf.writer(), .{});

        try serializer.sliceMaxDepth(maybe_recurse, .{}, 3);
        try std.testing.expectEqualStrings("&.{.{ .r = &.{} }}", buf.items);
        buf.clearRetainingCapacity();

        try serializer.sliceArbitraryDepth(maybe_recurse, .{});
        try std.testing.expectEqualStrings("&.{.{ .r = &.{} }}", buf.items);
        buf.clearRetainingCapacity();
    }

    // Max depth failing on recursive type due to recursion
    {
        var temp: [1]Recurse = .{ .{ .r = &.{} } };
        temp[0].r = &temp;
        const maybe_recurse: []const Recurse = &temp;

        try std.testing.expectError(error.MaxDepth, stringifyMaxDepth(maybe_recurse, .{}, buf.writer(), 128));
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();

        var serializer = stringifier(buf.writer(), .{});
        try std.testing.expectError(error.MaxDepth, serializer.sliceMaxDepth(maybe_recurse, .{}, 128));
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();
    }

    // Max depth on other parts of the lower level API
    {
        const writer = buf.writer();
        var serializer = stringifier(writer, .{});

        const maybe_recurse: []const Recurse = &.{};

        try std.testing.expectError(error.MaxDepth, serializer.valueMaxDepth(1, .{}, 0));
        try serializer.valueMaxDepth(2, .{}, 1);
        try serializer.value(3, .{});
        try serializer.valueArbitraryDepth(maybe_recurse, .{});

        var s = try serializer.startStruct(.{});
        try std.testing.expectError(error.MaxDepth, s.fieldMaxDepth("a", 1, .{}, 0));
        try s.fieldMaxDepth("b", 4, .{}, 1);
        try s.field("c", 5, .{});
        try s.fieldArbitraryDepth("d", maybe_recurse, .{});
        try s.finish();

        var t = try serializer.startTuple(.{});
        try std.testing.expectError(error.MaxDepth, t.fieldMaxDepth(1, .{}, 0));
        try t.fieldMaxDepth(6, .{}, 1);
        try t.field(7, .{});
        try t.fieldArbitraryDepth(maybe_recurse, .{});
        try t.finish();

        var a = try serializer.startSlice(.{});
        try std.testing.expectError(error.MaxDepth, a.itemMaxDepth(1, .{}, 0));
        try a.itemMaxDepth(8, .{}, 1);
        try a.item(9, .{});
        try a.itemArbitraryDepth(maybe_recurse, .{});
        try a.finish();

        try std.testing.expectEqualStrings(
            \\23&.{}.{
            \\    .b = 4,
            \\    .c = 5,
            \\    .d = &.{},
            \\}.{
            \\    6,
            \\    7,
            \\    &.{},
            \\}&.{
            \\    8,
            \\    9,
            \\    &.{},
            \\}
        , buf.items);
    }
}

test "stringify primitives" {
    try expectStringifyEqual(
        \\.{
        \\    .a = 1.5,
        \\    .b = 0.3333333333333333,
        \\    .c = 3.141592653589793,
        \\    .d = 0,
        \\    .e = -0,
        \\    .f = inf,
        \\    .g = -inf,
        \\    .h = nan,
        \\}
        , .{
            .a = @as(f128, 1.5), // Make sure explicit f128s work
            .b = 1.0 / 3.0,
            .c = std.math.pi,
            .d = 0.0,
            .e = -0.0,
            .f = std.math.inf(f32),
            .g = -std.math.inf(f32),
            .h = std.math.nan(f32),
        },
        .{},
    );

    try expectStringifyEqual(
        \\.{
        \\    .a = 18446744073709551616,
        \\    .b = -18446744073709551616,
        \\    .c = 680564733841876926926749214863536422912,
        \\    .d = -680564733841876926926749214863536422912,
        \\    .e = 0,
        \\}
        , .{
            .a = 18446744073709551616,
            .b = -18446744073709551616,
            .c = 680564733841876926926749214863536422912,
            .d = -680564733841876926926749214863536422912,
            .e = 0,
        },
        .{},
    );

    try expectStringifyEqual(
        \\.{
        \\    .a = true,
        \\    .b = false,
        \\    .c = .foo,
        \\    .d = {},
        \\    .e = null,
        \\}
        , .{
            .a = true,
            .b = false,
            .c = .foo,
            .d = {},
            .e = null,
        },
        .{},
    );

    const Struct = struct { x: f32, y: f32 };
    try expectStringifyEqual(
        ".{ .a = .{ .x = 1, .y = 2 }, .b = null }"
        , .{
            .a = @as(?Struct, .{ .x = 1, .y = 2 }),
            .b = @as(?Struct, null),
        },
        .{},
    );

    const E = enum (u8) {
        foo,
        bar,
    };
    try expectStringifyEqual(
        ".{ .a = .foo, .b = .foo }",
        .{
            .a = .foo,
            .b = E.foo,
        },
        .{},
    );
}

test "stringify ident" {
    var buffer = std.ArrayList(u8).init(std.testing.allocator);
    defer buffer.deinit();
    const writer = buffer.writer();
    var serializer = stringifier(writer, .{});

    try serializer.ident("a");
    try std.testing.expectEqualStrings("a", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.ident("foo_1");
    try std.testing.expectEqualStrings("foo_1", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.ident("_foo_1");
    try std.testing.expectEqualStrings("_foo_1", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.ident("foo bar");
    try std.testing.expectEqualStrings("@\"foo bar\"", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.ident("1foo");
    try std.testing.expectEqualStrings("@\"1foo\"", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.ident("var");
    try std.testing.expectEqualStrings("@\"var\"", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.ident("true");
    try std.testing.expectEqualStrings("true", buffer.items);
    buffer.clearRetainingCapacity();

    try serializer.ident("_");
    try std.testing.expectEqualStrings("_", buffer.items);
    buffer.clearRetainingCapacity();

    const Enum = enum {
        @"foo bar",
    };
    try expectStringifyEqual(".{ .@\"var\" = .@\"foo bar\", .@\"1\" = .@\"foo bar\" }", .{
        .@"var" = .@"foo bar",
        .@"1" = Enum.@"foo bar",
    }, .{});
}
