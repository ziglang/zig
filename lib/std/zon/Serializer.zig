//! Lower level control over serialization, you can create a new instance with `serializer`.
//!
//! Useful when you want control over which fields are serialized, how they're represented,
//! or want to write a ZON object that does not exist in memory.
//!
//! You can serialize values with `value`. To serialize recursive types, the following are provided:
//! * `valueMaxDepth`
//! * `valueArbitraryDepth`
//!
//! You can also serialize values using specific notations:
//! * `int`
//! * `float`
//! * `codePoint`
//! * `tuple`
//! * `tupleMaxDepth`
//! * `tupleArbitraryDepth`
//! * `string`
//! * `multilineString`
//!
//! For manual serialization of containers, see:
//! * `beginStruct`
//! * `beginTuple`

options: Options = .{},
indent_level: u8 = 0,
writer: *Writer,

const Serializer = @This();
const std = @import("std");
const assert = std.debug.assert;
const Writer = std.Io.Writer;

pub const Error = Writer.Error;
pub const DepthError = Error || error{ExceededMaxDepth};

pub const Options = struct {
    /// If false, only syntactically necessary whitespace is emitted.
    whitespace: bool = true,
};

/// Options for manual serialization of container types.
pub const ContainerOptions = struct {
    /// The whitespace style that should be used for this container. Ignored if whitespace is off.
    whitespace_style: union(enum) {
        /// If true, wrap every field. If false do not.
        wrap: bool,
        /// Automatically decide whether to wrap or not based on the number of fields. Following
        /// the standard rule of thumb, containers with more than two fields are wrapped.
        fields: usize,
    } = .{ .wrap = true },

    fn shouldWrap(self: ContainerOptions) bool {
        return switch (self.whitespace_style) {
            .wrap => |wrap| wrap,
            .fields => |fields| fields > 2,
        };
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

/// Serialize a value, similar to `serialize`.
pub fn value(self: *Serializer, val: anytype, options: ValueOptions) Error!void {
    comptime assert(!typeIsRecursive(@TypeOf(val)));
    return self.valueArbitraryDepth(val, options);
}

/// Serialize a value, similar to `serializeMaxDepth`.
/// Can return `error.ExceededMaxDepth`.
pub fn valueMaxDepth(self: *Serializer, val: anytype, options: ValueOptions, depth: usize) DepthError!void {
    try checkValueDepth(val, depth);
    return self.valueArbitraryDepth(val, options);
}

/// Serialize a value, similar to `serializeArbitraryDepth`.
pub fn valueArbitraryDepth(self: *Serializer, val: anytype, options: ValueOptions) Error!void {
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
        .bool, .null => try self.writer.print("{}", .{val}),
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
            inline for (0..vector.len) |i| {
                try container.fieldArbitraryDepth(val[i], options);
            }
            try container.end();
        },

        else => comptime unreachable,
    }
}

/// Serialize an integer.
pub fn int(self: *Serializer, val: anytype) Error!void {
    try self.writer.printInt(val, 10, .lower, .{});
}

/// Serialize a float.
pub fn float(self: *Serializer, val: anytype) Error!void {
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
            try self.writer.print("{d}", .{val});
        },
        .comptime_float => if (val == 0) {
            return self.writer.writeAll("0");
        } else {
            try self.writer.print("{d}", .{val});
        },
        else => comptime unreachable,
    }
}

/// Serialize `name` as an identifier prefixed with `.`.
///
/// Escapes the identifier if necessary.
pub fn ident(self: *Serializer, name: []const u8) Error!void {
    try self.writer.print(".{f}", .{std.zig.fmtIdPU(name)});
}

pub const CodePointError = Error || error{InvalidCodepoint};

/// Serialize `val` as a Unicode codepoint.
///
/// Returns `error.InvalidCodepoint` if `val` is not a valid Unicode codepoint.
pub fn codePoint(self: *Serializer, val: u21) CodePointError!void {
    try self.writer.print("'{f}'", .{std.zig.fmtChar(val)});
}

/// Like `value`, but always serializes `val` as a tuple.
///
/// Will fail at comptime if `val` is not a tuple, array, pointer to an array, or slice.
pub fn tuple(self: *Serializer, val: anytype, options: ValueOptions) Error!void {
    comptime assert(!typeIsRecursive(@TypeOf(val)));
    try self.tupleArbitraryDepth(val, options);
}

/// Like `tuple`, but recursive types are allowed.
///
/// Returns `error.ExceededMaxDepth` if `depth` is exceeded.
pub fn tupleMaxDepth(
    self: *Serializer,
    val: anytype,
    options: ValueOptions,
    depth: usize,
) DepthError!void {
    try checkValueDepth(val, depth);
    try self.tupleArbitraryDepth(val, options);
}

