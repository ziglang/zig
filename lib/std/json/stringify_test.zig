const std = @import("std");
const mem = std.mem;
const testing = std.testing;

const StringifyOptions = @import("stringify.zig").StringifyOptions;
const stringify = @import("stringify.zig").stringify;
const stringifyAlloc = @import("stringify.zig").stringifyAlloc;

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
    try teststringify("{\"nothing\":{}}", T{ .nothing = {} }, StringifyOptions{});
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
        StringifyOptions{
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

test "stringify alloc" {
    const allocator = std.testing.allocator;
    const expected =
        \\{"foo":"bar","answer":42,"my_friend":"sammy"}
    ;
    const actual = try stringifyAlloc(allocator, .{ .foo = "bar", .answer = 42, .my_friend = "sammy" }, .{});
    defer allocator.free(actual);

    try std.testing.expectEqualStrings(expected, actual);
}
