const std = @import("std");
const testing = std.testing;

const parseFromSlice = @import("./static.zig").parseFromSlice;
const parseFromTokenSource = @import("./static.zig").parseFromTokenSource;
const parseFree = @import("./static.zig").parseFree;
const ParseOptions = @import("./static.zig").ParseOptions;
const JsonScanner = @import("./scanner.zig").Scanner;
const jsonReader = @import("./scanner.zig").reader;

test "parse" {
    try testing.expectEqual(false, try parseFromSlice(bool, testing.allocator, "false", .{}));
    try testing.expectEqual(true, try parseFromSlice(bool, testing.allocator, "true", .{}));
    try testing.expectEqual(@as(u1, 1), try parseFromSlice(u1, testing.allocator, "1", .{}));
    try testing.expectError(error.Overflow, parseFromSlice(u1, testing.allocator, "50", .{}));
    try testing.expectEqual(@as(u64, 42), try parseFromSlice(u64, testing.allocator, "42", .{}));
    try testing.expectEqual(@as(f64, 42), try parseFromSlice(f64, testing.allocator, "42.0", .{}));
    try testing.expectEqual(@as(?bool, null), try parseFromSlice(?bool, testing.allocator, "null", .{}));
    try testing.expectEqual(@as(?bool, true), try parseFromSlice(?bool, testing.allocator, "true", .{}));

    try testing.expectEqual(@as([3]u8, "foo".*), try parseFromSlice([3]u8, testing.allocator, "\"foo\"", .{}));
    try testing.expectEqual(@as([3]u8, "foo".*), try parseFromSlice([3]u8, testing.allocator, "[102, 111, 111]", .{}));
    try testing.expectEqual(@as([0]u8, undefined), try parseFromSlice([0]u8, testing.allocator, "[]", .{}));

    try testing.expectEqual(@as(u64, 12345678901234567890), try parseFromSlice(u64, testing.allocator, "\"12345678901234567890\"", .{}));
    try testing.expectEqual(@as(f64, 123.456), try parseFromSlice(f64, testing.allocator, "\"123.456\"", .{}));
}

test "parse into enum" {
    const T = enum(u32) {
        Foo = 42,
        Bar,
        @"with\\escape",
    };
    try testing.expectEqual(@as(T, .Foo), try parseFromSlice(T, testing.allocator, "\"Foo\"", .{}));
    try testing.expectEqual(@as(T, .Foo), try parseFromSlice(T, testing.allocator, "42", .{}));
    try testing.expectEqual(@as(T, .@"with\\escape"), try parseFromSlice(T, testing.allocator, "\"with\\\\escape\"", .{}));
    try testing.expectError(error.InvalidEnumTag, parseFromSlice(T, testing.allocator, "5", .{}));
    try testing.expectError(error.InvalidEnumTag, parseFromSlice(T, testing.allocator, "\"Qux\"", .{}));
}

test "parse into that allocates a slice" {
    {
        // string as string
        const r = try parseFromSlice([]u8, testing.allocator, "\"foo\"", .{});
        defer parseFree([]u8, testing.allocator, r);
        try testing.expectEqualSlices(u8, "foo", r);
    }
    {
        // string as array of u8 integers
        const r = try parseFromSlice([]u8, testing.allocator, "[102, 111, 111]", .{});
        defer parseFree([]u8, testing.allocator, r);
        try testing.expectEqualSlices(u8, "foo", r);
    }
    {
        const r = try parseFromSlice([]u8, testing.allocator, "\"with\\\\escape\"", .{});
        defer parseFree([]u8, testing.allocator, r);
        try testing.expectEqualSlices(u8, "with\\escape", r);
    }
}

test "parse into sentinel slice" {
    const result = try parseFromSlice([:0]const u8, testing.allocator, "\"\\n\"", .{});
    defer parseFree([:0]const u8, testing.allocator, result);
    try testing.expect(std.mem.eql(u8, result, "\n"));
}

test "parse into tagged union" {
    const T = union(enum) {
        nothing,
        int: i32,
        float: f64,
        string: []const u8,
    };
    try testing.expectEqual(T{ .float = 1.5 }, try parseFromSlice(T, testing.allocator, "{\"float\":1.5}", .{}));
    try testing.expectEqual(T{ .int = 1 }, try parseFromSlice(T, testing.allocator, "{\"int\":1}", .{}));
    try testing.expectEqual(T{ .nothing = {} }, try parseFromSlice(T, testing.allocator, "{\"nothing\":{}}", .{}));
}

