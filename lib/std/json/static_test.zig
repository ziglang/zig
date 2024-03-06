const std = @import("std");
const testing = std.testing;
const ArenaAllocator = std.heap.ArenaAllocator;
const Allocator = std.mem.Allocator;

const parseFromSlice = @import("./static.zig").parseFromSlice;
const parseFromSliceLeaky = @import("./static.zig").parseFromSliceLeaky;
const parseFromTokenSource = @import("./static.zig").parseFromTokenSource;
const parseFromTokenSourceLeaky = @import("./static.zig").parseFromTokenSourceLeaky;
const innerParse = @import("./static.zig").innerParse;
const parseFromValue = @import("./static.zig").parseFromValue;
const parseFromValueLeaky = @import("./static.zig").parseFromValueLeaky;
const ParseOptions = @import("./static.zig").ParseOptions;

const JsonScanner = @import("./scanner.zig").Scanner;
const jsonReader = @import("./scanner.zig").reader;
const Diagnostics = @import("./scanner.zig").Diagnostics;

const Value = @import("./dynamic.zig").Value;

const Primitives = struct {
    bool: bool,
    // f16, f80, f128: don't work in std.fmt.parseFloat(T).
    f32: f32,
    f64: f64,
    u0: u0,
    i0: i0,
    u1: u1,
    i1: i1,
    u8: u8,
    i8: i8,
    i130: i130,
};

const primitives_0 = Primitives{
    .bool = false,
    .f32 = 0,
    .f64 = 0,
    .u0 = 0,
    .i0 = 0,
    .u1 = 0,
    .i1 = 0,
    .u8 = 0,
    .i8 = 0,
    .i130 = 0,
};
const primitives_0_doc_0 =
    \\{
    \\  "bool": false,
    \\  "f32": 0,
    \\  "f64": 0,
    \\  "u0": 0,
    \\  "i0": 0,
    \\  "u1": 0,
    \\  "i1": 0,
    \\  "u8": 0,
    \\  "i8": 0,
    \\  "i130": 0
    \\}
;
const primitives_0_doc_1 = // looks like a float.
    \\{
    \\  "bool": false,
    \\  "f32": 0.0,
    \\  "f64": 0.0,
    \\  "u0": 0.0,
    \\  "i0": 0.0,
    \\  "u1": 0.0,
    \\  "i1": 0.0,
    \\  "u8": 0.0,
    \\  "i8": 0.0,
    \\  "i130": 0.0
    \\}
;

const primitives_1 = Primitives{
    .bool = true,
    .f32 = 1073741824,
    .f64 = 1152921504606846976,
    .u0 = 0,
    .i0 = 0,
    .u1 = 1,
    .i1 = -1,
    .u8 = 255,
    .i8 = -128,
    .i130 = -680564733841876926926749214863536422911,
};
const primitives_1_doc_0 =
    \\{
    \\  "bool": true,
    \\  "f32": 1073741824,
    \\  "f64": 1152921504606846976,
    \\  "u0": 0,
    \\  "i0": 0,
    \\  "u1": 1,
    \\  "i1": -1,
    \\  "u8": 255,
    \\  "i8": -128,
    \\  "i130": -680564733841876926926749214863536422911
    \\}
;
const primitives_1_doc_1 = // float rounding.
    \\{
    \\  "bool": true,
    \\  "f32": 1073741825,
    \\  "f64": 1152921504606846977,
    \\  "u0": 0,
    \\  "i0": 0,
    \\  "u1": 1,
    \\  "i1": -1,
    \\  "u8": 255,
    \\  "i8": -128,
    \\  "i130": -680564733841876926926749214863536422911
    \\}
;

const Aggregates = struct {
    optional: ?i32,
    array: [4]i32,
    vector: @Vector(4, i32),
    pointer: *i32,
    pointer_const: *const i32,
    slice: []i32,
    slice_const: []const i32,
    slice_sentinel: [:0]i32,
    slice_sentinel_const: [:0]const i32,
};

