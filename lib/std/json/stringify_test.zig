const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const ObjectMap = @import("dynamic.zig").ObjectMap;
const Value = @import("dynamic.zig").Value;

const StringifyOptions = @import("stringify.zig").StringifyOptions;
const stringify = @import("stringify.zig").stringify;
const stringifyAlloc = @import("stringify.zig").stringifyAlloc;
const stringifyUnsafe = @import("stringify.zig").stringifyUnsafe;
const writeStream = @import("stringify.zig").writeStream;
const writeStreamUnsafe = @import("stringify.zig").writeStreamUnsafe;

test "json write stream" {
    var out_buf: [1024]u8 = undefined;
    var slice_stream = std.io.fixedBufferStream(&out_buf);
    const out = slice_stream.writer();

    {
        var w = writeStream(testing.allocator, out);
        defer w.deinit();
        try testBasicWriteStream(&w, &slice_stream);
    }

    {
        var w = writeStreamUnsafe(out);
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

    try w.objectField("string");
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
        \\ "object": {
        \\  "one": 1,
        \\  "two": 2.0e+00
        \\ },
        \\ "string": "This is a string",
        \\ "array": [
        \\  "Another string",
        \\  1,
        \\  3.5e+00
        \\ ],
        \\ "int": 10,
        \\ "float": 3.5e+00
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

test "json write stream primatives" {
    var out_buf: [1024]u8 = undefined;
    var slice_stream = std.io.fixedBufferStream(&out_buf);
    const out = slice_stream.writer();

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    var w = writeStream(testing.allocator, out);
    defer w.deinit();
    try w.write(null);
    // TODO
}

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
    try teststringify("false", false, .{});
    try teststringify("true", true, .{});
    try teststringify("null", @as(?u8, null), .{});
    try teststringify("null", @as(?*u32, null), .{});
    try teststringify("42", 42, .{});
    try teststringify("4.2e+01", 42.0, .{});
    try teststringify("42", @as(u8, 42), .{});
    try teststringify("42", @as(u128, 42), .{});
    try teststringify("4.2e+01", @as(f32, 42), .{});
    try teststringify("4.2e+01", @as(f64, 42), .{});
    try teststringify("\"ItBroke\"", @as(anyerror, error.ItBroke), .{});
}

test "stringify string" {
    try teststringify("\"hello\"", "hello", .{});
    try teststringify("\"with\\nescapes\\r\"", "with\nescapes\r", .{});
    try teststringify("\"with\\nescapes\\r\"", "with\nescapes\r", .{ .escape_unicode = true });
    try teststringify("\"with unicode\\u0001\"", "with unicode\u{1}", .{});
    try teststringify("\"with unicode\\u0001\"", "with unicode\u{1}", .{ .escape_unicode = true });
    try teststringify("\"with unicode\u{80}\"", "with unicode\u{80}", .{});
    try teststringify("\"with unicode\\u0080\"", "with unicode\u{80}", .{ .escape_unicode = true });
    try teststringify("\"with unicode\u{FF}\"", "with unicode\u{FF}", .{});
    try teststringify("\"with unicode\\u00ff\"", "with unicode\u{FF}", .{ .escape_unicode = true });
    try teststringify("\"with unicode\u{100}\"", "with unicode\u{100}", .{});
    try teststringify("\"with unicode\\u0100\"", "with unicode\u{100}", .{ .escape_unicode = true });
    try teststringify("\"with unicode\u{800}\"", "with unicode\u{800}", .{});
    try teststringify("\"with unicode\\u0800\"", "with unicode\u{800}", .{ .escape_unicode = true });
    try teststringify("\"with unicode\u{8000}\"", "with unicode\u{8000}", .{});
    try teststringify("\"with unicode\\u8000\"", "with unicode\u{8000}", .{ .escape_unicode = true });
    try teststringify("\"with unicode\u{D799}\"", "with unicode\u{D799}", .{});
    try teststringify("\"with unicode\\ud799\"", "with unicode\u{D799}", .{ .escape_unicode = true });
    try teststringify("\"with unicode\u{10000}\"", "with unicode\u{10000}", .{});
    try teststringify("\"with unicode\\ud800\\udc00\"", "with unicode\u{10000}", .{ .escape_unicode = true });
    try teststringify("\"with unicode\u{10FFFF}\"", "with unicode\u{10FFFF}", .{});
    try teststringify("\"with unicode\\udbff\\udfff\"", "with unicode\u{10FFFF}", .{ .escape_unicode = true });
    try teststringify("\"/\"", "/", .{});
    try teststringify("\"\\/\"", "/", .{ .escape_solidus = true });
}

test "stringify many-item sentinel-terminated string" {
    try teststringify("\"hello\"", @as([*:0]const u8, "hello"), .{});
    try teststringify("\"with\\nescapes\\r\"", @as([*:0]const u8, "with\nescapes\r"), .{ .escape_unicode = true });
    try teststringify("\"with unicode\\u0001\"", @as([*:0]const u8, "with unicode\u{1}"), .{ .escape_unicode = true });
}

test "stringify enums" {
    const E = enum {
        foo,
        bar,
    };
    try teststringify("\"foo\"", E.foo, .{});
    try teststringify("\"bar\"", E.bar, .{});
}

test "stringify tagged unions" {
    const T = union(enum) {
        nothing,
        foo: u32,
        bar: bool,
    };
    try teststringify("{\"nothing\":{}}", T{ .nothing = {} }, .{});
    try teststringify("{\"foo\":42}", T{ .foo = 42 }, .{});
    try teststringify("{\"bar\":true}", T{ .bar = true }, .{});
}

test "stringify struct" {
    try teststringify("{\"foo\":42}", struct {
        foo: u32,
    }{ .foo = 42 }, .{});
}

test "stringify struct with string as array" {
    try teststringify("{\"foo\":\"bar\"}", .{ .foo = "bar" }, .{});
    try teststringify("{\"foo\":[98,97,114]}", .{ .foo = "bar" }, .{ .emit_strings_as_arrays = true });
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
        .{
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
        .{
            .whitespace = .{
                .indent = .tab,
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
        .{
            .whitespace = .{
                .indent = .none,
                .separator = false,
            },
        },
    );
}

test "stringify struct with void field" {
    try teststringify("{\"foo\":42}", struct {
        foo: u32,
        bar: void = {},
    }{ .foo = 42 }, .{});
}

test "stringify array of structs" {
    const MyStruct = struct {
        foo: u32,
    };
    try teststringify("[{\"foo\":42},{\"foo\":100},{\"foo\":1000}]", [_]MyStruct{
        MyStruct{ .foo = 42 },
        MyStruct{ .foo = 100 },
        MyStruct{ .foo = 1000 },
    }, .{});
}

test "stringify struct with custom stringifier" {
    try teststringify("[\"something special\",42]", struct {
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
    try teststringify("[1,1]", @as(@Vector(2, u32), @splat(1)), .{});
}

test "stringify tuple" {
    try teststringify("[\"foo\",42]", std.meta.Tuple(&.{ []const u8, usize }){ "foo", 42 }, .{});
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
    try stringify(testing.allocator, value, options, vos.writer());
    if (vos.expected_remaining.len > 0) return error.NotEnoughData;

    // Also test with safety disabled.
    try testStringifyUnsafe(expected, value, options);
}

fn testStringifyUnsafe(expected: []const u8, value: anytype, options: StringifyOptions) !void {
    var out_buf: [1024]u8 = undefined;
    var slice_stream = std.io.fixedBufferStream(&out_buf);
    const out = slice_stream.writer();

    try stringifyUnsafe(value, options, out);
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
    comptime testStringifyUnsafe("false", false, .{}) catch unreachable;

    const MyStruct = struct {
        foo: u32,
    };
    comptime testStringifyUnsafe("[{\"foo\":42},{\"foo\":100},{\"foo\":1000}]", [_]MyStruct{
        MyStruct{ .foo = 42 },
        MyStruct{ .foo = 100 },
        MyStruct{ .foo = 1000 },
    }, .{}) catch unreachable;
}