test "parse into tagged union errors" {
    const T = union(enum) {
        nothing,
        int: i32,
        float: f64,
        string: []const u8,
    };
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "42", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "{}", .{}));
    try testing.expectError(error.UnknownField, parseFromSlice(T, testing.allocator, "{\"bogus\":1}", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "{\"int\":1, \"int\":1", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "{\"int\":1, \"float\":1.0}", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "{\"nothing\":null}", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSlice(T, testing.allocator, "{\"nothing\":{\"no\":0}}", .{}));

    // Allocator failure
    var fail_alloc = testing.FailingAllocator.init(testing.allocator, 0);
    const failing_allocator = fail_alloc.allocator();
    try testing.expectError(error.OutOfMemory, parseFromSlice(T, failing_allocator, "{\"string\"\"foo\"}", .{}));
}

test "parseFree descends into tagged union" {
    const T = union(enum) {
        nothing,
        int: i32,
        float: f64,
        string: []const u8,
    };
    const r = try parseFromSlice(T, testing.allocator, "{\"string\":\"foo\"}", .{});
    try testing.expectEqualSlices(u8, "foo", r.string);
    parseFree(T, testing.allocator, r);
}

test "parse into struct with no fields" {
    const T = struct {};
    try testing.expectEqual(T{}, try parseFromSlice(T, testing.allocator, "{}", .{}));
}

const test_const_value: usize = 123;

test "parse into struct with default const pointer field" {
    const T = struct { a: *const usize = &test_const_value };
    try testing.expectEqual(T{}, try parseFromSlice(T, testing.allocator, "{}", .{}));
}

const test_default_usize: usize = 123;
const test_default_usize_ptr: *align(1) const usize = &test_default_usize;
const test_default_str: []const u8 = "test str";
const test_default_str_slice: [2][]const u8 = [_][]const u8{
    "test1",
    "test2",
};

test "freeing parsed structs with pointers to default values" {
    const T = struct {
        int: *const usize = &test_default_usize,
        int_ptr: *allowzero align(1) const usize = test_default_usize_ptr,
        str: []const u8 = test_default_str,
        str_slice: []const []const u8 = &test_default_str_slice,
    };

    const parsed = try parseFromSlice(T, testing.allocator, "{}", .{});
    try testing.expectEqual(T{}, parsed);
    // This will panic if it tries to free global constants:
    parseFree(T, testing.allocator, parsed);
}

test "parse into struct where destination and source lengths mismatch" {
    const T = struct { a: [2]u8 };
    try testing.expectError(error.LengthMismatch, parseFromSlice(T, testing.allocator, "{\"a\": \"bbb\"}", .{}));
}

test "parse into struct with misc fields" {
    const T = struct {
        int: i64,
        float: f64,
        @"with\\escape": bool,
        @"withąunicode😂": bool,
        language: []const u8,
        optional: ?bool,
        default_field: i32 = 42,
        static_array: [3]f64,
        dynamic_array: []f64,

        complex: struct {
            nested: []const u8,
        },

        veryComplex: []struct {
            foo: []const u8,
        },

        a_union: Union,
        const Union = union(enum) {
            x: u8,
            float: f64,
            string: []const u8,
        };
    };
    var document_str =
        \\{
        \\  "int": 420,
        \\  "float": 3.14,
        \\  "with\\escape": true,
        \\  "with\u0105unicode\ud83d\ude02": false,
        \\  "language": "zig",
        \\  "optional": null,
        \\  "static_array": [66.6, 420.420, 69.69],
        \\  "dynamic_array": [66.6, 420.420, 69.69],
        \\  "complex": {
        \\    "nested": "zig"
        \\  },
        \\  "veryComplex": [
        \\    {
        \\      "foo": "zig"
        \\    }, {
        \\      "foo": "rocks"
        \\    }
        \\  ],
        \\  "a_union": {
        \\    "float": 100000
        \\  }
        \\}
    ;
    const r = try parseFromSlice(T, testing.allocator, document_str, .{});
    defer parseFree(T, testing.allocator, r);
    try testing.expectEqual(@as(i64, 420), r.int);
    try testing.expectEqual(@as(f64, 3.14), r.float);
    try testing.expectEqual(true, r.@"with\\escape");
    try testing.expectEqual(false, r.@"withąunicode😂");
    try testing.expectEqualSlices(u8, "zig", r.language);
    try testing.expectEqual(@as(?bool, null), r.optional);
    try testing.expectEqual(@as(i32, 42), r.default_field);
    try testing.expectEqual(@as(f64, 66.6), r.static_array[0]);
    try testing.expectEqual(@as(f64, 420.420), r.static_array[1]);
    try testing.expectEqual(@as(f64, 69.69), r.static_array[2]);
    try testing.expectEqual(@as(usize, 3), r.dynamic_array.len);
    try testing.expectEqual(@as(f64, 66.6), r.dynamic_array[0]);
    try testing.expectEqual(@as(f64, 420.420), r.dynamic_array[1]);
    try testing.expectEqual(@as(f64, 69.69), r.dynamic_array[2]);
    try testing.expectEqualSlices(u8, r.complex.nested, "zig");
    try testing.expectEqualSlices(u8, "zig", r.veryComplex[0].foo);
    try testing.expectEqualSlices(u8, "rocks", r.veryComplex[1].foo);
    try testing.expectEqual(T.Union{ .float = 100000 }, r.a_union);
}