var zero: i32 = 0;
const zero_const: i32 = 0;
var array_of_zeros: [4:0]i32 = [_:0]i32{ 0, 0, 0, 0 };
var one: i32 = 1;
const one_const: i32 = 1;
var array_countdown: [4:0]i32 = [_:0]i32{ 4, 3, 2, 1 };

const aggregates_0 = Aggregates{
    .optional = null,
    .array = [4]i32{ 0, 0, 0, 0 },
    .vector = @Vector(4, i32){ 0, 0, 0, 0 },
    .pointer = &zero,
    .pointer_const = &zero_const,
    .slice = array_of_zeros[0..0],
    .slice_const = &[_]i32{},
    .slice_sentinel = array_of_zeros[0..0 :0],
    .slice_sentinel_const = &[_:0]i32{},
};
const aggregates_0_doc =
    \\{
    \\  "optional": null,
    \\  "array": [0, 0, 0, 0],
    \\  "vector": [0, 0, 0, 0],
    \\  "pointer": 0,
    \\  "pointer_const": 0,
    \\  "slice": [],
    \\  "slice_const": [],
    \\  "slice_sentinel": [],
    \\  "slice_sentinel_const": []
    \\}
;

const aggregates_1 = Aggregates{
    .optional = 1,
    .array = [4]i32{ 1, 2, 3, 4 },
    .vector = @Vector(4, i32){ 1, 2, 3, 4 },
    .pointer = &one,
    .pointer_const = &one_const,
    .slice = array_countdown[0..],
    .slice_const = array_countdown[0..],
    .slice_sentinel = array_countdown[0.. :0],
    .slice_sentinel_const = array_countdown[0.. :0],
};
const aggregates_1_doc =
    \\{
    \\  "optional": 1,
    \\  "array": [1, 2, 3, 4],
    \\  "vector": [1, 2, 3, 4],
    \\  "pointer": 1,
    \\  "pointer_const": 1,
    \\  "slice": [4, 3, 2, 1],
    \\  "slice_const": [4, 3, 2, 1],
    \\  "slice_sentinel": [4, 3, 2, 1],
    \\  "slice_sentinel_const": [4, 3, 2, 1]
    \\}
;

const Strings = struct {
    slice_u8: []u8,
    slice_const_u8: []const u8,
    array_u8: [4]u8,
    slice_sentinel_u8: [:0]u8,
    slice_const_sentinel_u8: [:0]const u8,
    array_sentinel_u8: [4:0]u8,
};

var abcd = [4:0]u8{ 'a', 'b', 'c', 'd' };
const strings_0 = Strings{
    .slice_u8 = abcd[0..],
    .slice_const_u8 = "abcd",
    .array_u8 = [4]u8{ 'a', 'b', 'c', 'd' },
    .slice_sentinel_u8 = abcd[0..],
    .slice_const_sentinel_u8 = "abcd",
    .array_sentinel_u8 = [4:0]u8{ 'a', 'b', 'c', 'd' },
};
const strings_0_doc_0 =
    \\{
    \\  "slice_u8": "abcd",
    \\  "slice_const_u8": "abcd",
    \\  "array_u8": "abcd",
    \\  "slice_sentinel_u8": "abcd",
    \\  "slice_const_sentinel_u8": "abcd",
    \\  "array_sentinel_u8": "abcd"
    \\}
;
const strings_0_doc_1 =
    \\{
    \\  "slice_u8": [97, 98, 99, 100],
    \\  "slice_const_u8": [97, 98, 99, 100],
    \\  "array_u8": [97, 98, 99, 100],
    \\  "slice_sentinel_u8": [97, 98, 99, 100],
    \\  "slice_const_sentinel_u8": [97, 98, 99, 100],
    \\  "array_sentinel_u8": [97, 98, 99, 100]
    \\}
;

