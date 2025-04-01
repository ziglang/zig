//! ZON can be serialized with `serialize`.
//!
//! The following functions are provided for serializing recursive types:
//! * `serializeMaxDepth`
//! * `serializeArbitraryDepth`
//!
//! For additional control over serialization, see `Serializer`.
//!
//! The following types and any types that contain them may not be serialized:
//! * `type`
//! * `void`, except as a union payload
//! * `noreturn`
//! * Error sets/error unions
//! * Untagged unions
//! * Many-pointers or C-pointers
//! * Opaque types, including `anyopaque`
//! * Async frame types, including `anyframe` and `anyframe->T`
//! * Functions
//!
//! All other types are valid. Unsupported types will fail to serialize at compile time. Pointers
//! are followed.

const std = @import("std");
const assert = std.debug.assert;

/// Options for `serialize`.
pub const SerializeOptions = struct {
    /// If false, whitespace is omitted. Otherwise whitespace is emitted in standard Zig style.
    whitespace: bool = true,
    /// Determines when to emit Unicode code point literals as opposed to integer literals.
    emit_codepoint_literals: EmitCodepointLiterals = .never,
    /// If true, slices of `u8`s, and pointers to arrays of `u8` are serialized as containers.
    /// Otherwise they are serialized as string literals.
    emit_strings_as_containers: bool = false,
    /// If false, struct fields are not written if they are equal to their default value. Comparison
    /// is done by `std.meta.eql`.
    emit_default_optional_fields: bool = true,
};

/// Serialize the given value as ZON.
///
/// It is asserted at comptime that `@TypeOf(val)` is not a recursive type.
pub fn serialize(
    val: anytype,
    options: SerializeOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    var sz = serializer(writer, .{
        .whitespace = options.whitespace,
    });
    try sz.value(val, .{
        .emit_codepoint_literals = options.emit_codepoint_literals,
        .emit_strings_as_containers = options.emit_strings_as_containers,
        .emit_default_optional_fields = options.emit_default_optional_fields,
    });
}

/// Like `serialize`, but recursive types are allowed.
///
/// Returns `error.ExceededMaxDepth` if `depth` is exceeded. Every nested value adds one to a
/// value's depth.
pub fn serializeMaxDepth(
    val: anytype,
    options: SerializeOptions,
    writer: anytype,
    depth: usize,
) (@TypeOf(writer).Error || error{ExceededMaxDepth})!void {
    var sz = serializer(writer, .{
        .whitespace = options.whitespace,
    });
    try sz.valueMaxDepth(val, .{
        .emit_codepoint_literals = options.emit_codepoint_literals,
        .emit_strings_as_containers = options.emit_strings_as_containers,
        .emit_default_optional_fields = options.emit_default_optional_fields,
    }, depth);
}

/// Like `serialize`, but recursive types are allowed.
///
/// It is the caller's responsibility to ensure that `val` does not contain cycles.
pub fn serializeArbitraryDepth(
    val: anytype,
    options: SerializeOptions,
    writer: anytype,
) @TypeOf(writer).Error!void {
    var sz = serializer(writer, .{
        .whitespace = options.whitespace,
    });
    try sz.valueArbitraryDepth(val, .{
        .emit_codepoint_literals = options.emit_codepoint_literals,
        .emit_strings_as_containers = options.emit_strings_as_containers,
        .emit_default_optional_fields = options.emit_default_optional_fields,
    });
}

fn typeIsRecursive(comptime T: type) bool {
    return comptime typeIsRecursiveImpl(T, &.{});
}

fn typeIsRecursiveImpl(comptime T: type, comptime prev_visited: []const type) bool {
    for (prev_visited) |V| {
        if (V == T) return true;
    }
    const visited = prev_visited ++ .{T};

    return switch (@typeInfo(T)) {
        .pointer => |pointer| typeIsRecursiveImpl(pointer.child, visited),
        .optional => |optional| typeIsRecursiveImpl(optional.child, visited),
        .array => |array| typeIsRecursiveImpl(array.child, visited),
        .vector => |vector| typeIsRecursiveImpl(vector.child, visited),
        .@"struct" => |@"struct"| for (@"struct".fields) |field| {
            if (typeIsRecursiveImpl(field.type, visited)) break true;
        } else false,
        .@"union" => |@"union"| inline for (@"union".fields) |field| {
            if (typeIsRecursiveImpl(field.type, visited)) break true;
        } else false,
        else => false,
    };
}

fn canSerializeType(T: type) bool {
    comptime return canSerializeTypeInner(T, &.{}, false);
}

fn canSerializeTypeInner(
    T: type,
    /// Visited structs and unions, to avoid infinite recursion.
    /// Tracking more types is unnecessary, and a little complex due to optional nesting.
    visited: []const type,
    parent_is_optional: bool,
) bool {
    return switch (@typeInfo(T)) {
        .bool,
        .int,
        .float,
        .comptime_float,
        .comptime_int,
        .null,
        .enum_literal,
        => true,

        .noreturn,
        .void,
        .type,
        .undefined,
        .error_union,
        .error_set,
        .@"fn",
        .frame,
        .@"anyframe",
        .@"opaque",
        => false,

        .@"enum" => |@"enum"| @"enum".is_exhaustive,

        .pointer => |pointer| switch (pointer.size) {
            .one => canSerializeTypeInner(pointer.child, visited, parent_is_optional),
            .slice => canSerializeTypeInner(pointer.child, visited, false),
            .many, .c => false,
        },

        .optional => |optional| if (parent_is_optional)
            false
        else
            canSerializeTypeInner(optional.child, visited, true),

        .array => |array| canSerializeTypeInner(array.child, visited, false),
        .vector => |vector| canSerializeTypeInner(vector.child, visited, false),

        .@"struct" => |@"struct"| {
            for (visited) |V| if (T == V) return true;
            const new_visited = visited ++ .{T};
            for (@"struct".fields) |field| {
                if (!canSerializeTypeInner(field.type, new_visited, false)) return false;
            }
            return true;
        },
        .@"union" => |@"union"| {
            for (visited) |V| if (T == V) return true;
            const new_visited = visited ++ .{T};
            if (@"union".tag_type == null) return false;
            for (@"union".fields) |field| {
                if (field.type != void and !canSerializeTypeInner(field.type, new_visited, false)) {
                    return false;
                }
            }
            return true;
        },
    };
}

fn isNestedOptional(T: type) bool {
    comptime switch (@typeInfo(T)) {
        .optional => |optional| return isNestedOptionalInner(optional.child),
        else => return false,
    };
}

fn isNestedOptionalInner(T: type) bool {
    switch (@typeInfo(T)) {
        .pointer => |pointer| {
            if (pointer.size == .one) {
                return isNestedOptionalInner(pointer.child);
            } else {
                return false;
            }
        },
        .optional => return true,
        else => return false,
    }
}