test "parse into struct with strings and arrays with sentinels" {
    const T = struct {
        language: [:0]const u8,
        language_without_sentinel: []const u8,
        data: [:99]const i32,
        simple_data: []const i32,
    };
    var document_str =
        \\{
        \\  "language": "zig",
        \\  "language_without_sentinel": "zig again!",
        \\  "data": [1, 2, 3],
        \\  "simple_data": [4, 5, 6]
        \\}
    ;
    const r = try parseFromSlice(T, testing.allocator, document_str, .{});
    defer parseFree(T, testing.allocator, r);

    try testing.expectEqualSentinel(u8, 0, "zig", r.language);

    const data = [_:99]i32{ 1, 2, 3 };
    try testing.expectEqualSentinel(i32, 99, data[0..data.len], r.data);

    // Make sure that arrays who aren't supposed to have a sentinel still parse without one.
    try testing.expectEqual(@as(?i32, null), std.meta.sentinel(@TypeOf(r.simple_data)));
    try testing.expectEqual(@as(?u8, null), std.meta.sentinel(@TypeOf(r.language_without_sentinel)));
}

test "parse into struct with duplicate field" {
    // allow allocator to detect double frees by keeping bucket in use
    const ballast = try testing.allocator.alloc(u64, 1);
    defer testing.allocator.free(ballast);

    const options_first = ParseOptions{ .duplicate_field_behavior = .use_first };
    const options_last = ParseOptions{ .duplicate_field_behavior = .use_last };

    const str = "{ \"a\": 1, \"a\": 0.25 }";

    const T1 = struct { a: *u64 };
    // both .use_first and .use_last should fail because second "a" value isn't a u64
    try testing.expectError(error.InvalidNumber, parseFromSlice(T1, testing.allocator, str, options_first));
    try testing.expectError(error.InvalidNumber, parseFromSlice(T1, testing.allocator, str, options_last));

    const T2 = struct { a: f64 };
    try testing.expectEqual(T2{ .a = 1.0 }, try parseFromSlice(T2, testing.allocator, str, options_first));
    try testing.expectEqual(T2{ .a = 0.25 }, try parseFromSlice(T2, testing.allocator, str, options_last));
}

test "parse into struct ignoring unknown fields" {
    const T = struct {
        int: i64,
        language: []const u8,
    };

    var str =
        \\{
        \\  "int": 420,
        \\  "float": 3.14,
        \\  "with\\escape": true,
        \\  "with\u0105unicode\ud83d\ude02": false,
        \\  "optional": null,
        \\  "static_array": [66.6, 420.420, 69.69],
        \\  "dynamic_array": [66.6, 420.420, 69.69],
        \\  "complex": {
        \\    "nested": "zig"
        \\  },
        \\  "veryComplex": [
        \\    {
        \\      "foo": "zig"
        \\    }, {
        \\      "foo": "rocks"
        \\    }
        \\  ],
        \\  "a_union": {
        \\    "float": 100000
        \\  },
        \\  "language": "zig"
        \\}
    ;
    const r = try parseFromSlice(T, testing.allocator, str, .{ .ignore_unknown_fields = true });
    defer parseFree(T, testing.allocator, r);

    try testing.expectEqual(@as(i64, 420), r.int);
    try testing.expectEqualSlices(u8, "zig", r.language);
}

