const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const ObjectMap = @import("dynamic.zig").ObjectMap;
const Value = @import("dynamic.zig").Value;

const StringifyOptions = @import("stringify.zig").StringifyOptions;
const stringify = @import("stringify.zig").stringify;
const stringifyMaxDepth = @import("stringify.zig").stringifyMaxDepth;
const stringifyArbitraryDepth = @import("stringify.zig").stringifyArbitraryDepth;
const stringifyAlloc = @import("stringify.zig").stringifyAlloc;
const writeStream = @import("stringify.zig").writeStream;
const writeStreamMaxDepth = @import("stringify.zig").writeStreamMaxDepth;
const writeStreamArbitraryDepth = @import("stringify.zig").writeStreamArbitraryDepth;

test "json write stream" {
    var out_buf: [1024]u8 = undefined;
    var slice_stream = std.io.fixedBufferStream(&out_buf);
    const out = slice_stream.writer();

    {
        var w = writeStream(out, .{ .whitespace = .indent_2 });
        try testBasicWriteStream(&w, &slice_stream);
    }

    {
        var w = writeStreamMaxDepth(out, .{ .whitespace = .indent_2 }, 8);
        try testBasicWriteStream(&w, &slice_stream);
    }

    {
        var w = writeStreamMaxDepth(out, .{ .whitespace = .indent_2 }, null);
        try testBasicWriteStream(&w, &slice_stream);
    }

    {
        var w = writeStreamArbitraryDepth(testing.allocator, out, .{ .whitespace = .indent_2 });
        defer w.deinit();
        try testBasicWriteStream(&w, &slice_stream);
    }
}

fn testBasicWriteStream(w: anytype, slice_stream: anytype) !void {
    slice_stream.reset();

    try w.beginObject();

    try w.objectField("object");
    var arena_allocator = std.heap.ArenaAllocator.init(testing.allocator);
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

    const result = slice_stream.getWritten();
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
    try std.testing.expectEqualStrings(expected, result);
}

fn getJsonObject(allocator: std.mem.Allocator) !Value {
    var value = Value{ .object = ObjectMap.init(allocator) };
    try value.object.put("one", Value{ .integer = @as(i64, @intCast(1)) });
    try value.object.put("two", Value{ .float = 2.0 });
    return value;
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

test "stringify struct with void field" {
    try testStringify("{\"foo\":42}", struct {
        foo: u32,
        bar: void = {},
    }{ .foo = 42 }, .{});
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
        pub fn jsonStringify(value: @This(), jws: anytype) !void {
            _ = value;
            try jws.beginArray();
            try jws.write("something special");
            try jws.write(42);
            try jws.endArray();
        }
    }{ .foo = 42 }, .{});
}

test "stringify vector" {
    try testStringify("[1,1]", @as(@Vector(2, u32), @splat(1)), .{});
    try testStringify("\"AA\"", @as(@Vector(2, u8), @splat('A')), .{});
    try testStringify("[65,65]", @as(@Vector(2, u8), @splat('A')), .{ .emit_strings_as_arrays = true });
}

test "stringify tuple" {
    try testStringify("[\"foo\",42]", std.meta.Tuple(&.{ []const u8, usize }){ "foo", 42 }, .{});
}

fn testStringify(expected: []const u8, value: anytype, options: StringifyOptions) !void {
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
    try stringifyArbitraryDepth(testing.allocator, value, options, vos.writer());
    if (vos.expected_remaining.len > 0) return error.NotEnoughData;

    // Also test with safety disabled.
    try testStringifyMaxDepth(expected, value, options, null);
    try testStringifyArbitraryDepth(expected, value, options);
}

fn testStringifyMaxDepth(expected: []const u8, value: anytype, options: StringifyOptions, comptime max_depth: ?usize) !void {
    var out_buf: [1024]u8 = undefined;
    var slice_stream = std.io.fixedBufferStream(&out_buf);
    const out = slice_stream.writer();

    try stringifyMaxDepth(value, options, out, max_depth);
    const got = slice_stream.getWritten();

    try testing.expectEqualStrings(expected, got);
}

fn testStringifyArbitraryDepth(expected: []const u8, value: anytype, options: StringifyOptions) !void {
    var out_buf: [1024]u8 = undefined;
    var slice_stream = std.io.fixedBufferStream(&out_buf);
    const out = slice_stream.writer();

    try stringifyArbitraryDepth(testing.allocator, value, options, out);
    const got = slice_stream.getWritten();

    try testing.expectEqualStrings(expected, got);
}

test "stringify alloc" {
    const allocator = std.testing.allocator;
    const expected =
        \\{"foo":"bar","answer":42,"my_friend":"sammy"}
    ;
    const actual = try stringifyAlloc(allocator, .{ .foo = "bar", .answer = 42, .my_friend = "sammy" }, .{});
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}

test "comptime stringify" {
    comptime testStringifyMaxDepth("false", false, .{}, null) catch unreachable;
    comptime testStringifyMaxDepth("false", false, .{}, 0) catch unreachable;
    comptime testStringifyArbitraryDepth("false", false, .{}) catch unreachable;

    const MyStruct = struct {
        foo: u32,
    };
    comptime testStringifyMaxDepth("[{\"foo\":42},{\"foo\":100},{\"foo\":1000}]", [_]MyStruct{
        MyStruct{ .foo = 42 },
        MyStruct{ .foo = 100 },
        MyStruct{ .foo = 1000 },
    }, .{}, null) catch unreachable;
    comptime testStringifyMaxDepth("[{\"foo\":42},{\"foo\":100},{\"foo\":1000}]", [_]MyStruct{
        MyStruct{ .foo = 42 },
        MyStruct{ .foo = 100 },
        MyStruct{ .foo = 1000 },
    }, .{}, 8) catch unreachable;
}

test "print" {
    var out_buf: [1024]u8 = undefined;
    var slice_stream = std.io.fixedBufferStream(&out_buf);
    const out = slice_stream.writer();

    var w = writeStream(out, .{ .whitespace = .indent_2 });
    defer w.deinit();

    try w.beginObject();
    try w.objectField("a");
    try w.print("[  ]", .{});
    try w.objectField("b");
    try w.beginArray();
    try w.print("[{s}] ", .{"[]"});
    try w.print("  {}", .{12345});
    try w.endArray();
    try w.endObject();

    const result = slice_stream.getWritten();
    const expected =
        \\{
        \\  "a": [  ],
        \\  "b": [
        \\    [[]] ,
        \\      12345
        \\  ]
        \\}
    ;
    try std.testing.expectEqualStrings(expected, result);
}

test "nonportable numbers" {
    try testStringify("9999999999999999", 9999999999999999, .{});
    try testStringify("\"9999999999999999\"", 9999999999999999, .{ .emit_nonportable_numbers_as_strings = true });
}