test "std.zon stringify canSerializeType" {
    try std.testing.expect(!comptime canSerializeType(void));
    try std.testing.expect(!comptime canSerializeType(struct { f: [*]u8 }));
    try std.testing.expect(!comptime canSerializeType(struct { error{foo} }));
    try std.testing.expect(!comptime canSerializeType(union(enum) { a: void, f: [*c]u8 }));
    try std.testing.expect(!comptime canSerializeType(@Vector(0, [*c]u8)));
    try std.testing.expect(!comptime canSerializeType(*?[*c]u8));
    try std.testing.expect(!comptime canSerializeType(enum(u8) { _ }));
    try std.testing.expect(!comptime canSerializeType(union { foo: void }));
    try std.testing.expect(comptime canSerializeType(union(enum) { foo: void }));
    try std.testing.expect(comptime canSerializeType(comptime_float));
    try std.testing.expect(comptime canSerializeType(comptime_int));
    try std.testing.expect(!comptime canSerializeType(struct { comptime foo: ??u8 = null }));
    try std.testing.expect(comptime canSerializeType(@TypeOf(.foo)));
    try std.testing.expect(comptime canSerializeType(?u8));
    try std.testing.expect(comptime canSerializeType(*?*u8));
    try std.testing.expect(comptime canSerializeType(?struct {
        foo: ?struct {
            ?union(enum) {
                a: ?@Vector(0, ?*u8),
            },
            ?struct {
                f: ?[]?u8,
            },
        },
    }));
    try std.testing.expect(!comptime canSerializeType(??u8));
    try std.testing.expect(!comptime canSerializeType(?*?u8));
    try std.testing.expect(!comptime canSerializeType(*?*?*u8));
    try std.testing.expect(comptime canSerializeType(struct { x: comptime_int = 2 }));
    try std.testing.expect(comptime canSerializeType(struct { x: comptime_float = 2 }));
    try std.testing.expect(comptime canSerializeType(struct { comptime_int }));
    try std.testing.expect(comptime canSerializeType(struct { comptime x: @TypeOf(.foo) = .foo }));
    const Recursive = struct { foo: ?*@This() };
    try std.testing.expect(comptime canSerializeType(Recursive));

    // Make sure we validate nested optional before we early out due to already having seen
    // a type recursion!
    try std.testing.expect(!comptime canSerializeType(struct {
        add_to_visited: ?u8,
        retrieve_from_visited: ??u8,
    }));
}