const Subnamespaces = struct {
    packed_struct: packed struct { a: u32, b: u32 },
    union_enum: union(enum) { i: i32, s: []const u8, v },
    inferred_enum: enum { a, b },
    explicit_enum: enum(u8) { a = 0, b = 1 },

    custom_struct: struct {
        pub fn jsonParse(allocator: Allocator, source: anytype, options: ParseOptions) !@This() {
            _ = allocator;
            _ = options;
            try source.skipValue();
            return @This(){};
        }
        pub fn jsonParseFromValue(allocator: Allocator, source: Value, options: ParseOptions) !@This() {
            _ = allocator;
            _ = source;
            _ = options;
            return @This(){};
        }
    },
    custom_union: union(enum) {
        i: i32,
        s: []const u8,
        pub fn jsonParse(allocator: Allocator, source: anytype, options: ParseOptions) !@This() {
            _ = allocator;
            _ = options;
            try source.skipValue();
            return @This(){ .i = 0 };
        }
        pub fn jsonParseFromValue(allocator: Allocator, source: Value, options: ParseOptions) !@This() {
            _ = allocator;
            _ = source;
            _ = options;
            return @This(){ .i = 0 };
        }
    },
    custom_enum: enum {
        a,
        b,
        pub fn jsonParse(allocator: Allocator, source: anytype, options: ParseOptions) !@This() {
            _ = allocator;
            _ = options;
            try source.skipValue();
            return .a;
        }
        pub fn jsonParseFromValue(allocator: Allocator, source: Value, options: ParseOptions) !@This() {
            _ = allocator;
            _ = source;
            _ = options;
            return .a;
        }
    },
};

const subnamespaces_0 = Subnamespaces{
    .packed_struct = .{ .a = 0, .b = 0 },
    .union_enum = .{ .i = 0 },
    .inferred_enum = .a,
    .explicit_enum = .a,
    .custom_struct = .{},
    .custom_union = .{ .i = 0 },
    .custom_enum = .a,
};
const subnamespaces_0_doc =
    \\{
    \\  "packed_struct": {"a": 0, "b": 0},
    \\  "union_enum": {"i": 0},
    \\  "inferred_enum": "a",
    \\  "explicit_enum": "a",
    \\  "custom_struct": null,
    \\  "custom_union": null,
    \\  "custom_enum": null
    \\}
;

fn testAllParseFunctions(comptime T: type, expected: T, doc: []const u8) !void {
    // First do the one with the debug info in case we get a SyntaxError or something.
    {
        var scanner = JsonScanner.initCompleteInput(testing.allocator, doc);
        defer scanner.deinit();
        var diagnostics = Diagnostics{};
        scanner.enableDiagnostics(&diagnostics);
        var parsed = parseFromTokenSource(T, testing.allocator, &scanner, .{}) catch |e| {
            std.debug.print("at line,col: {}:{}\n", .{ diagnostics.getLine(), diagnostics.getColumn() });
            return e;
        };
        defer parsed.deinit();
        try testing.expectEqualDeep(expected, parsed.value);
    }
    {
        const parsed = try parseFromSlice(T, testing.allocator, doc, .{});
        defer parsed.deinit();
        try testing.expectEqualDeep(expected, parsed.value);
    }
    {
        var stream = std.io.fixedBufferStream(doc);
        var json_reader = jsonReader(std.testing.allocator, stream.reader());
        defer json_reader.deinit();
        var parsed = try parseFromTokenSource(T, testing.allocator, &json_reader, .{});
        defer parsed.deinit();
        try testing.expectEqualDeep(expected, parsed.value);
    }

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    {
        try testing.expectEqualDeep(expected, try parseFromSliceLeaky(T, arena.allocator(), doc, .{}));
    }
    {
        var scanner = JsonScanner.initCompleteInput(testing.allocator, doc);
        defer scanner.deinit();
        try testing.expectEqualDeep(expected, try parseFromTokenSourceLeaky(T, arena.allocator(), &scanner, .{}));
    }
    {
        var stream = std.io.fixedBufferStream(doc);
        var json_reader = jsonReader(std.testing.allocator, stream.reader());
        defer json_reader.deinit();
        try testing.expectEqualDeep(expected, try parseFromTokenSourceLeaky(T, arena.allocator(), &json_reader, .{}));
    }

    const parsed_dynamic = try parseFromSlice(Value, testing.allocator, doc, .{});
    defer parsed_dynamic.deinit();
    {
        const parsed = try parseFromValue(T, testing.allocator, parsed_dynamic.value, .{});
        defer parsed.deinit();
        try testing.expectEqualDeep(expected, parsed.value);
    }
    {
        try testing.expectEqualDeep(expected, try parseFromValueLeaky(T, arena.allocator(), parsed_dynamic.value, .{}));
    }
}

