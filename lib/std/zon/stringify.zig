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
const Writer = std.Io.Writer;
const Serializer = std.zon.Serializer;

pub const SerializeOptions = struct {
    /// If false, whitespace is omitted. Otherwise whitespace is emitted in standard Zig style.
    whitespace: bool = true,
    /// Determines when to emit Unicode code point literals as opposed to integer literals.
    emit_codepoint_literals: Serializer.EmitCodepointLiterals = .never,
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
pub fn serialize(val: anytype, options: SerializeOptions, writer: *Writer) Writer.Error!void {
    var s: Serializer = .{
        .writer = writer,
        .options = .{ .whitespace = options.whitespace },
    };
    try s.value(val, .{
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
    writer: *Writer,
    depth: usize,
) Serializer.DepthError!void {
    var s: Serializer = .{
        .writer = writer,
        .options = .{ .whitespace = options.whitespace },
    };
    try s.valueMaxDepth(val, .{
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
    writer: *Writer,
) Serializer.Error!void {
    var s: Serializer = .{
        .writer = writer,
        .options = .{ .whitespace = options.whitespace },
    };
    try s.valueArbitraryDepth(val, .{
        .emit_codepoint_literals = options.emit_codepoint_literals,
        .emit_strings_as_containers = options.emit_strings_as_containers,
        .emit_default_optional_fields = options.emit_default_optional_fields,
    });
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

fn expectSerializeEqual(
    expected: []const u8,
    value: anytype,
    options: SerializeOptions,
) !void {
    var aw: Writer.Allocating = .init(std.testing.allocator);
    const bw = &aw.writer;
    defer aw.deinit();

    try serialize(value, options, bw);
    try std.testing.expectEqualStrings(expected, aw.getWritten());
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
    var aw: Writer.Allocating = .init(std.testing.allocator);
    var s: Serializer = .{ .writer = &aw.writer };
    defer aw.deinit();

    for ([2]bool{ true, false }) |whitespace| {
        s.options = .{ .whitespace = whitespace };

        // Empty containers
        {
            var container = try s.beginStruct(.{});
            try container.end();
            try std.testing.expectEqualStrings(".{}", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginTuple(.{});
            try container.end();
            try std.testing.expectEqualStrings(".{}", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.end();
            try std.testing.expectEqualStrings(".{}", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.end();
            try std.testing.expectEqualStrings(".{}", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginStruct(.{ .whitespace_style = .{ .fields = 0 } });
            try container.end();
            try std.testing.expectEqualStrings(".{}", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginTuple(.{ .whitespace_style = .{ .fields = 0 } });
            try container.end();
            try std.testing.expectEqualStrings(".{}", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        // Size 1
        {
            var container = try s.beginStruct(.{});
            try container.field("a", 1, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\}
                , aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginTuple(.{});
            try container.field(1, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\}
                , aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{1}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1 }", aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            // We get extra spaces here, since we didn't know up front that there would only be one
            // field.
            var container = try s.beginTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1 }", aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{1}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginStruct(.{ .whitespace_style = .{ .fields = 1 } });
            try container.field("a", 1, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1 }", aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{.a=1}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginTuple(.{ .whitespace_style = .{ .fields = 1 } });
            try container.field(1, .{});
            try container.end();
            try std.testing.expectEqualStrings(".{1}", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        // Size 2
        {
            var container = try s.beginStruct(.{});
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    .a = 1,
                    \\    .b = 2,
                    \\}
                , aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginTuple(.{});
            try container.field(1, .{});
            try container.field(2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(
                    \\.{
                    \\    1,
                    \\    2,
                    \\}
                , aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{1,2}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2 }", aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2 }", aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{1,2}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginStruct(.{ .whitespace_style = .{ .fields = 2 } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2 }", aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginTuple(.{ .whitespace_style = .{ .fields = 2 } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2 }", aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{1,2}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        // Size 3
        {
            var container = try s.beginStruct(.{});
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
                , aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginTuple(.{});
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
                , aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginStruct(.{ .whitespace_style = .{ .wrap = false } });
            try container.field("a", 1, .{});
            try container.field("b", 2, .{});
            try container.field("c", 3, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ .a = 1, .b = 2, .c = 3 }", aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginTuple(.{ .whitespace_style = .{ .wrap = false } });
            try container.field(1, .{});
            try container.field(2, .{});
            try container.field(3, .{});
            try container.end();
            if (whitespace) {
                try std.testing.expectEqualStrings(".{ 1, 2, 3 }", aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginStruct(.{ .whitespace_style = .{ .fields = 3 } });
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
                , aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{.a=1,.b=2,.c=3}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            var container = try s.beginTuple(.{ .whitespace_style = .{ .fields = 3 } });
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
                , aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(".{1,2,3}", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        // Nested objects where the outer container doesn't wrap but the inner containers do
        {
            var container = try s.beginStruct(.{ .whitespace_style = .{ .wrap = false } });
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
                , aw.getWritten());
            } else {
                try std.testing.expectEqualStrings(
                    ".{.first=.{1,2,3},.second=.{4,5,6}}",
                    aw.getWritten(),
                );
            }
            aw.clearRetainingCapacity();
        }
    }
}

test "std.zon stringify utf8 codepoints" {
    var aw: Writer.Allocating = .init(std.testing.allocator);
    var s: Serializer = .{ .writer = &aw.writer };
    defer aw.deinit();

    // Printable ASCII
    try s.int('a');
    try std.testing.expectEqualStrings("97", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.codePoint('a');
    try std.testing.expectEqualStrings("'a'", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value('a', .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings("'a'", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value('a', .{ .emit_codepoint_literals = .printable_ascii });
    try std.testing.expectEqualStrings("'a'", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value('a', .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings("97", aw.getWritten());
    aw.clearRetainingCapacity();

    // Short escaped codepoint
    try s.int('\n');
    try std.testing.expectEqualStrings("10", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.codePoint('\n');
    try std.testing.expectEqualStrings("'\\n'", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value('\n', .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings("'\\n'", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value('\n', .{ .emit_codepoint_literals = .printable_ascii });
    try std.testing.expectEqualStrings("10", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value('\n', .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings("10", aw.getWritten());
    aw.clearRetainingCapacity();

    // Large codepoint
    try s.int('⚡');
    try std.testing.expectEqualStrings("9889", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.codePoint('⚡');
    try std.testing.expectEqualStrings("'\\u{26a1}'", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value('⚡', .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings("'\\u{26a1}'", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value('⚡', .{ .emit_codepoint_literals = .printable_ascii });
    try std.testing.expectEqualStrings("9889", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value('⚡', .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings("9889", aw.getWritten());
    aw.clearRetainingCapacity();

    // Invalid codepoint
    try s.codePoint(0x110000 + 1);
    try std.testing.expectEqualStrings("'\\u{110001}'", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.int(0x110000 + 1);
    try std.testing.expectEqualStrings("1114113", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value(0x110000 + 1, .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings("1114113", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value(0x110000 + 1, .{ .emit_codepoint_literals = .printable_ascii });
    try std.testing.expectEqualStrings("1114113", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value(0x110000 + 1, .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings("1114113", aw.getWritten());
    aw.clearRetainingCapacity();

    // Valid codepoint, not a codepoint type
    try s.value(@as(u22, 'a'), .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings("97", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value(@as(u22, 'a'), .{ .emit_codepoint_literals = .printable_ascii });
    try std.testing.expectEqualStrings("97", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value(@as(i32, 'a'), .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings("97", aw.getWritten());
    aw.clearRetainingCapacity();

    // Make sure value options are passed to children
    try s.value(.{ .c = '⚡' }, .{ .emit_codepoint_literals = .always });
    try std.testing.expectEqualStrings(".{ .c = '\\u{26a1}' }", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value(.{ .c = '⚡' }, .{ .emit_codepoint_literals = .never });
    try std.testing.expectEqualStrings(".{ .c = 9889 }", aw.getWritten());
    aw.clearRetainingCapacity();
}

test "std.zon stringify strings" {
    var aw: Writer.Allocating = .init(std.testing.allocator);
    var s: Serializer = .{ .writer = &aw.writer };
    defer aw.deinit();

    // Minimal case
    try s.string("abc⚡\n");
    try std.testing.expectEqualStrings("\"abc\\xe2\\x9a\\xa1\\n\"", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.tuple("abc⚡\n", .{});
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
    , aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value("abc⚡\n", .{});
    try std.testing.expectEqualStrings("\"abc\\xe2\\x9a\\xa1\\n\"", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value("abc⚡\n", .{ .emit_strings_as_containers = true });
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
    , aw.getWritten());
    aw.clearRetainingCapacity();

    // Value options are inherited by children
    try s.value(.{ .str = "abc" }, .{});
    try std.testing.expectEqualStrings(".{ .str = \"abc\" }", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.value(.{ .str = "abc" }, .{ .emit_strings_as_containers = true });
    try std.testing.expectEqualStrings(
        \\.{ .str = .{
        \\    97,
        \\    98,
        \\    99,
        \\} }
    , aw.getWritten());
    aw.clearRetainingCapacity();

    // Arrays (rather than pointers to arrays) of u8s are not considered strings, so that data can
    // round trip correctly.
    try s.value("abc".*, .{});
    try std.testing.expectEqualStrings(
        \\.{
        \\    97,
        \\    98,
        \\    99,
        \\}
    , aw.getWritten());
    aw.clearRetainingCapacity();
}

test "std.zon stringify multiline strings" {
    var aw: Writer.Allocating = .init(std.testing.allocator);
    var s: Serializer = .{ .writer = &aw.writer };
    defer aw.deinit();

    inline for (.{ true, false }) |whitespace| {
        s.options.whitespace = whitespace;

        {
            try s.multilineString("", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            try s.multilineString("abc⚡", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\abc⚡", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            try s.multilineString("abc⚡\ndef", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\abc⚡\n\\\\def", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            try s.multilineString("abc⚡\r\ndef", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\abc⚡\n\\\\def", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            try s.multilineString("\nabc⚡", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\\n\\\\abc⚡", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            try s.multilineString("\r\nabc⚡", .{ .top_level = true });
            try std.testing.expectEqualStrings("\\\\\n\\\\abc⚡", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            try s.multilineString("abc\ndef", .{});
            if (whitespace) {
                try std.testing.expectEqualStrings("\n\\\\abc\n\\\\def\n", aw.getWritten());
            } else {
                try std.testing.expectEqualStrings("\\\\abc\n\\\\def\n", aw.getWritten());
            }
            aw.clearRetainingCapacity();
        }

        {
            const str: []const u8 = &.{ 'a', '\r', 'c' };
            try s.string(str);
            try std.testing.expectEqualStrings("\"a\\rc\"", aw.getWritten());
            aw.clearRetainingCapacity();
        }

        {
            try std.testing.expectError(
                error.InnerCarriageReturn,
                s.multilineString(@as([]const u8, &.{ 'a', '\r', 'c' }), .{}),
            );
            try std.testing.expectError(
                error.InnerCarriageReturn,
                s.multilineString(@as([]const u8, &.{ 'a', '\r', 'c', '\n' }), .{}),
            );
            try std.testing.expectError(
                error.InnerCarriageReturn,
                s.multilineString(@as([]const u8, &.{ 'a', '\r', 'c', '\r', '\n' }), .{}),
            );
            try std.testing.expectEqualStrings("", aw.getWritten());
            aw.clearRetainingCapacity();
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
    var aw: Writer.Allocating = .init(std.testing.allocator);
    const bw = &aw.writer;
    defer aw.deinit();

    const Recurse = struct { r: []const @This() };

    // Normal operation
    try serializeMaxDepth(.{ 1, .{ 2, 3 } }, .{}, bw, 16);
    try std.testing.expectEqualStrings(".{ 1, .{ 2, 3 } }", aw.getWritten());
    aw.clearRetainingCapacity();

    try serializeArbitraryDepth(.{ 1, .{ 2, 3 } }, .{}, bw);
    try std.testing.expectEqualStrings(".{ 1, .{ 2, 3 } }", aw.getWritten());
    aw.clearRetainingCapacity();

    // Max depth failing on non recursive type
    try std.testing.expectError(
        error.ExceededMaxDepth,
        serializeMaxDepth(.{ 1, .{ 2, .{ 3, 4 } } }, .{}, bw, 3),
    );
    try std.testing.expectEqualStrings("", aw.getWritten());
    aw.clearRetainingCapacity();

    // Max depth passing on recursive type
    {
        const maybe_recurse = Recurse{ .r = &.{} };
        try serializeMaxDepth(maybe_recurse, .{}, bw, 2);
        try std.testing.expectEqualStrings(".{ .r = .{} }", aw.getWritten());
        aw.clearRetainingCapacity();
    }

    // Unchecked passing on recursive type
    {
        const maybe_recurse = Recurse{ .r = &.{} };
        try serializeArbitraryDepth(maybe_recurse, .{}, bw);
        try std.testing.expectEqualStrings(".{ .r = .{} }", aw.getWritten());
        aw.clearRetainingCapacity();
    }

    // Max depth failing on recursive type due to depth
    {
        var maybe_recurse = Recurse{ .r = &.{} };
        maybe_recurse.r = &.{.{ .r = &.{} }};
        try std.testing.expectError(
            error.ExceededMaxDepth,
            serializeMaxDepth(maybe_recurse, .{}, bw, 2),
        );
        try std.testing.expectEqualStrings("", aw.getWritten());
        aw.clearRetainingCapacity();
    }

    // Same but for a slice
    {
        var temp: [1]Recurse = .{.{ .r = &.{} }};
        const maybe_recurse: []const Recurse = &temp;

        try std.testing.expectError(
            error.ExceededMaxDepth,
            serializeMaxDepth(maybe_recurse, .{}, bw, 2),
        );
        try std.testing.expectEqualStrings("", aw.getWritten());
        aw.clearRetainingCapacity();

        var s: Serializer = .{ .writer = bw };

        try std.testing.expectError(
            error.ExceededMaxDepth,
            s.tupleMaxDepth(maybe_recurse, .{}, 2),
        );
        try std.testing.expectEqualStrings("", aw.getWritten());
        aw.clearRetainingCapacity();

        try s.tupleArbitraryDepth(maybe_recurse, .{});
        try std.testing.expectEqualStrings(".{.{ .r = .{} }}", aw.getWritten());
        aw.clearRetainingCapacity();
    }

    // A slice succeeding
    {
        var temp: [1]Recurse = .{.{ .r = &.{} }};
        const maybe_recurse: []const Recurse = &temp;

        try serializeMaxDepth(maybe_recurse, .{}, bw, 3);
        try std.testing.expectEqualStrings(".{.{ .r = .{} }}", aw.getWritten());
        aw.clearRetainingCapacity();

        var s: Serializer = .{ .writer = bw };

        try s.tupleMaxDepth(maybe_recurse, .{}, 3);
        try std.testing.expectEqualStrings(".{.{ .r = .{} }}", aw.getWritten());
        aw.clearRetainingCapacity();

        try s.tupleArbitraryDepth(maybe_recurse, .{});
        try std.testing.expectEqualStrings(".{.{ .r = .{} }}", aw.getWritten());
        aw.clearRetainingCapacity();
    }

    // Max depth failing on recursive type due to recursion
    {
        var temp: [1]Recurse = .{.{ .r = &.{} }};
        temp[0].r = &temp;
        const maybe_recurse: []const Recurse = &temp;

        try std.testing.expectError(
            error.ExceededMaxDepth,
            serializeMaxDepth(maybe_recurse, .{}, bw, 128),
        );
        try std.testing.expectEqualStrings("", aw.getWritten());
        aw.clearRetainingCapacity();

        var s: Serializer = .{ .writer = bw };
        try std.testing.expectError(
            error.ExceededMaxDepth,
            s.tupleMaxDepth(maybe_recurse, .{}, 128),
        );
        try std.testing.expectEqualStrings("", aw.getWritten());
        aw.clearRetainingCapacity();
    }

    // Max depth on other parts of the lower level API
    {
        var s: Serializer = .{ .writer = bw };

        const maybe_recurse: []const Recurse = &.{};

        try std.testing.expectError(error.ExceededMaxDepth, s.valueMaxDepth(1, .{}, 0));
        try s.valueMaxDepth(2, .{}, 1);
        try s.value(3, .{});
        try s.valueArbitraryDepth(maybe_recurse, .{});

        var wip_struct = try s.beginStruct(.{});
        try std.testing.expectError(error.ExceededMaxDepth, wip_struct.fieldMaxDepth("a", 1, .{}, 0));
        try wip_struct.fieldMaxDepth("b", 4, .{}, 1);
        try wip_struct.field("c", 5, .{});
        try wip_struct.fieldArbitraryDepth("d", maybe_recurse, .{});
        try wip_struct.end();

        var t = try s.beginTuple(.{});
        try std.testing.expectError(error.ExceededMaxDepth, t.fieldMaxDepth(1, .{}, 0));
        try t.fieldMaxDepth(6, .{}, 1);
        try t.field(7, .{});
        try t.fieldArbitraryDepth(maybe_recurse, .{});
        try t.end();

        var a = try s.beginTuple(.{});
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
        , aw.getWritten());
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
    var aw: Writer.Allocating = .init(std.testing.allocator);
    var s: Serializer = .{ .writer = &aw.writer };
    defer aw.deinit();

    try expectSerializeEqual(".{ .a = 0 }", .{ .a = 0 }, .{});
    try s.ident("a");
    try std.testing.expectEqualStrings(".a", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.ident("foo_1");
    try std.testing.expectEqualStrings(".foo_1", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.ident("_foo_1");
    try std.testing.expectEqualStrings("._foo_1", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.ident("foo bar");
    try std.testing.expectEqualStrings(".@\"foo bar\"", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.ident("1foo");
    try std.testing.expectEqualStrings(".@\"1foo\"", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.ident("var");
    try std.testing.expectEqualStrings(".@\"var\"", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.ident("true");
    try std.testing.expectEqualStrings(".true", aw.getWritten());
    aw.clearRetainingCapacity();

    try s.ident("_");
    try std.testing.expectEqualStrings("._", aw.getWritten());
    aw.clearRetainingCapacity();

    const Enum = enum {
        @"foo bar",
    };
    try expectSerializeEqual(".{ .@\"var\" = .@\"foo bar\", .@\"1\" = .@\"foo bar\" }", .{
        .@"var" = .@"foo bar",
        .@"1" = Enum.@"foo bar",
    }, .{});
}

test "std.zon stringify as tuple" {
    var aw: Writer.Allocating = .init(std.testing.allocator);
    var s: Serializer = .{ .writer = &aw.writer };
    defer aw.deinit();

    // Tuples
    try s.tuple(.{ 1, 2 }, .{});
    try std.testing.expectEqualStrings(".{ 1, 2 }", aw.getWritten());
    aw.clearRetainingCapacity();

    // Slice
    try s.tuple(@as([]const u8, &.{ 1, 2 }), .{});
    try std.testing.expectEqualStrings(".{ 1, 2 }", aw.getWritten());
    aw.clearRetainingCapacity();

    // Array
    try s.tuple([2]u8{ 1, 2 }, .{});
    try std.testing.expectEqualStrings(".{ 1, 2 }", aw.getWritten());
    aw.clearRetainingCapacity();
}

test "std.zon stringify as float" {
    var aw: Writer.Allocating = .init(std.testing.allocator);
    var s: Serializer = .{ .writer = &aw.writer };
    defer aw.deinit();

    // Comptime float
    try s.float(2.5);
    try std.testing.expectEqualStrings("2.5", aw.getWritten());
    aw.clearRetainingCapacity();

    // Sized float
    try s.float(@as(f32, 2.5));
    try std.testing.expectEqualStrings("2.5", aw.getWritten());
    aw.clearRetainingCapacity();
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
    var aw: Writer.Allocating = .init(std.testing.allocator);
    var s: Serializer = .{ .writer = &aw.writer };
    defer aw.deinit();

    // Test on structs
    {
        var root = try s.beginStruct(.{});
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
        , aw.getWritten());
        aw.clearRetainingCapacity();
    }

    // Test on tuples
    {
        var root = try s.beginTuple(.{});
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
        , aw.getWritten());
        aw.clearRetainingCapacity();
    }
}