test "std.zon typeIsRecursive" {
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

fn checkValueDepth(val: anytype, depth: usize) error{ExceededMaxDepth}!void {
    if (depth == 0) return error.ExceededMaxDepth;
    const child_depth = depth - 1;

    switch (@typeInfo(@TypeOf(val))) {
        .pointer => |pointer| switch (pointer.size) {
            .one => try checkValueDepth(val.*, child_depth),
            .slice => for (val) |item| {
                try checkValueDepth(item, child_depth);
            },
            .c, .many => {},
        },
        .array => for (val) |item| {
            try checkValueDepth(item, child_depth);
        },
        .@"struct" => |@"struct"| inline for (@"struct".fields) |field_info| {
            try checkValueDepth(@field(val, field_info.name), child_depth);
        },
        .@"union" => |@"union"| if (@"union".tag_type == null) {
            return;
        } else switch (val) {
            inline else => |payload| {
                return checkValueDepth(payload, child_depth);
            },
        },
        .optional => if (val) |inner| try checkValueDepth(inner, child_depth),
        else => {},
    }
}

fn expectValueDepthEquals(expected: usize, value: anytype) !void {
    try checkValueDepth(value, expected);
    try std.testing.expectError(error.ExceededMaxDepth, checkValueDepth(value, expected - 1));
}

test "std.zon checkValueDepth" {
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
    try expectValueDepthEquals(2, Union{ .x = 1 });
    try expectValueDepthEquals(3, Union{ .y = .{ .x = 1 } });

    const Recurse = struct { r: ?*const @This() };
    try expectValueDepthEquals(2, Recurse{ .r = null });
    try expectValueDepthEquals(5, Recurse{ .r = &Recurse{ .r = null } });
    try expectValueDepthEquals(8, Recurse{ .r = &Recurse{ .r = &Recurse{ .r = null } } });

    try expectValueDepthEquals(2, @as([]const u8, &.{ 1, 2, 3 }));
    try expectValueDepthEquals(3, @as([]const []const u8, &.{&.{ 1, 2, 3 }}));
}

/// Options for `Serializer`.
pub const SerializerOptions = struct {
    /// If false, only syntactically necessary whitespace is emitted.
    whitespace: bool = true,
};

/// Determines when to emit Unicode code point literals as opposed to integer literals.
pub const EmitCodepointLiterals = enum {
    /// Never emit Unicode code point literals.
    never,
    /// Emit Unicode code point literals for any `u8` in the printable ASCII range.
    printable_ascii,
    /// Emit Unicode code point literals for any unsigned integer with 21 bits or fewer
    /// whose value is a valid non-surrogate code point.
    always,

    /// If the value should be emitted as a Unicode codepoint, return it as a u21.
    fn emitAsCodepoint(self: @This(), val: anytype) ?u21 {
        // Rule out incompatible integer types
        switch (@typeInfo(@TypeOf(val))) {
            .int => |int_info| if (int_info.signedness == .signed or int_info.bits > 21) {
                return null;
            },
            .comptime_int => {},
            else => comptime unreachable,
        }

        // Return null if the value shouldn't be printed as a Unicode codepoint, or the value casted
        // to a u21 if it should.
        switch (self) {
            .always => {
                const c = std.math.cast(u21, val) orelse return null;
                if (!std.unicode.utf8ValidCodepoint(c)) return null;
                return c;
            },
            .printable_ascii => {
                const c = std.math.cast(u8, val) orelse return null;
                if (!std.ascii.isPrint(c)) return null;
                return c;
            },
            .never => {
                return null;
            },
        }
    }
};

/// Options for serialization of an individual value.
///
/// See `SerializeOptions` for more information on these options.
pub const ValueOptions = struct {
    emit_codepoint_literals: EmitCodepointLiterals = .never,
    emit_strings_as_containers: bool = false,
    emit_default_optional_fields: bool = true,
};

/// Options for manual serialization of container types.
pub const SerializeContainerOptions = struct {
    /// The whitespace style that should be used for this container. Ignored if whitespace is off.
    whitespace_style: union(enum) {
        /// If true, wrap every field. If false do not.
        wrap: bool,
        /// Automatically decide whether to wrap or not based on the number of fields. Following
        /// the standard rule of thumb, containers with more than two fields are wrapped.
        fields: usize,
    } = .{ .wrap = true },

    fn shouldWrap(self: SerializeContainerOptions) bool {
        return switch (self.whitespace_style) {
            .wrap => |wrap| wrap,
            .fields => |fields| fields > 2,
        };
    }
};

/// Lower level control over serialization, you can create a new instance with `serializer`.
///
/// Useful when you want control over which fields are serialized, how they're represented,
/// or want to write a ZON object that does not exist in memory.
///
/// You can serialize values with `value`. To serialize recursive types, the following are provided:
/// * `valueMaxDepth`
/// * `valueArbitraryDepth`
///
/// You can also serialize values using specific notations:
/// * `int`
/// * `float`
/// * `codePoint`
/// * `tuple`
/// * `tupleMaxDepth`
/// * `tupleArbitraryDepth`
/// * `string`
/// * `multilineString`
///
/// For manual serialization of containers, see:
/// * `beginStruct`
/// * `beginTuple`
///
/// # Example
/// ```zig
/// var sz = serializer(writer, .{});
/// var vec2 = try sz.beginStruct(.{});
/// try vec2.field("x", 1.5, .{});
/// try vec2.fieldPrefix();
/// try sz.value(2.5);
/// try vec2.end();
/// ```
pub fn Serializer(Writer: type) type {
    return struct {
        const Self = @This();

        options: SerializerOptions,
        indent_level: u8,
        writer: Writer,

        /// Initialize a serializer.
        fn init(writer: Writer, options: SerializerOptions) Self {
            return .{
                .options = options,
                .writer = writer,
                .indent_level = 0,
            };
        }

        /// Serialize a value, similar to `serialize`.
        pub fn value(self: *Self, val: anytype, options: ValueOptions) Writer.Error!void {
            comptime assert(!typeIsRecursive(@TypeOf(val)));
            return self.valueArbitraryDepth(val, options);
        }

        /// Serialize a value, similar to `serializeMaxDepth`.
        pub fn valueMaxDepth(
            self: *Self,
            val: anytype,
            options: ValueOptions,
            depth: usize,
        ) (Writer.Error || error{ExceededMaxDepth})!void {
            try checkValueDepth(val, depth);
            return self.valueArbitraryDepth(val, options);
        }

        /// Serialize a value, similar to `serializeArbitraryDepth`.
        pub fn valueArbitraryDepth(
            self: *Self,
            val: anytype,
            options: ValueOptions,
        ) Writer.Error!void {
            comptime assert(canSerializeType(@TypeOf(val)));
            switch (@typeInfo(@TypeOf(val))) {
                .int, .comptime_int => if (options.emit_codepoint_literals.emitAsCodepoint(val)) |c| {
                    self.codePoint(c) catch |err| switch (err) {
                        error.InvalidCodepoint => unreachable, // Already validated
                        else => |e| return e,
                    };
                } else {
                    try self.int(val);
                },
                .float, .comptime_float => try self.float(val),
                .bool, .null => try std.fmt.format(self.writer, "{}", .{val}),
                .enum_literal => try self.ident(@tagName(val)),
                .@"enum" => try self.ident(@tagName(val)),
                .pointer => |pointer| {
                    // Try to serialize as a string
                    const item: ?type = switch (@typeInfo(pointer.child)) {
                        .array => |array| array.child,
                        else => if (pointer.size == .slice) pointer.child else null,
                    };
                    if (item == u8 and
                        (pointer.sentinel() == null or pointer.sentinel() == 0) and
                        !options.emit_strings_as_containers)
                    {
                        return try self.string(val);
                    }

                    // Serialize as either a tuple or as the child type
                    switch (pointer.size) {
                        .slice => try self.tupleImpl(val, options),
                        .one => try self.valueArbitraryDepth(val.*, options),
                        else => comptime unreachable,
                    }
                },
                .array => {
                    var container = try self.beginTuple(
                        .{ .whitespace_style = .{ .fields = val.len } },
                    );
                    for (val) |item_val| {
                        try container.fieldArbitraryDepth(item_val, options);
                    }
                    try container.end();
                },
                .@"struct" => |@"struct"| if (@"struct".is_tuple) {
                    var container = try self.beginTuple(
                        .{ .whitespace_style = .{ .fields = @"struct".fields.len } },
                    );
                    inline for (val) |field_value| {
                        try container.fieldArbitraryDepth(field_value, options);
                    }
                    try container.end();
                } else {
                    // Decide which fields to emit
                    const fields, const skipped: [@"struct".fields.len]bool = if (options.emit_default_optional_fields) b: {
                        break :b .{ @"struct".fields.len, @splat(false) };
                    } else b: {
                        var fields = @"struct".fields.len;
                        var skipped: [@"struct".fields.len]bool = @splat(false);
                        inline for (@"struct".fields, &skipped) |field_info, *skip| {
                            if (field_info.default_value_ptr) |ptr| {
                                const default: *const field_info.type = @ptrCast(@alignCast(ptr));
                                const field_value = @field(val, field_info.name);
                                if (std.meta.eql(field_value, default.*)) {
                                    skip.* = true;
                                    fields -= 1;
                                }
                            }
                        }
                        break :b .{ fields, skipped };
                    };

                    // Emit those fields
                    var container = try self.beginStruct(
                        .{ .whitespace_style = .{ .fields = fields } },
                    );
                    inline for (@"struct".fields, skipped) |field_info, skip| {
                        if (!skip) {
                            try container.fieldArbitraryDepth(
                                field_info.name,
                                @field(val, field_info.name),
                                options,
                            );
                        }
                    }
                    try container.end();
                },
                .@"union" => |@"union"| {
                    comptime assert(@"union".tag_type != null);
                    switch (val) {
                        inline else => |pl, tag| if (@TypeOf(pl) == void)
                            try self.writer.print(".{s}", .{@tagName(tag)})
                        else {
                            var container = try self.beginStruct(.{ .whitespace_style = .{ .fields = 1 } });

                            try container.fieldArbitraryDepth(
                                @tagName(tag),
                                pl,
                                options,
                            );

                            try container.end();
                        },
                    }
                },
                .optional => if (val) |inner| {
                    try self.valueArbitraryDepth(inner, options);
                } else {
                    try self.writer.writeAll("null");
                },
                .vector => |vector| {
                    var container = try self.beginTuple(
                        .{ .whitespace_style = .{ .fields = vector.len } },
                    );
                    for (0..vector.len) |i| {
                        try container.fieldArbitraryDepth(val[i], options);
                    }
                    try container.end();
                },

                else => comptime unreachable,
            }
        }

        /// Serialize an integer.
        pub fn int(self: *Self, val: anytype) Writer.Error!void {
            try std.fmt.formatInt(val, 10, .lower, .{}, self.writer);
        }

        /// Serialize a float.
        pub fn float(self: *Self, val: anytype) Writer.Error!void {
            switch (@typeInfo(@TypeOf(val))) {
                .float => if (std.math.isNan(val)) {
                    return self.writer.writeAll("nan");
                } else if (std.math.isPositiveInf(val)) {
                    return self.writer.writeAll("inf");
                } else if (std.math.isNegativeInf(val)) {
                    return self.writer.writeAll("-inf");
                } else if (std.math.isNegativeZero(val)) {
                    return self.writer.writeAll("-0.0");
                } else {
                    try std.fmt.format(self.writer, "{d}", .{val});
                },
                .comptime_float => if (val == 0) {
                    return self.writer.writeAll("0");
                } else {
                    try std.fmt.format(self.writer, "{d}", .{val});
                },
                else => comptime unreachable,
            }
        }

        /// Serialize `name` as an identifier prefixed with `.`.
        ///
        /// Escapes the identifier if necessary.
        pub fn ident(self: *Self, name: []const u8) Writer.Error!void {
            try self.writer.print(".{p_}", .{std.zig.fmtId(name)});
        }

        /// Serialize `val` as a Unicode codepoint.
        ///
        /// Returns `error.InvalidCodepoint` if `val` is not a valid Unicode codepoint.
        pub fn codePoint(
            self: *Self,
            val: u21,
        ) (Writer.Error || error{InvalidCodepoint})!void {
            var buf: [8]u8 = undefined;
            const len = std.unicode.utf8Encode(val, &buf) catch return error.InvalidCodepoint;
            const str = buf[0..len];
            try std.fmt.format(self.writer, "'{'}'", .{std.zig.fmtEscapes(str)});
        }

        /// Like `value`, but always serializes `val` as a tuple.
        ///
        /// Will fail at comptime if `val` is not a tuple, array, pointer to an array, or slice.
        pub fn tuple(self: *Self, val: anytype, options: ValueOptions) Writer.Error!void {
            comptime assert(!typeIsRecursive(@TypeOf(val)));
            try self.tupleArbitraryDepth(val, options);
        }

        /// Like `tuple`, but recursive types are allowed.
        ///
        /// Returns `error.ExceededMaxDepth` if `depth` is exceeded.
        pub fn tupleMaxDepth(
            self: *Self,
            val: anytype,
            options: ValueOptions,
            depth: usize,
        ) (Writer.Error || error{ExceededMaxDepth})!void {
            try checkValueDepth(val, depth);
            try self.tupleArbitraryDepth(val, options);
        }

        /// Like `tuple`, but recursive types are allowed.
        ///
        /// It is the caller's responsibility to ensure that `val` does not contain cycles.
        pub fn tupleArbitraryDepth(
            self: *Self,
            val: anytype,
            options: ValueOptions,
        ) Writer.Error!void {
            try self.tupleImpl(val, options);
        }

        fn tupleImpl(self: *Self, val: anytype, options: ValueOptions) Writer.Error!void {
            comptime assert(canSerializeType(@TypeOf(val)));
            switch (@typeInfo(@TypeOf(val))) {
                .@"struct" => {
                    var container = try self.beginTuple(.{ .whitespace_style = .{ .fields = val.len } });
                    inline for (val) |item_val| {
                        try container.fieldArbitraryDepth(item_val, options);
                    }
                    try container.end();
                },
                .pointer, .array => {
                    var container = try self.beginTuple(.{ .whitespace_style = .{ .fields = val.len } });
                    for (val) |item_val| {
                        try container.fieldArbitraryDepth(item_val, options);
                    }
                    try container.end();
                },
                else => comptime unreachable,
            }
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
        pub fn multilineString(
            self: *Self,
            val: []const u8,
            options: MultilineStringOptions,
        ) (Writer.Error || error{InnerCarriageReturn})!void {
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
        pub fn beginStruct(
            self: *Self,
            options: SerializeContainerOptions,
        ) Writer.Error!Struct {
            return Struct.begin(self, options);
        }

        /// Creates a `Tuple` for writing ZON tuples field by field.
        pub fn beginTuple(
            self: *Self,
            options: SerializeContainerOptions,
        ) Writer.Error!Tuple {
            return Tuple.begin(self, options);
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

            fn begin(parent: *Self, options: SerializeContainerOptions) Writer.Error!Tuple {
                return .{
                    .container = try Container.begin(parent, .anon, options),
                };
            }

            /// Finishes serializing the tuple.
            ///
            /// Prints a trailing comma as configured when appropriate, and the closing bracket.
            pub fn end(self: *Tuple) Writer.Error!void {
                try self.container.end();
                self.* = undefined;
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `value`.
            pub fn field(
                self: *Tuple,
                val: anytype,
                options: ValueOptions,
            ) Writer.Error!void {
                try self.container.field(null, val, options);
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `valueMaxDepth`.
            pub fn fieldMaxDepth(
                self: *Tuple,
                val: anytype,
                options: ValueOptions,
                depth: usize,
            ) (Writer.Error || error{ExceededMaxDepth})!void {
                try self.container.fieldMaxDepth(null, val, options, depth);
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by
            /// `valueArbitraryDepth`.
            pub fn fieldArbitraryDepth(
                self: *Tuple,
                val: anytype,
                options: ValueOptions,
            ) Writer.Error!void {
                try self.container.fieldArbitraryDepth(null, val, options);
            }

            /// Starts a field with a struct as a value. Returns the struct.
            pub fn beginStructField(
                self: *Tuple,
                options: SerializeContainerOptions,
            ) Writer.Error!Struct {
                try self.fieldPrefix();
                return self.container.serializer.beginStruct(options);
            }

            /// Starts a field with a tuple as a value. Returns the tuple.
            pub fn beginTupleField(
                self: *Tuple,
                options: SerializeContainerOptions,
            ) Writer.Error!Tuple {
                try self.fieldPrefix();
                return self.container.serializer.beginTuple(options);
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

            fn begin(parent: *Self, options: SerializeContainerOptions) Writer.Error!Struct {
                return .{
                    .container = try Container.begin(parent, .named, options),
                };
            }

            /// Finishes serializing the struct.
            ///
            /// Prints a trailing comma as configured when appropriate, and the closing bracket.
            pub fn end(self: *Struct) Writer.Error!void {
                try self.container.end();
                self.* = undefined;
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `value`.
            pub fn field(
                self: *Struct,
                name: []const u8,
                val: anytype,
                options: ValueOptions,
            ) Writer.Error!void {
                try self.container.field(name, val, options);
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `valueMaxDepth`.
            pub fn fieldMaxDepth(
                self: *Struct,
                name: []const u8,
                val: anytype,
                options: ValueOptions,
                depth: usize,
            ) (Writer.Error || error{ExceededMaxDepth})!void {
                try self.container.fieldMaxDepth(name, val, options, depth);
            }

            /// Serialize a field. Equivalent to calling `fieldPrefix` followed by
            /// `valueArbitraryDepth`.
            pub fn fieldArbitraryDepth(
                self: *Struct,
                name: []const u8,
                val: anytype,
                options: ValueOptions,
            ) Writer.Error!void {
                try self.container.fieldArbitraryDepth(name, val, options);
            }

            /// Starts a field with a struct as a value. Returns the struct.
            pub fn beginStructField(
                self: *Struct,
                name: []const u8,
                options: SerializeContainerOptions,
            ) Writer.Error!Struct {
                try self.fieldPrefix(name);
                return self.container.serializer.beginStruct(options);
            }

            /// Starts a field with a tuple as a value. Returns the tuple.
            pub fn beginTupleField(
                self: *Struct,
                name: []const u8,
                options: SerializeContainerOptions,
            ) Writer.Error!Tuple {
                try self.fieldPrefix(name);
                return self.container.serializer.beginTuple(options);
            }

            /// Print a field prefix. This prints any necessary commas, the field name (escaped if
            /// necessary) and whitespace as configured. Useful if you want to serialize the field
            /// value yourself.
            pub fn fieldPrefix(self: *Struct, name: []const u8) Writer.Error!void {
                try self.container.fieldPrefix(name);
            }
        };

        const Container = struct {
            const FieldStyle = enum { named, anon };

            serializer: *Self,
            field_style: FieldStyle,
            options: SerializeContainerOptions,
            empty: bool,

            fn begin(
                sz: *Self,
                field_style: FieldStyle,
                options: SerializeContainerOptions,
            ) Writer.Error!Container {
                if (options.shouldWrap()) sz.indent_level +|= 1;
                try sz.writer.writeAll(".{");
                return .{
                    .serializer = sz,
                    .field_style = field_style,
                    .options = options,
                    .empty = true,
                };
            }

            fn end(self: *Container) Writer.Error!void {
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
                    try self.serializer.ident(n);
                    try self.serializer.space();
                    try self.serializer.writer.writeByte('=');
                    try self.serializer.space();
                }
            }

            fn field(
                self: *Container,
                name: ?[]const u8,
                val: anytype,
                options: ValueOptions,
            ) Writer.Error!void {
                comptime assert(!typeIsRecursive(@TypeOf(val)));
                try self.fieldArbitraryDepth(name, val, options);
            }

            fn fieldMaxDepth(
                self: *Container,
                name: ?[]const u8,
                val: anytype,
                options: ValueOptions,
                depth: usize,
            ) (Writer.Error || error{ExceededMaxDepth})!void {
                try checkValueDepth(val, depth);
                try self.fieldArbitraryDepth(name, val, options);
            }

            fn fieldArbitraryDepth(
                self: *Container,
                name: ?[]const u8,
                val: anytype,
                options: ValueOptions,
            ) Writer.Error!void {
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
    };
}

/// Creates a new `Serializer` with the given writer and options.
pub fn serializer(writer: anytype, options: SerializerOptions) Serializer(@TypeOf(writer)) {
    return .init(writer, options);
}

fn expectSerializeEqual(
    expected: []const u8,
    value: anytype,
    options: SerializeOptions,
) !void {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    try serialize(value, options, buf.writer());
    try std.testing.expectEqualStrings(expected, buf.items);
}

test "std.zon stringify whitespace, high level API" {
    try expectSerializeEqual(".{}", .{}, .{});
    try expectSerializeEqual(".{}", .{}, .{ .whitespace = false });

    try expectSerializeEqual(".{1}", .{1}, .{});
    try expectSerializeEqual(".{1}", .{1}, .{ .whitespace = false });

    try expectSerializeEqual(".{1}", @as([1]u32, .{1}), .{});
    try expectSerializeEqual(".{1}", @as([1]u32, .{1}), .{ .whitespace = false });

    try expectSerializeEqual(".{1}", @as([]const u32, &.{1}), .{});
    try expectSerializeEqual(".{1}", @as([]const u32, &.{1}), .{ .whitespace = false });

    try expectSerializeEqual(".{ .x = 1 }", .{ .x = 1 }, .{});
    try expectSerializeEqual(".{.x=1}", .{ .x = 1 }, .{ .whitespace = false });

    try expectSerializeEqual(".{ 1, 2 }", .{ 1, 2 }, .{});
    try expectSerializeEqual(".{1,2}", .{ 1, 2 }, .{ .whitespace = false });

    try expectSerializeEqual(".{ 1, 2 }", @as([2]u32, .{ 1, 2 }), .{});
    try expectSerializeEqual(".{1,2}", @as([2]u32, .{ 1, 2 }), .{ .whitespace = false });

    try expectSerializeEqual(".{ 1, 2 }", @as([]const u32, &.{ 1, 2 }), .{});
    try expectSerializeEqual(".{1,2}", @as([]const u32, &.{ 1, 2 }), .{ .whitespace = false });

    try expectSerializeEqual(".{ .x = 1, .y = 2 }", .{ .x = 1, .y = 2 }, .{});
    try expectSerializeEqual(".{.x=1,.y=2}", .{ .x = 1, .y = 2 }, .{ .whitespace = false });

    try expectSerializeEqual(
        \\.{
        \\    1,
        \\    2,
        \\    3,
        \\}
    , .{ 1, 2, 3 }, .{});
    try expectSerializeEqual(".{1,2,3}", .{ 1, 2, 3 }, .{ .whitespace = false });

    try expectSerializeEqual(
        \\.{
        \\    1,
        \\    2,
        \\    3,
        \\}
    , @as([3]u32, .{ 1, 2, 3 }), .{});
    try expectSerializeEqual(".{1,2,3}", @as([3]u32, .{ 1, 2, 3 }), .{ .whitespace = false });

    try expectSerializeEqual(
        \\.{
        \\    1,
        \\    2,
        \\    3,
        \\}
    , @as([]const u32, &.{ 1, 2, 3 }), .{});
    try expectSerializeEqual(
        ".{1,2,3}",
        @as([]const u32, &.{ 1, 2, 3 }),
        .{ .whitespace = false },
    );

    try expectSerializeEqual(
        \\.{
        \\    .x = 1,
        \\    .y = 2,
        \\    .z = 3,
        \\}
    , .{ .x = 1, .y = 2, .z = 3 }, .{});
    try expectSerializeEqual(
        ".{.x=1,.y=2,.z=3}",
        .{ .x = 1, .y = 2, .z = 3 },
        .{ .whitespace = false },
    );

    const Union = union(enum) { a: bool, b: i32, c: u8 };

    try expectSerializeEqual(".{ .b = 1 }", Union{ .b = 1 }, .{});
    try expectSerializeEqual(".{.b=1}", Union{ .b = 1 }, .{ .whitespace = false });

    // Nested indentation where outer object doesn't wrap
    try expectSerializeEqual(
        \\.{ .inner = .{
        \\    1,
        \\    2,
        \\    3,
        \\} }
    , .{ .inner = .{ 1, 2, 3 } }, .{});

    const UnionWithVoid = union(enum) { a, b: void, c: u8 };

    try expectSerializeEqual(
        \\.a
    , UnionWithVoid.a, .{});
}

test "std.zon stringify whitespace, low level API" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    var sz = serializer(buf.writer(), .{});

    inline for (.{ true, false }) |whitespace| {
        sz.options = .{ .whitespace = whitespace };

        // Empty containers
        {
            var container = try sz.beginStruct(.{});
            try container.end();
            try std.testing.expectEqualStrings(".{}", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginTuple(.{});
            try container.end();
            try std.testing.expectEqualStrings(".{}", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.end();
            try std.testing.expectEqualStrings(".{}", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.end();
            try std.testing.expectEqualStrings(".{}", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginStruct(.{ .whitespace_style = .{ .fields = 0 } });
            try container.end();
            try std.testing.expectEqualStrings(".{}", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginTuple(.{ .whitespace_style = .{ .fields = 0 } });
            try container.end();
            try std.testing.expectEqualStrings(".{}", buf.items);
            buf.clearRetainingCapacity();
        }

        // Size 1
        {
            var container = try sz.beginStruct(.{});
            try container.field("a", 1, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\}
                , buf.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginTuple(.{});
            try container.field(1, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\}
                , buf.items);
            } else {
                try std.testing.expectEqualStrings(".{1}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1 }", buf.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            // We get extra spaces here, since we didn't know up front that there would only be one
            // field.
            var container = try sz.beginTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1 }", buf.items);
            } else {
                try std.testing.expectEqualStrings(".{1}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginStruct(.{ .whitespace_style = .{ .fields = 1 } });
            try container.field("a", 1, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1 }", buf.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginTuple(.{ .whitespace_style = .{ .fields = 1 } });
            try container.field(1, .{});
            try container.end();
            try std.testing.expectEqualStrings(".{1}", buf.items);
            buf.clearRetainingCapacity();
        }

        // Size 2
        {
            var container = try sz.beginStruct(.{});
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\    .b = 2,
                    \\}
                , buf.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginTuple(.{});
            try container.field(1, .{});
            try container.field(2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\    2,
                    \\}
                , buf.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2 }", buf.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2 }", buf.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginStruct(.{ .whitespace_style = .{ .fields = 2 } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2 }", buf.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginTuple(.{ .whitespace_style = .{ .fields = 2 } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2 }", buf.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        // Size 3
        {
            var container = try sz.beginStruct(.{});
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.field("c", 3, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\    .b = 2,
                    \\    .c = 3,
                    \\}
                , buf.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginTuple(.{});
            try container.field(1, .{});
            try container.field(2, .{});
            try container.field(3, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\    2,
                    \\    3,
                    \\}
                , buf.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.field("c", 3, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2, .c = 3 }", buf.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.field(3, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2, 3 }", buf.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginStruct(.{ .whitespace_style = .{ .fields = 3 } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.field("c", 3, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\    .b = 2,
                    \\    .c = 3,
                    \\}
                , buf.items);
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            var container = try sz.beginTuple(.{ .whitespace_style = .{ .fields = 3 } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.field(3, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\    2,
                    \\    3,
                    \\}
                , buf.items);
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        // Nested objects where the outer container doesn't wrap but the inner containers do
        {
            var container = try sz.beginStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("first", .{ 1, 2, 3 }, .{});
            try container.field("second", .{ 4, 5, 6 }, .{});
            try container.end();
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
                , buf.items);
            } else {
                try std.testing.expectEqualStrings(
                    ".{.first=.{1,2,3},.second=.{4,5,6}}",
                    buf.items,
                );
            }
            buf.clearRetainingCapacity();
        }
    }
}

test "std.zon stringify utf8 codepoints" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    var sz = serializer(buf.writer(), .{});

    // Printable ASCII
    try sz.int('a');
    try std.testing.expectEqualStrings("97", buf.items);
    buf.clearRetainingCapacity();

    try sz.codePoint('a');
    try std.testing.expectEqualStrings("'a'", buf.items);
    buf.clearRetainingCapacity();

    try sz.value('a', .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings("'a'", buf.items);
    buf.clearRetainingCapacity();

    try sz.value('a', .{ .emit_codepoint_literals = .printable_ascii });
    try std.testing.expectEqualStrings("'a'", buf.items);
    buf.clearRetainingCapacity();

    try sz.value('a', .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings("97", buf.items);
    buf.clearRetainingCapacity();

    // Short escaped codepoint
    try sz.int('\n');
    try std.testing.expectEqualStrings("10", buf.items);
    buf.clearRetainingCapacity();

    try sz.codePoint('\n');
    try std.testing.expectEqualStrings("'\\n'", buf.items);
    buf.clearRetainingCapacity();

    try sz.value('\n', .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings("'\\n'", buf.items);
    buf.clearRetainingCapacity();

    try sz.value('\n', .{ .emit_codepoint_literals = .printable_ascii });
    try std.testing.expectEqualStrings("10", buf.items);
    buf.clearRetainingCapacity();

    try sz.value('\n', .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings("10", buf.items);
    buf.clearRetainingCapacity();

    // Large codepoint
    try sz.int('⚡');
    try std.testing.expectEqualStrings("9889", buf.items);
    buf.clearRetainingCapacity();

    try sz.codePoint('⚡');
    try std.testing.expectEqualStrings("'\\xe2\\x9a\\xa1'", buf.items);
    buf.clearRetainingCapacity();

    try sz.value('⚡', .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings("'\\xe2\\x9a\\xa1'", buf.items);
    buf.clearRetainingCapacity();

    try sz.value('⚡', .{ .emit_codepoint_literals = .printable_ascii });
    try std.testing.expectEqualStrings("9889", buf.items);
    buf.clearRetainingCapacity();

    try sz.value('⚡', .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings("9889", buf.items);
    buf.clearRetainingCapacity();

    // Invalid codepoint
    try std.testing.expectError(error.InvalidCodepoint, sz.codePoint(0x110000 + 1));

    try sz.int(0x110000 + 1);
    try std.testing.expectEqualStrings("1114113", buf.items);
    buf.clearRetainingCapacity();

    try sz.value(0x110000 + 1, .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings("1114113", buf.items);
    buf.clearRetainingCapacity();

    try sz.value(0x110000 + 1, .{ .emit_codepoint_literals = .printable_ascii });
    try std.testing.expectEqualStrings("1114113", buf.items);
    buf.clearRetainingCapacity();

    try sz.value(0x110000 + 1, .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings("1114113", buf.items);
    buf.clearRetainingCapacity();

    // Valid codepoint, not a codepoint type
    try sz.value(@as(u22, 'a'), .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings("97", buf.items);
    buf.clearRetainingCapacity();

    try sz.value(@as(u22, 'a'), .{ .emit_codepoint_literals = .printable_ascii });
    try std.testing.expectEqualStrings("97", buf.items);
    buf.clearRetainingCapacity();

    try sz.value(@as(i32, 'a'), .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings("97", buf.items);
    buf.clearRetainingCapacity();

    // Make sure value options are passed to children
    try sz.value(.{ .c = '⚡' }, .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings(".{ .c = '\\xe2\\x9a\\xa1' }", buf.items);
    buf.clearRetainingCapacity();

    try sz.value(.{ .c = '⚡' }, .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings(".{ .c = 9889 }", buf.items);
    buf.clearRetainingCapacity();
}

test "std.zon stringify strings" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    var sz = serializer(buf.writer(), .{});

    // Minimal case
    try sz.string("abc⚡\n");
    try std.testing.expectEqualStrings("\"abc\\xe2\\x9a\\xa1\\n\"", buf.items);
    buf.clearRetainingCapacity();

    try sz.tuple("abc⚡\n", .{});
    try std.testing.expectEqualStrings(
        \\.{
        \\    97,
        \\    98,
        \\    99,
        \\    226,
        \\    154,
        \\    161,
        \\    10,
        \\}
    , buf.items);
    buf.clearRetainingCapacity();

    try sz.value("abc⚡\n", .{});
    try std.testing.expectEqualStrings("\"abc\\xe2\\x9a\\xa1\\n\"", buf.items);
    buf.clearRetainingCapacity();

    try sz.value("abc⚡\n", .{ .emit_strings_as_containers = true });
    try std.testing.expectEqualStrings(
        \\.{
        \\    97,
        \\    98,
        \\    99,
        \\    226,
        \\    154,
        \\    161,
        \\    10,
        \\}
    , buf.items);
    buf.clearRetainingCapacity();

    // Value options are inherited by children
    try sz.value(.{ .str = "abc" }, .{});
    try std.testing.expectEqualStrings(".{ .str = \"abc\" }", buf.items);
    buf.clearRetainingCapacity();

    try sz.value(.{ .str = "abc" }, .{ .emit_strings_as_containers = true });
    try std.testing.expectEqualStrings(
        \\.{ .str = .{
        \\    97,
        \\    98,
        \\    99,
        \\} }
    , buf.items);
    buf.clearRetainingCapacity();

    // Arrays (rather than pointers to arrays) of u8s are not considered strings, so that data can
    // round trip correctly.
    try sz.value("abc".*, .{});
    try std.testing.expectEqualStrings(
        \\.{
        \\    97,
        \\    98,
        \\    99,
        \\}
    , buf.items);
    buf.clearRetainingCapacity();
}

test "std.zon stringify multiline strings" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    var sz = serializer(buf.writer(), .{});

    inline for (.{ true, false }) |whitespace| {
        sz.options.whitespace = whitespace;

        {
            try sz.multilineString("", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try sz.multilineString("abc⚡", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\abc⚡", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try sz.multilineString("abc⚡\ndef", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\abc⚡\n\\\\def", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try sz.multilineString("abc⚡\r\ndef", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\abc⚡\n\\\\def", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try sz.multilineString("\nabc⚡", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\\n\\\\abc⚡", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try sz.multilineString("\r\nabc⚡", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\\n\\\\abc⚡", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try sz.multilineString("abc\ndef", .{});
            if (whitespace) {
                try std.testing.expectEqualStrings("\n\\\\abc\n\\\\def\n", buf.items);
            } else {
                try std.testing.expectEqualStrings("\\\\abc\n\\\\def\n", buf.items);
            }
            buf.clearRetainingCapacity();
        }

        {
            const str: []const u8 = &.{ 'a', '\r', 'c' };
            try sz.string(str);
            try std.testing.expectEqualStrings("\"a\\rc\"", buf.items);
            buf.clearRetainingCapacity();
        }

        {
            try std.testing.expectError(
                error.InnerCarriageReturn,
                sz.multilineString(@as([]const u8, &.{ 'a', '\r', 'c' }), .{}),
            );
            try std.testing.expectError(
                error.InnerCarriageReturn,
                sz.multilineString(@as([]const u8, &.{ 'a', '\r', 'c', '\n' }), .{}),
            );
            try std.testing.expectError(
                error.InnerCarriageReturn,
                sz.multilineString(@as([]const u8, &.{ 'a', '\r', 'c', '\r', '\n' }), .{}),
            );
            try std.testing.expectEqualStrings("", buf.items);
            buf.clearRetainingCapacity();
        }
    }
}

test "std.zon stringify skip default fields" {
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
    try expectSerializeEqual(
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
    ,
        Struct{
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
        .{ .emit_codepoint_literals = .always },
    );

    // Top level defaults
    try expectSerializeEqual(
        \\.{ .y = 3, .inner3 = .{
        \\    'a',
        \\    'b',
        \\    'd',
        \\} }
    ,
        Struct{
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
            .emit_codepoint_literals = .always,
        },
    );

    // Inner types having defaults, and defaults changing the number of fields affecting the
    // formatting
    try expectSerializeEqual(
        \\.{
        \\    .y = 3,
        \\    .inner1 = .{ .b = '2', .c = '3' },
        \\    .inner3 = .{
        \\        'a',
        \\        'b',
        \\        'd',
        \\    },
        \\}
    ,
        Struct{
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
            .emit_codepoint_literals = .always,
        },
    );

    const DefaultStrings = struct {
        foo: []const u8 = "abc",
    };
    try expectSerializeEqual(
        \\.{}
    ,
        DefaultStrings{ .foo = "abc" },
        .{ .emit_default_optional_fields = false },
    );
    try expectSerializeEqual(
        \\.{ .foo = "abcd" }
    ,
        DefaultStrings{ .foo = "abcd" },
        .{ .emit_default_optional_fields = false },
    );
}

test "std.zon depth limits" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();

    const Recurse = struct { r: []const @This() };

    // Normal operation
    try serializeMaxDepth(.{ 1, .{ 2, 3 } }, .{}, buf.writer(), 16);
    try std.testing.expectEqualStrings(".{ 1, .{ 2, 3 } }", buf.items);
    buf.clearRetainingCapacity();

    try serializeArbitraryDepth(.{ 1, .{ 2, 3 } }, .{}, buf.writer());
    try std.testing.expectEqualStrings(".{ 1, .{ 2, 3 } }", buf.items);
    buf.clearRetainingCapacity();

    // Max depth failing on non recursive type
    try std.testing.expectError(
        error.ExceededMaxDepth,
        serializeMaxDepth(.{ 1, .{ 2, .{ 3, 4 } } }, .{}, buf.writer(), 3),
    );
    try std.testing.expectEqualStrings("", buf.items);
    buf.clearRetainingCapacity();

    // Max depth passing on recursive type
    {
        const maybe_recurse = Recurse{ .r = &.{} };
        try serializeMaxDepth(maybe_recurse, .{}, buf.writer(), 2);
        try std.testing.expectEqualStrings(".{ .r = .{} }", buf.items);
        buf.clearRetainingCapacity();
    }

    // Unchecked passing on recursive type
    {
        const maybe_recurse = Recurse{ .r = &.{} };
        try serializeArbitraryDepth(maybe_recurse, .{}, buf.writer());
        try std.testing.expectEqualStrings(".{ .r = .{} }", buf.items);
        buf.clearRetainingCapacity();
    }

    // Max depth failing on recursive type due to depth
    {
        var maybe_recurse = Recurse{ .r = &.{} };
        maybe_recurse.r = &.{.{ .r = &.{} }};
        try std.testing.expectError(
            error.ExceededMaxDepth,
            serializeMaxDepth(maybe_recurse, .{}, buf.writer(), 2),
        );
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();
    }

    // Same but for a slice
    {
        var temp: [1]Recurse = .{.{ .r = &.{} }};
        const maybe_recurse: []const Recurse = &temp;

        try std.testing.expectError(
            error.ExceededMaxDepth,
            serializeMaxDepth(maybe_recurse, .{}, buf.writer(), 2),
        );
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();

        var sz = serializer(buf.writer(), .{});

        try std.testing.expectError(
            error.ExceededMaxDepth,
            sz.tupleMaxDepth(maybe_recurse, .{}, 2),
        );
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();

        try sz.tupleArbitraryDepth(maybe_recurse, .{});
        try std.testing.expectEqualStrings(".{.{ .r = .{} }}", buf.items);
        buf.clearRetainingCapacity();
    }

    // A slice succeeding
    {
        var temp: [1]Recurse = .{.{ .r = &.{} }};
        const maybe_recurse: []const Recurse = &temp;

        try serializeMaxDepth(maybe_recurse, .{}, buf.writer(), 3);
        try std.testing.expectEqualStrings(".{.{ .r = .{} }}", buf.items);
        buf.clearRetainingCapacity();

        var sz = serializer(buf.writer(), .{});

        try sz.tupleMaxDepth(maybe_recurse, .{}, 3);
        try std.testing.expectEqualStrings(".{.{ .r = .{} }}", buf.items);
        buf.clearRetainingCapacity();

        try sz.tupleArbitraryDepth(maybe_recurse, .{});
        try std.testing.expectEqualStrings(".{.{ .r = .{} }}", buf.items);
        buf.clearRetainingCapacity();
    }

    // Max depth failing on recursive type due to recursion
    {
        var temp: [1]Recurse = .{.{ .r = &.{} }};
        temp[0].r = &temp;
        const maybe_recurse: []const Recurse = &temp;

        try std.testing.expectError(
            error.ExceededMaxDepth,
            serializeMaxDepth(maybe_recurse, .{}, buf.writer(), 128),
        );
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();

        var sz = serializer(buf.writer(), .{});
        try std.testing.expectError(
            error.ExceededMaxDepth,
            sz.tupleMaxDepth(maybe_recurse, .{}, 128),
        );
        try std.testing.expectEqualStrings("", buf.items);
        buf.clearRetainingCapacity();
    }

    // Max depth on other parts of the lower level API
    {
        var sz = serializer(buf.writer(), .{});

        const maybe_recurse: []const Recurse = &.{};

        try std.testing.expectError(error.ExceededMaxDepth, sz.valueMaxDepth(1, .{}, 0));
        try sz.valueMaxDepth(2, .{}, 1);
        try sz.value(3, .{});
        try sz.valueArbitraryDepth(maybe_recurse, .{});

        var s = try sz.beginStruct(.{});
        try std.testing.expectError(error.ExceededMaxDepth, s.fieldMaxDepth("a", 1, .{}, 0));
        try s.fieldMaxDepth("b", 4, .{}, 1);
        try s.field("c", 5, .{});
        try s.fieldArbitraryDepth("d", maybe_recurse, .{});
        try s.end();

        var t = try sz.beginTuple(.{});
        try std.testing.expectError(error.ExceededMaxDepth, t.fieldMaxDepth(1, .{}, 0));
        try t.fieldMaxDepth(6, .{}, 1);
        try t.field(7, .{});
        try t.fieldArbitraryDepth(maybe_recurse, .{});
        try t.end();

        var a = try sz.beginTuple(.{});
        try std.testing.expectError(error.ExceededMaxDepth, a.fieldMaxDepth(1, .{}, 0));
        try a.fieldMaxDepth(8, .{}, 1);
        try a.field(9, .{});
        try a.fieldArbitraryDepth(maybe_recurse, .{});
        try a.end();

        try std.testing.expectEqualStrings(
            \\23.{}.{
            \\    .b = 4,
            \\    .c = 5,
            \\    .d = .{},
            \\}.{
            \\    6,
            \\    7,
            \\    .{},
            \\}.{
            \\    8,
            \\    9,
            \\    .{},
            \\}
        , buf.items);
    }
}

test "std.zon stringify primitives" {
    // Issue: https://github.com/ziglang/zig/issues/20880
    if (@import("builtin").zig_backend == .stage2_c) return error.SkipZigTest;

    try expectSerializeEqual(
        \\.{
        \\    .a = 1.5,
        \\    .b = 0.3333333333333333333333333333333333,
        \\    .c = 3.1415926535897932384626433832795028,
        \\    .d = 0,
        \\    .e = 0,
        \\    .f = -0.0,
        \\    .g = inf,
        \\    .h = -inf,
        \\    .i = nan,
        \\}
    ,
        .{
            .a = @as(f128, 1.5), // Make sure explicit f128s work
            .b = 1.0 / 3.0,
            .c = std.math.pi,
            .d = 0.0,
            .e = -0.0,
            .f = @as(f128, -0.0),
            .g = std.math.inf(f32),
            .h = -std.math.inf(f32),
            .i = std.math.nan(f32),
        },
        .{},
    );

    try expectSerializeEqual(
        \\.{
        \\    .a = 18446744073709551616,
        \\    .b = -18446744073709551616,
        \\    .c = 680564733841876926926749214863536422912,
        \\    .d = -680564733841876926926749214863536422912,
        \\    .e = 0,
        \\}
    ,
        .{
            .a = 18446744073709551616,
            .b = -18446744073709551616,
            .c = 680564733841876926926749214863536422912,
            .d = -680564733841876926926749214863536422912,
            .e = 0,
        },
        .{},
    );

    try expectSerializeEqual(
        \\.{
        \\    .a = true,
        \\    .b = false,
        \\    .c = .foo,
        \\    .e = null,
        \\}
    ,
        .{
            .a = true,
            .b = false,
            .c = .foo,
            .e = null,
        },
        .{},
    );

    const Struct = struct { x: f32, y: f32 };
    try expectSerializeEqual(
        ".{ .a = .{ .x = 1, .y = 2 }, .b = null }",
        .{
            .a = @as(?Struct, .{ .x = 1, .y = 2 }),
            .b = @as(?Struct, null),
        },
        .{},
    );

    const E = enum(u8) {
        foo,
        bar,
    };
    try expectSerializeEqual(
        ".{ .a = .foo, .b = .foo }",
        .{
            .a = .foo,
            .b = E.foo,
        },
        .{},
    );
}

test "std.zon stringify ident" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    var sz = serializer(buf.writer(), .{});

    try expectSerializeEqual(".{ .a = 0 }", .{ .a = 0 }, .{});
    try sz.ident("a");
    try std.testing.expectEqualStrings(".a", buf.items);
    buf.clearRetainingCapacity();

    try sz.ident("foo_1");
    try std.testing.expectEqualStrings(".foo_1", buf.items);
    buf.clearRetainingCapacity();

    try sz.ident("_foo_1");
    try std.testing.expectEqualStrings("._foo_1", buf.items);
    buf.clearRetainingCapacity();

    try sz.ident("foo bar");
    try std.testing.expectEqualStrings(".@\"foo bar\"", buf.items);
    buf.clearRetainingCapacity();

    try sz.ident("1foo");
    try std.testing.expectEqualStrings(".@\"1foo\"", buf.items);
    buf.clearRetainingCapacity();

    try sz.ident("var");
    try std.testing.expectEqualStrings(".@\"var\"", buf.items);
    buf.clearRetainingCapacity();

    try sz.ident("true");
    try std.testing.expectEqualStrings(".true", buf.items);
    buf.clearRetainingCapacity();

    try sz.ident("_");
    try std.testing.expectEqualStrings("._", buf.items);
    buf.clearRetainingCapacity();

    const Enum = enum {
        @"foo bar",
    };
    try expectSerializeEqual(".{ .@\"var\" = .@\"foo bar\", .@\"1\" = .@\"foo bar\" }", .{
        .@"var" = .@"foo bar",
        .@"1" = Enum.@"foo bar",
    }, .{});
}

test "std.zon stringify as tuple" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    var sz = serializer(buf.writer(), .{});

    // Tuples
    try sz.tuple(.{ 1, 2 }, .{});
    try std.testing.expectEqualStrings(".{ 1, 2 }", buf.items);
    buf.clearRetainingCapacity();

    // Slice
    try sz.tuple(@as([]const u8, &.{ 1, 2 }), .{});
    try std.testing.expectEqualStrings(".{ 1, 2 }", buf.items);
    buf.clearRetainingCapacity();

    // Array
    try sz.tuple([2]u8{ 1, 2 }, .{});
    try std.testing.expectEqualStrings(".{ 1, 2 }", buf.items);
    buf.clearRetainingCapacity();
}

test "std.zon stringify as float" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    var sz = serializer(buf.writer(), .{});

    // Comptime float
    try sz.float(2.5);
    try std.testing.expectEqualStrings("2.5", buf.items);
    buf.clearRetainingCapacity();

    // Sized float
    try sz.float(@as(f32, 2.5));
    try std.testing.expectEqualStrings("2.5", buf.items);
    buf.clearRetainingCapacity();
}

test "std.zon stringify vector" {
    try expectSerializeEqual(
        \\.{
        \\    .{},
        \\    .{
        \\        true,
        \\        false,
        \\        true,
        \\    },
        \\    .{},
        \\    .{
        \\        1.5,
        \\        2.5,
        \\        3.5,
        \\    },
        \\    .{},
        \\    .{
        \\        2,
        \\        4,
        \\        6,
        \\    },
        \\    .{ 1, 2 },
        \\    .{
        \\        3,
        \\        4,
        \\        null,
        \\    },
        \\}
    ,
        .{
            @Vector(0, bool){},
            @Vector(3, bool){ true, false, true },
            @Vector(0, f32){},
            @Vector(3, f32){ 1.5, 2.5, 3.5 },
            @Vector(0, u8){},
            @Vector(3, u8){ 2, 4, 6 },
            @Vector(2, *const u8){ &1, &2 },
            @Vector(3, ?*const u8){ &3, &4, null },
        },
        .{},
    );
}

test "std.zon pointers" {
    // Primitive with varying levels of pointers
    try expectSerializeEqual("10", &@as(u32, 10), .{});
    try expectSerializeEqual("10", &&@as(u32, 10), .{});
    try expectSerializeEqual("10", &&&@as(u32, 10), .{});

    // Primitive optional with varying levels of pointers
    try expectSerializeEqual("10", @as(?*const u32, &10), .{});
    try expectSerializeEqual("null", @as(?*const u32, null), .{});
    try expectSerializeEqual("10", @as(?*const u32, &10), .{});
    try expectSerializeEqual("null", @as(*const ?u32, &null), .{});

    try expectSerializeEqual("10", @as(?*const *const u32, &&10), .{});
    try expectSerializeEqual("null", @as(?*const *const u32, null), .{});
    try expectSerializeEqual("10", @as(*const ?*const u32, &&10), .{});
    try expectSerializeEqual("null", @as(*const ?*const u32, &null), .{});
    try expectSerializeEqual("10", @as(*const *const ?u32, &&10), .{});
    try expectSerializeEqual("null", @as(*const *const ?u32, &&null), .{});

    try expectSerializeEqual(".{ 1, 2 }", &[2]u32{ 1, 2 }, .{});

    // A complicated type with nested internal pointers and string allocations
    {
        const Inner = struct {
            f1: *const ?*const []const u8,
            f2: *const ?*const []const u8,
        };
        const Outer = struct {
            f1: *const ?*const Inner,
            f2: *const ?*const Inner,
        };
        const val: ?*const Outer = &.{
            .f1 = &&.{
                .f1 = &null,
                .f2 = &&"foo",
            },
            .f2 = &null,
        };

        try expectSerializeEqual(
            \\.{ .f1 = .{ .f1 = null, .f2 = "foo" }, .f2 = null }
        , val, .{});
    }
}

test "std.zon tuple/struct field" {
    var buf = std.ArrayList(u8).init(std.testing.allocator);
    defer buf.deinit();
    var sz = serializer(buf.writer(), .{});

    // Test on structs
    {
        var root = try sz.beginStruct(.{});
        {
            var tuple = try root.beginTupleField("foo", .{});
            try tuple.field(0, .{});
            try tuple.field(1, .{});
            try tuple.end();
        }
        {
            var strct = try root.beginStructField("bar", .{});
            try strct.field("a", 0, .{});
            try strct.field("b", 1, .{});
            try strct.end();
        }
        try root.end();

        try std.testing.expectEqualStrings(
            \\.{
            \\    .foo = .{
            \\        0,
            \\        1,
            \\    },
            \\    .bar = .{
            \\        .a = 0,
            \\        .b = 1,
            \\    },
            \\}
        , buf.items);
        buf.clearRetainingCapacity();
    }

    // Test on tuples
    {
        var root = try sz.beginTuple(.{});
        {
            var tuple = try root.beginTupleField(.{});
            try tuple.field(0, .{});
            try tuple.field(1, .{});
            try tuple.end();
        }
        {
            var strct = try root.beginStructField(.{});
            try strct.field("a", 0, .{});
            try strct.field("b", 1, .{});
            try strct.end();
        }
        try root.end();

        try std.testing.expectEqualStrings(
            \\.{
            \\    .{
            \\        0,
            \\        1,
            \\    },
            \\    .{
            \\        .a = 0,
            \\        .b = 1,
            \\    },
            \\}
        , buf.items);
        buf.clearRetainingCapacity();
    }
}