test "test all types" {
    if (true) return error.SkipZigTest; // See https://github.com/ziglang/zig/issues/16108
    try testAllParseFunctions(Primitives, primitives_0, primitives_0_doc_0);
    try testAllParseFunctions(Primitives, primitives_0, primitives_0_doc_1);
    try testAllParseFunctions(Primitives, primitives_1, primitives_1_doc_0);
    try testAllParseFunctions(Primitives, primitives_1, primitives_1_doc_1);

    try testAllParseFunctions(Aggregates, aggregates_0, aggregates_0_doc);
    try testAllParseFunctions(Aggregates, aggregates_1, aggregates_1_doc);

    try testAllParseFunctions(Strings, strings_0, strings_0_doc_0);
    try testAllParseFunctions(Strings, strings_0, strings_0_doc_1);

    try testAllParseFunctions(Subnamespaces, subnamespaces_0, subnamespaces_0_doc);
}

test "parse" {
    try testing.expectEqual(false, try parseFromSliceLeaky(bool, testing.allocator, "false", .{}));
    try testing.expectEqual(true, try parseFromSliceLeaky(bool, testing.allocator, "true", .{}));
    try testing.expectEqual(1, try parseFromSliceLeaky(u1, testing.allocator, "1", .{}));
    try testing.expectError(error.Overflow, parseFromSliceLeaky(u1, testing.allocator, "50", .{}));
    try testing.expectEqual(42, try parseFromSliceLeaky(u64, testing.allocator, "42", .{}));
    try testing.expectEqual(42, try parseFromSliceLeaky(f64, testing.allocator, "42.0", .{}));
    try testing.expectEqual(null, try parseFromSliceLeaky(?bool, testing.allocator, "null", .{}));
    try testing.expectEqual(true, try parseFromSliceLeaky(?bool, testing.allocator, "true", .{}));

    try testing.expectEqual("foo".*, try parseFromSliceLeaky([3]u8, testing.allocator, "\"foo\"", .{}));
    try testing.expectEqual("foo".*, try parseFromSliceLeaky([3]u8, testing.allocator, "[102, 111, 111]", .{}));
    try testing.expectEqual(undefined, try parseFromSliceLeaky([0]u8, testing.allocator, "[]", .{}));

    try testing.expectEqual(12345678901234567890, try parseFromSliceLeaky(u64, testing.allocator, "\"12345678901234567890\"", .{}));
    try testing.expectEqual(123.456, try parseFromSliceLeaky(f64, testing.allocator, "\"123.456\"", .{}));
}

test "parse into enum" {
    const T = enum(u32) {
        Foo = 42,
        Bar,
        @"with\\escape",
    };
    try testing.expectEqual(.Foo, try parseFromSliceLeaky(T, testing.allocator, "\"Foo\"", .{}));
    try testing.expectEqual(.Foo, try parseFromSliceLeaky(T, testing.allocator, "42", .{}));
    try testing.expectEqual(.@"with\\escape", try parseFromSliceLeaky(T, testing.allocator, "\"with\\\\escape\"", .{}));
    try testing.expectError(error.InvalidEnumTag, parseFromSliceLeaky(T, testing.allocator, "5", .{}));
    try testing.expectError(error.InvalidEnumTag, parseFromSliceLeaky(T, testing.allocator, "\"Qux\"", .{}));
}

test "parse into that allocates a slice" {
    {
        // string as string
        const parsed = try parseFromSlice([]u8, testing.allocator, "\"foo\"", .{});
        defer parsed.deinit();
        try testing.expectEqualSlices(u8, "foo", parsed.value);
    }
    {
        // string as array of u8 integers
        const parsed = try parseFromSlice([]u8, testing.allocator, "[102, 111, 111]", .{});
        defer parsed.deinit();
        try testing.expectEqualSlices(u8, "foo", parsed.value);
    }
    {
        const parsed = try parseFromSlice([]u8, testing.allocator, "\"with\\\\escape\"", .{});
        defer parsed.deinit();
        try testing.expectEqualSlices(u8, "with\\escape", parsed.value);
    }
}