/// Like `tuple`, but recursive types are allowed.
///
/// It is the caller's responsibility to ensure that `val` does not contain cycles.
pub fn tupleArbitraryDepth(
    self: *Serializer,
    val: anytype,
    options: ValueOptions,
) Error!void {
    try self.tupleImpl(val, options);
}

fn tupleImpl(self: *Serializer, val: anytype, options: ValueOptions) Error!void {
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
pub fn string(self: *Serializer, val: []const u8) Error!void {
    try self.writer.print("\"{f}\"", .{std.zig.fmtString(val)});
}

/// Options for formatting multiline strings.
pub const MultilineStringOptions = struct {
    /// If top level is true, whitespace before and after the multiline string is elided.
    /// If it is true, a newline is printed, then the value, followed by a newline, and if
    /// whitespace is true any necessary indentation follows.
    top_level: bool = false,
};

pub const MultilineStringError = Error || error{InnerCarriageReturn};

/// Like `value`, but always serializes to a multiline string literal.
///
/// Returns `error.InnerCarriageReturn` if `val` contains a CR not followed by a newline,
/// since multiline strings cannot represent CR without a following newline.
pub fn multilineString(
    self: *Serializer,
    val: []const u8,
    options: MultilineStringOptions,
) MultilineStringError!void {
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
pub fn beginStruct(self: *Serializer, options: ContainerOptions) Error!Struct {
    return Struct.begin(self, options);
}

/// Creates a `Tuple` for writing ZON tuples field by field.
pub fn beginTuple(self: *Serializer, options: ContainerOptions) Error!Tuple {
    return Tuple.begin(self, options);
}

fn indent(self: *Serializer) Error!void {
    if (self.options.whitespace) {
        try self.writer.splatByteAll(' ', 4 * self.indent_level);
    }
}

fn newline(self: *Serializer) Error!void {
    if (self.options.whitespace) {
        try self.writer.writeByte('\n');
    }
}

fn newlineOrSpace(self: *Serializer, len: usize) Error!void {
    if (self.containerShouldWrap(len)) {
        try self.newline();
    } else {
        try self.space();
    }
}

fn space(self: *Serializer) Error!void {
    if (self.options.whitespace) {
        try self.writer.writeByte(' ');
    }
}

/// Writes ZON tuples field by field.
pub const Tuple = struct {
    container: Container,

    fn begin(parent: *Serializer, options: ContainerOptions) Error!Tuple {
        return .{
            .container = try Container.begin(parent, .anon, options),
        };
    }

    /// Finishes serializing the tuple.
    ///
    /// Prints a trailing comma as configured when appropriate, and the closing bracket.
    pub fn end(self: *Tuple) Error!void {
        try self.container.end();
        self.* = undefined;
    }

    /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `value`.
    pub fn field(
        self: *Tuple,
        val: anytype,
        options: ValueOptions,
    ) Error!void {
        try self.container.field(null, val, options);
    }

    /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `valueMaxDepth`.
    /// Returns `error.ExceededMaxDepth` if `depth` is exceeded.
    pub fn fieldMaxDepth(
        self: *Tuple,
        val: anytype,
        options: ValueOptions,
        depth: usize,
    ) DepthError!void {
        try self.container.fieldMaxDepth(null, val, options, depth);
    }

    /// Serialize a field. Equivalent to calling `fieldPrefix` followed by
    /// `valueArbitraryDepth`.
    pub fn fieldArbitraryDepth(
        self: *Tuple,
        val: anytype,
        options: ValueOptions,
    ) Error!void {
        try self.container.fieldArbitraryDepth(null, val, options);
    }

    /// Starts a field with a struct as a value. Returns the struct.
    pub fn beginStructField(
        self: *Tuple,
        options: ContainerOptions,
    ) Error!Struct {
        try self.fieldPrefix();
        return self.container.serializer.beginStruct(options);
    }

    /// Starts a field with a tuple as a value. Returns the tuple.
    pub fn beginTupleField(
        self: *Tuple,
        options: ContainerOptions,
    ) Error!Tuple {
        try self.fieldPrefix();
        return self.container.serializer.beginTuple(options);
    }

    /// Print a field prefix. This prints any necessary commas, and whitespace as
    /// configured. Useful if you want to serialize the field value yourself.
    pub fn fieldPrefix(self: *Tuple) Error!void {
        try self.container.fieldPrefix(null);
    }
};

/// Writes ZON structs field by field.
pub const Struct = struct {
    container: Container,

    fn begin(parent: *Serializer, options: ContainerOptions) Error!Struct {
        return .{
            .container = try Container.begin(parent, .named, options),
        };
    }

    /// Finishes serializing the struct.
    ///
    /// Prints a trailing comma as configured when appropriate, and the closing bracket.
    pub fn end(self: *Struct) Error!void {
        try self.container.end();
        self.* = undefined;
    }

    /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `value`.
    pub fn field(
        self: *Struct,
        name: []const u8,
        val: anytype,
        options: ValueOptions,
    ) Error!void {
        try self.container.field(name, val, options);
    }

    /// Serialize a field. Equivalent to calling `fieldPrefix` followed by `valueMaxDepth`.
    /// Returns `error.ExceededMaxDepth` if `depth` is exceeded.
    pub fn fieldMaxDepth(
        self: *Struct,
        name: []const u8,
        val: anytype,
        options: ValueOptions,
        depth: usize,
    ) DepthError!void {
        try self.container.fieldMaxDepth(name, val, options, depth);
    }

    /// Serialize a field. Equivalent to calling `fieldPrefix` followed by
    /// `valueArbitraryDepth`.
    pub fn fieldArbitraryDepth(
        self: *Struct,
        name: []const u8,
        val: anytype,
        options: ValueOptions,
    ) Error!void {
        try self.container.fieldArbitraryDepth(name, val, options);
    }

    /// Starts a field with a struct as a value. Returns the struct.
    pub fn beginStructField(
        self: *Struct,
        name: []const u8,
        options: ContainerOptions,
    ) Error!Struct {
        try self.fieldPrefix(name);
        return self.container.serializer.beginStruct(options);
    }

    /// Starts a field with a tuple as a value. Returns the tuple.
    pub fn beginTupleField(
        self: *Struct,
        name: []const u8,
        options: ContainerOptions,
    ) Error!Tuple {
        try self.fieldPrefix(name);
        return self.container.serializer.beginTuple(options);
    }

    /// Print a field prefix. This prints any necessary commas, the field name (escaped if
    /// necessary) and whitespace as configured. Useful if you want to serialize the field
    /// value yourself.
    pub fn fieldPrefix(self: *Struct, name: []const u8) Error!void {
        try self.container.fieldPrefix(name);
    }
};

const Container = struct {
    const FieldStyle = enum { named, anon };

    serializer: *Serializer,
    field_style: FieldStyle,
    options: ContainerOptions,
    empty: bool,

    fn begin(
        sz: *Serializer,
        field_style: FieldStyle,
        options: ContainerOptions,
    ) Error!Container {
        if (options.shouldWrap()) sz.indent_level +|= 1;
        try sz.writer.writeAll(".{");
        return .{
            .serializer = sz,
            .field_style = field_style,
            .options = options,
            .empty = true,
        };
    }

    fn end(self: *Container) Error!void {
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

    fn fieldPrefix(self: *Container, name: ?[]const u8) Error!void {
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
    ) Error!void {
        comptime assert(!typeIsRecursive(@TypeOf(val)));
        try self.fieldArbitraryDepth(name, val, options);
    }

    /// Returns `error.ExceededMaxDepth` if `depth` is exceeded.
    fn fieldMaxDepth(
        self: *Container,
        name: ?[]const u8,
        val: anytype,
        options: ValueOptions,
        depth: usize,
    ) DepthError!void {
        try checkValueDepth(val, depth);
        try self.fieldArbitraryDepth(name, val, options);
    }

    fn fieldArbitraryDepth(
        self: *Container,
        name: ?[]const u8,
        val: anytype,
        options: ValueOptions,
    ) Error!void {
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

test Serializer {
    var discarding: Writer.Discarding = .init(&.{});
    var s: Serializer = .{ .writer = &discarding.writer };
    var vec2 = try s.beginStruct(.{});
    try vec2.field("x", 1.5, .{});
    try vec2.fieldPrefix("prefix");
    try s.value(2.5, .{});
    try vec2.end();
}

inline fn typeIsRecursive(comptime T: type) bool {
    return comptime typeIsRecursiveInner(T, &.{});
}

fn typeIsRecursiveInner(comptime T: type, comptime prev_visited: []const type) bool {
    for (prev_visited) |V| {
        if (V == T) return true;
    }
    const visited = prev_visited ++ .{T};

    return switch (@typeInfo(T)) {
        .pointer => |pointer| typeIsRecursiveInner(pointer.child, visited),
        .optional => |optional| typeIsRecursiveInner(optional.child, visited),
        .array => |array| typeIsRecursiveInner(array.child, visited),
        .vector => |vector| typeIsRecursiveInner(vector.child, visited),
        .@"struct" => |@"struct"| for (@"struct".fields) |field| {
            if (typeIsRecursiveInner(field.type, visited)) break true;
        } else false,
        .@"union" => |@"union"| inline for (@"union".fields) |field| {
            if (typeIsRecursiveInner(field.type, visited)) break true;
        } else false,
        else => false,
    };
}

test typeIsRecursive {
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

fn expectValueDepthEquals(expected: usize, v: anytype) !void {
    try checkValueDepth(v, expected);
    try std.testing.expectError(error.ExceededMaxDepth, checkValueDepth(v, expected - 1));
}

test checkValueDepth {
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

inline fn canSerializeType(T: type) bool {
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

test canSerializeType {
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