test "parse into tuple" {
    const Union = union(enum) {
        char: u8,
        float: f64,
        string: []const u8,
    };
    const T = std.meta.Tuple(&.{
        i64,
        f64,
        bool,
        []const u8,
        ?bool,
        struct {
            foo: i32,
            bar: []const u8,
        },
        std.meta.Tuple(&.{ u8, []const u8, u8 }),
        Union,
    });
    var str =
        \\[
        \\  420,
        \\  3.14,
        \\  true,
        \\  "zig",
        \\  null,
        \\  {
        \\    "foo": 1,
        \\    "bar": "zero"
        \\  },
        \\  [4, "två", 42],
        \\  {"float": 12.34}
        \\]
    ;
    const r = try parseFromSlice(T, testing.allocator, str, .{});
    defer parseFree(T, testing.allocator, r);
    try testing.expectEqual(@as(i64, 420), r[0]);
    try testing.expectEqual(@as(f64, 3.14), r[1]);
    try testing.expectEqual(true, r[2]);
    try testing.expectEqualSlices(u8, "zig", r[3]);
    try testing.expectEqual(@as(?bool, null), r[4]);
    try testing.expectEqual(@as(i32, 1), r[5].foo);
    try testing.expectEqualSlices(u8, "zero", r[5].bar);
    try testing.expectEqual(@as(u8, 4), r[6][0]);
    try testing.expectEqualSlices(u8, "två", r[6][1]);
    try testing.expectEqual(@as(u8, 42), r[6][2]);
    try testing.expectEqual(Union{ .float = 12.34 }, r[7]);
}

const ParseIntoRecursiveUnionDefinitionValue = union(enum) {
    integer: i64,
    array: []const ParseIntoRecursiveUnionDefinitionValue,
};

test "parse into recursive union definition" {
    const T = struct {
        values: ParseIntoRecursiveUnionDefinitionValue,
    };

    const r = try parseFromSlice(T, testing.allocator, "{\"values\":{\"array\":[{\"integer\":58}]}}", .{});
    defer parseFree(T, testing.allocator, r);

    try testing.expectEqual(@as(i64, 58), r.values.array[0].integer);
}

const ParseIntoDoubleRecursiveUnionValueFirst = union(enum) {
    integer: i64,
    array: []const ParseIntoDoubleRecursiveUnionValueSecond,
};

const ParseIntoDoubleRecursiveUnionValueSecond = union(enum) {
    boolean: bool,
    array: []const ParseIntoDoubleRecursiveUnionValueFirst,
};

test "parse into double recursive union definition" {
    const T = struct {
        values: ParseIntoDoubleRecursiveUnionValueFirst,
    };

    const r = try parseFromSlice(T, testing.allocator, "{\"values\":{\"array\":[{\"array\":[{\"integer\":58}]}]}}", .{});
    defer parseFree(T, testing.allocator, r);

    try testing.expectEqual(@as(i64, 58), r.values.array[0].array[0].integer);
}

test "parse exponential into int" {
    const T = struct { int: i64 };
    const r = try parseFromSlice(T, testing.allocator, "{ \"int\": 4.2e2 }", .{});
    try testing.expectEqual(@as(i64, 420), r.int);
    try testing.expectError(error.InvalidNumber, parseFromSlice(T, testing.allocator, "{ \"int\": 0.042e2 }", .{}));
    try testing.expectError(error.Overflow, parseFromSlice(T, testing.allocator, "{ \"int\": 18446744073709551616.0 }", .{}));
}

test "parseFromTokenSource" {
    var scanner = JsonScanner.initCompleteInput(testing.allocator, "123");
    defer scanner.deinit();
    try testing.expectEqual(@as(u32, 123), try parseFromTokenSource(u32, testing.allocator, &scanner, .{}));

    var stream = std.io.fixedBufferStream("123");
    var json_reader = jsonReader(std.testing.allocator, stream.reader());
    defer json_reader.deinit();
    try testing.expectEqual(@as(u32, 123), try parseFromTokenSource(u32, testing.allocator, &json_reader, .{}));
}

test "max_value_len" {
    try testing.expectError(error.ValueTooLong, parseFromSlice([]u8, testing.allocator, "\"0123456789\"", .{ .max_value_len = 5 }));
}

test "parse into vector" {
    const T = struct {
        vec_i32: @Vector(4, i32),
        vec_f32: @Vector(2, f32),
    };
    var s =
        \\{
        \\  "vec_f32": [1.5, 2.5],
        \\  "vec_i32": [4, 5, 6, 7]
        \\}
    ;
    const r = try parseFromSlice(T, testing.allocator, s, .{});
    defer parseFree(T, testing.allocator, r);
    try testing.expectApproxEqAbs(@as(f32, 1.5), r.vec_f32[0], 0.0000001);
    try testing.expectApproxEqAbs(@as(f32, 2.5), r.vec_f32[1], 0.0000001);
    try testing.expectEqual(@Vector(4, i32){ 4, 5, 6, 7 }, r.vec_i32);
}