test "parse into sentinel slice" {
    const parsed = try parseFromSlice([:0]const u8, testing.allocator, "\"\\n\"", .{});
    defer parsed.deinit();
    try testing.expect(std.mem.eql(u8, parsed.value, "\n"));
}

test "parse into tagged union" {
    const T = union(enum) {
        nothing,
        int: i32,
        float: f64,
        string: []const u8,
    };
    try testing.expectEqual(T{ .float = 1.5 }, try parseFromSliceLeaky(T, testing.allocator, "{\"float\":1.5}", .{}));
    try testing.expectEqual(T{ .int = 1 }, try parseFromSliceLeaky(T, testing.allocator, "{\"int\":1}", .{}));
    try testing.expectEqual(T{ .nothing = {} }, try parseFromSliceLeaky(T, testing.allocator, "{\"nothing\":{}}", .{}));
    const parsed = try parseFromSlice(T, testing.allocator, "{\"string\":\"foo\"}", .{});
    defer parsed.deinit();
    try testing.expectEqualSlices(u8, "foo", parsed.value.string);
}

test "parse into tagged union errors" {
    const T = union(enum) {
        nothing,
        int: i32,
        float: f64,
        string: []const u8,
    };
    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();
    try testing.expectError(error.UnexpectedToken, parseFromSliceLeaky(T, arena.allocator(), "42", .{}));
    try testing.expectError(error.SyntaxError, parseFromSliceLeaky(T, arena.allocator(), "{\"int\":1} 42", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSliceLeaky(T, arena.allocator(), "{}", .{}));
    try testing.expectError(error.UnknownField, parseFromSliceLeaky(T, arena.allocator(), "{\"bogus\":1}", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSliceLeaky(T, arena.allocator(), "{\"int\":1, \"int\":1", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSliceLeaky(T, arena.allocator(), "{\"int\":1, \"float\":1.0}", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSliceLeaky(T, arena.allocator(), "{\"nothing\":null}", .{}));
    try testing.expectError(error.UnexpectedToken, parseFromSliceLeaky(T, arena.allocator(), "{\"nothing\":{\"no\":0}}", .{}));

    // Allocator failure
    try testing.expectError(error.OutOfMemory, parseFromSlice(T, testing.failing_allocator, "{\"string\"\"foo\"}", .{}));
}

test "parse into struct with no fields" {
    const T = struct {};
    const parsed = try parseFromSlice(T, testing.allocator, "{}", .{});
    defer parsed.deinit();
    try testing.expectEqual(T{}, parsed.value);
}

const test_const_value: usize = 123;

test "parse into struct with default const pointer field" {
    const T = struct { a: *const usize = &test_const_value };
    const parsed = try parseFromSlice(T, testing.allocator, "{}", .{});
    defer parsed.deinit();
    try testing.expectEqual(T{}, parsed.value);
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

    var parsed = try parseFromSlice(T, testing.allocator, "{}", .{});
    try testing.expectEqual(T{}, parsed.value);
    defer parsed.deinit();
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
    const document_str =
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
    const parsed = try parseFromSlice(T, testing.allocator, document_str, .{});
    defer parsed.deinit();
    const r = &parsed.value;
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
    const document_str =
        \\{
        \\  "language": "zig",
        \\  "language_without_sentinel": "zig again!",
        \\  "data": [1, 2, 3],
        \\  "simple_data": [4, 5, 6]
        \\}
    ;
    const parsed = try parseFromSlice(T, testing.allocator, document_str, .{});
    defer parsed.deinit();

    try testing.expectEqualSentinel(u8, 0, "zig", parsed.value.language);

    const data = [_:99]i32{ 1, 2, 3 };
    try testing.expectEqualSentinel(i32, 99, data[0..data.len], parsed.value.data);

    // Make sure that arrays who aren't supposed to have a sentinel still parse without one.
    try testing.expectEqual(@as(?i32, null), std.meta.sentinel(@TypeOf(parsed.value.simple_data)));
    try testing.expectEqual(@as(?u8, null), std.meta.sentinel(@TypeOf(parsed.value.language_without_sentinel)));
}

test "parse into struct with duplicate field" {
    const options_first = ParseOptions{ .duplicate_field_behavior = .use_first };
    const options_last = ParseOptions{ .duplicate_field_behavior = .use_last };

    const str = "{ \"a\": 1, \"a\": 0.25 }";

    const T1 = struct { a: *u64 };
    // both .use_first and .use_last should fail because second "a" value isn't a u64
    try testing.expectError(error.InvalidNumber, parseFromSlice(T1, testing.allocator, str, options_first));
    try testing.expectError(error.InvalidNumber, parseFromSlice(T1, testing.allocator, str, options_last));

    var arena = ArenaAllocator.init(testing.allocator);
    defer arena.deinit();

    const T2 = struct { a: f64 };
    try testing.expectEqual(T2{ .a = 1.0 }, try parseFromSliceLeaky(T2, arena.allocator(), str, options_first));
    try testing.expectEqual(T2{ .a = 0.25 }, try parseFromSliceLeaky(T2, arena.allocator(), str, options_last));
}

test "parse into struct ignoring unknown fields" {
    const T = struct {
        int: i64,
        language: []const u8,
    };

    const str =
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
    const parsed = try parseFromSlice(T, testing.allocator, str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    try testing.expectEqual(@as(i64, 420), parsed.value.int);
    try testing.expectEqualSlices(u8, "zig", parsed.value.language);
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
    const str =
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
    const parsed = try parseFromSlice(T, testing.allocator, str, .{});
    defer parsed.deinit();
    const r = parsed.value;
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

    const parsed = try parseFromSlice(T, testing.allocator, "{\"values\":{\"array\":[{\"integer\":58}]}}", .{});
    defer parsed.deinit();

    try testing.expectEqual(@as(i64, 58), parsed.value.values.array[0].integer);
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

    const parsed = try parseFromSlice(T, testing.allocator, "{\"values\":{\"array\":[{\"array\":[{\"integer\":58}]}]}}", .{});
    defer parsed.deinit();

    try testing.expectEqual(@as(i64, 58), parsed.value.values.array[0].array[0].integer);
}

test "parse exponential into int" {
    const T = struct { int: i64 };
    const r = try parseFromSliceLeaky(T, testing.allocator, "{ \"int\": 4.2e2 }", .{});
    try testing.expectEqual(@as(i64, 420), r.int);
    try testing.expectError(error.InvalidNumber, parseFromSliceLeaky(T, testing.allocator, "{ \"int\": 0.042e2 }", .{}));
    try testing.expectError(error.Overflow, parseFromSliceLeaky(T, testing.allocator, "{ \"int\": 18446744073709551616.0 }", .{}));
}

test "parseFromTokenSource" {
    {
        var scanner = JsonScanner.initCompleteInput(testing.allocator, "123");
        defer scanner.deinit();
        var parsed = try parseFromTokenSource(u32, testing.allocator, &scanner, .{});
        defer parsed.deinit();
        try testing.expectEqual(@as(u32, 123), parsed.value);
    }

    {
        var stream = std.io.fixedBufferStream("123");
        var json_reader = jsonReader(std.testing.allocator, stream.reader());
        defer json_reader.deinit();
        var parsed = try parseFromTokenSource(u32, testing.allocator, &json_reader, .{});
        defer parsed.deinit();
        try testing.expectEqual(@as(u32, 123), parsed.value);
    }
}

test "max_value_len" {
    try testing.expectError(error.ValueTooLong, parseFromSlice([]u8, testing.allocator, "\"0123456789\"", .{ .max_value_len = 5 }));
}

test "parse into vector" {
    const T = struct {
        vec_i32: @Vector(4, i32),
        vec_f32: @Vector(2, f32),
    };
    const s =
        \\{
        \\  "vec_f32": [1.5, 2.5],
        \\  "vec_i32": [4, 5, 6, 7]
        \\}
    ;
    const parsed = try parseFromSlice(T, testing.allocator, s, .{});
    defer parsed.deinit();
    try testing.expectApproxEqAbs(@as(f32, 1.5), parsed.value.vec_f32[0], 0.0000001);
    try testing.expectApproxEqAbs(@as(f32, 2.5), parsed.value.vec_f32[1], 0.0000001);
    try testing.expectEqual(@Vector(4, i32){ 4, 5, 6, 7 }, parsed.value.vec_i32);
}

fn assertKey(
    allocator: Allocator,
    test_string: []const u8,
    scanner: anytype,
) !void {
    const token_outer = try scanner.nextAlloc(allocator, .alloc_always);
    switch (token_outer) {
        .allocated_string => |string| {
            try testing.expectEqualSlices(u8, string, test_string);
            allocator.free(string);
        },
        else => return error.UnexpectedToken,
    }
}
test "json parse partial" {
    const Inner = struct {
        num: u32,
        yes: bool,
    };
    const str =
        \\{
        \\  "outer": {
        \\    "key1": {
        \\      "num": 75,
        \\      "yes": true
        \\    },
        \\    "key2": {
        \\      "num": 95,
        \\      "yes": false
        \\    }
        \\  }
        \\}
    ;
    const allocator = testing.allocator;
    var scanner = JsonScanner.initCompleteInput(allocator, str);
    defer scanner.deinit();

    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();

    // Peel off the outer object
    try testing.expectEqual(try scanner.next(), .object_begin);
    try assertKey(allocator, "outer", &scanner);
    try testing.expectEqual(try scanner.next(), .object_begin);
    try assertKey(allocator, "key1", &scanner);

    // Parse the inner object to an Inner struct
    const inner_token = try innerParse(
        Inner,
        arena.allocator(),
        &scanner,
        .{ .max_value_len = scanner.input.len },
    );
    try testing.expectEqual(inner_token.num, 75);
    try testing.expectEqual(inner_token.yes, true);

    // Get they next key
    try assertKey(allocator, "key2", &scanner);
    const inner_token_2 = try innerParse(
        Inner,
        arena.allocator(),
        &scanner,
        .{ .max_value_len = scanner.input.len },
    );
    try testing.expectEqual(inner_token_2.num, 95);
    try testing.expectEqual(inner_token_2.yes, false);
    try testing.expectEqual(try scanner.next(), .object_end);
}

test "json parse allocate when streaming" {
    const T = struct {
        not_const: []u8,
        is_const: []const u8,
    };
    const str =
        \\{
        \\  "not_const": "non const string",
        \\  "is_const": "const string"
        \\}
    ;
    const allocator = testing.allocator;
    var arena = ArenaAllocator.init(allocator);
    defer arena.deinit();

    var stream = std.io.fixedBufferStream(str);
    var json_reader = jsonReader(std.testing.allocator, stream.reader());

    const parsed = parseFromTokenSourceLeaky(T, arena.allocator(), &json_reader, .{}) catch |err| {
        json_reader.deinit();
        return err;
    };
    // Deinit our reader to invalidate its buffer
    json_reader.deinit();

    // If either of these was invalidated, it would be full of '0xAA'
    try testing.expectEqualSlices(u8, parsed.not_const, "non const string");
    try testing.expectEqualSlices(u8, parsed.is_const, "const string");
}

test "parse at comptime" {
    const doc =
        \\{
        \\    "vals": {
        \\        "testing": 1,
        \\        "production": 42
        \\    },
        \\    "uptime": 9999
        \\}
    ;
    const Config = struct {
        vals: struct { testing: u8, production: u8 },
        uptime: u64,
    };
    const config = comptime x: {
        var buf: [32]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        const res = parseFromSliceLeaky(Config, fba.allocator(), doc, .{});
        // Assert no error can occur since we are
        // parsing this JSON at comptime!
        break :x res catch unreachable;
    };
    comptime testing.expectEqual(@as(u64, 9999), config.uptime) catch unreachable;
}
