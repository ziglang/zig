const std = @import("std");

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualDeep = std.testing.expectEqualDeep;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;

test "bool" {
    try expectEqual(true, @as(bool, @import("zon/true.zon")));
    try expectEqual(false, @as(bool, @import("zon/false.zon")));
}

test "optional" {
    const some: ?u32 = @import("zon/some.zon");
    const none: ?u32 = @import("zon/none.zon");
    const @"null": @TypeOf(null) = @import("zon/none.zon");
    try expectEqual(@as(u32, 10), some);
    try expectEqual(@as(?u32, null), none);
    try expectEqual(null, @"null");
}

test "union" {
    // No tag
    {
        const Union = union {
            x: f32,
            y: bool,
            z: void,
        };

        const union1: Union = @import("zon/union1.zon");
        const union2: Union = @import("zon/union2.zon");
        const union3: Union = @import("zon/union3.zon");

        try expectEqual(1.5, union1.x);
        try expectEqual(true, union2.y);
        try expectEqual({}, union3.z);
    }

    // Inferred tag
    {
        const Union = union(enum) {
            x: f32,
            y: bool,
            z: void,
        };

        const union1: Union = comptime @import("zon/union1.zon");
        const union2: Union = @import("zon/union2.zon");
        const union3: Union = @import("zon/union3.zon");

        try expectEqual(1.5, union1.x);
        try expectEqual(true, union2.y);
        try expectEqual({}, union3.z);
    }

    // Explicit tag
    {
        const Tag = enum(i128) {
            x = -1,
            y = 2,
            z = 1,
        };
        const Union = union(Tag) {
            x: f32,
            y: bool,
            z: void,
        };

        const union1: Union = @import("zon/union1.zon");
        const union2: Union = @import("zon/union2.zon");
        const union3: Union = @import("zon/union3.zon");

        try expectEqual(1.5, union1.x);
        try expectEqual(true, union2.y);
        try expectEqual({}, union3.z);
    }
}

test "struct" {
    const Vec0 = struct {};
    const Vec1 = struct { x: f32 };
    const Vec2 = struct { x: f32, y: f32 };
    const Escaped = struct { @"0": f32, foo: f32 };
    try expectEqual(Vec0{}, @as(Vec0, @import("zon/vec0.zon")));
    try expectEqual(Vec1{ .x = 1.5 }, @as(Vec1, @import("zon/vec1.zon")));
    try expectEqual(Vec2{ .x = 1.5, .y = 2 }, @as(Vec2, @import("zon/vec2.zon")));
    try expectEqual(Escaped{ .@"0" = 1.5, .foo = 2 }, @as(Escaped, @import("zon/escaped_struct.zon")));
}

test "struct default fields" {
    const Vec3 = struct {
        x: f32,
        y: f32,
        z: f32 = 123.4,
    };
    try expectEqual(Vec3{ .x = 1.5, .y = 2.0, .z = 123.4 }, @as(Vec3, @import("zon/vec2.zon")));
    const ascribed: Vec3 = @import("zon/vec2.zon");
    try expectEqual(Vec3{ .x = 1.5, .y = 2.0, .z = 123.4 }, ascribed);

    const Vec2 = struct {
        x: f32 = 20.0,
        y: f32 = 10.0,
    };
    try expectEqual(Vec2{ .x = 1.5, .y = 2.0 }, @as(Vec2, @import("zon/vec2.zon")));
}

test "struct enum field" {
    const Struct = struct {
        x: enum { x, y, z },
    };
    try expectEqual(Struct{ .x = .z }, @as(Struct, @import("zon/enum_field.zon")));
}

test "tuple" {
    const Tuple = struct { f32, bool, []const u8, u16 };
    try expectEqualDeep(Tuple{ 1.2, true, "hello", 3 }, @as(Tuple, @import("zon/tuple.zon")));
}

test "comptime fields" {
    // Test setting comptime tuple fields to the correct value
    {
        const Tuple = struct {
            comptime f32 = 1.2,
            comptime bool = true,
            comptime []const u8 = "hello",
            comptime u16 = 3,
        };
        try expectEqualDeep(Tuple{ 1.2, true, "hello", 3 }, @as(Tuple, @import("zon/tuple.zon")));
    }

    // Test setting comptime struct fields to the correct value
    {
        const Vec2 = struct {
            comptime x: f32 = 1.5,
            comptime y: f32 = 2.0,
        };
        try expectEqualDeep(Vec2{}, @as(Vec2, @import("zon/vec2.zon")));
    }

    // Test allowing comptime tuple fields to be set to their defaults
    {
        const Tuple = struct {
            f32,
            bool,
            []const u8,
            u16,
            comptime u8 = 255,
        };
        try expectEqualDeep(Tuple{ 1.2, true, "hello", 3 }, @as(Tuple, @import("zon/tuple.zon")));
    }

    // Test allowing comptime struct fields to be set to their defaults
    {
        const Vec2 = struct {
            comptime x: f32 = 1.5,
            comptime y: f32 = 2.0,
        };
        try expectEqualDeep(Vec2{}, @as(Vec2, @import("zon/slice-empty.zon")));
    }
}

test "char" {
    try expectEqual(@as(u8, 'a'), @as(u8, @import("zon/a.zon")));
    try expectEqual(@as(u8, 'z'), @as(u8, @import("zon/z.zon")));
}

test "arrays" {
    try expectEqual([0]u8{}, @as([0]u8, @import("zon/vec0.zon")));
    try expectEqual([0:1]u8{}, @as([0:1]u8, @import("zon/vec0.zon")));
    try expectEqual(1, @as([0:1]u8, @import("zon/vec0.zon"))[0]);
    try expectEqual([4]u8{ 'a', 'b', 'c', 'd' }, @as([4]u8, @import("zon/array.zon")));
    try expectEqual([4:2]u8{ 'a', 'b', 'c', 'd' }, @as([4:2]u8, @import("zon/array.zon")));
    try expectEqual(2, @as([4:2]u8, @import("zon/array.zon"))[4]);
}

test "slices, arrays, tuples" {
    {
        const expected_slice: []const u8 = &.{};
        const found_slice: []const u8 = @import("zon/slice-empty.zon");
        try expectEqualSlices(u8, expected_slice, found_slice);

        const expected_array: [0]u8 = .{};
        const found_array: [0]u8 = @import("zon/slice-empty.zon");
        try expectEqual(expected_array, found_array);

        const T = struct {};
        const expected_tuple: T = .{};
        const found_tuple: T = @import("zon/slice-empty.zon");
        try expectEqual(expected_tuple, found_tuple);
    }

    {
        const expected_slice: []const u8 = &.{1};
        const found_slice: []const u8 = @import("zon/slice1_no_newline.zon");
        try expectEqualSlices(u8, expected_slice, found_slice);

        const expected_array: [1]u8 = .{1};
        const found_array: [1]u8 = @import("zon/slice1_no_newline.zon");
        try expectEqual(expected_array, found_array);

        const T = struct { u8 };
        const expected_tuple: T = .{1};
        const found_tuple: T = @import("zon/slice1_no_newline.zon");
        try expectEqual(expected_tuple, found_tuple);
    }

    {
        const expected_slice: []const u8 = &.{ 'a', 'b', 'c' };
        const found_slice: []const u8 = @import("zon/slice-abc.zon");
        try expectEqualSlices(u8, expected_slice, found_slice);

        const expected_array: [3]u8 = .{ 'a', 'b', 'c' };
        const found_array: [3]u8 = @import("zon/slice-abc.zon");
        try expectEqual(expected_array, found_array);

        const T = struct { u8, u8, u8 };
        const expected_tuple: T = .{ 'a', 'b', 'c' };
        const found_tuple: T = @import("zon/slice-abc.zon");
        try expectEqual(expected_tuple, found_tuple);
    }
}

test "string literals" {
    try expectEqualSlices(u8, "abc", @import("zon/abc.zon"));
    try expectEqualSlices(u8, "ab\\c", @import("zon/abc-escaped.zon"));
    const zero_terminated: [:0]const u8 = @import("zon/abc.zon");
    try expectEqualDeep(zero_terminated, "abc");
    try expectEqual(0, zero_terminated[zero_terminated.len]);
    try expectEqualStrings(
        \\Hello, world!
        \\This is a multiline string!
        \\ There are no escapes, we can, for example, include \n in the string
    , @import("zon/multiline_string.zon"));
    try expectEqualStrings("a\nb\x00c", @import("zon/string_embedded_null.zon"));
}

test "enum literals" {
    const Enum = enum {
        foo,
        bar,
        baz,
        @"0\na",
    };
    try expectEqual(Enum.foo, @as(Enum, @import("zon/foo.zon")));
    try expectEqual(.foo, @as(@TypeOf(.foo), @import("zon/foo.zon")));
    try expectEqual(Enum.@"0\na", @as(Enum, @import("zon/escaped_enum.zon")));
}

test "int" {
    const T = struct {
        u8,
        i16,
        i14,
        i32,
        i8,
        i8,
        u8,
        u8,
        u65,
        u65,
        i128,
        i128,
        i66,
        i66,
        i8,
        i8,
        i16,
        i16,
        i16,
        i16,
        i16,
        i16,
        u65,
        i66,
        i66,
        u65,
        i66,
        i66,
        u65,
        i66,
        i66,
    };
    const expected: T = .{
        // Test various numbers and types
        10,
        24,
        -4,
        -123,

        // Test limits
        127,
        -128,

        // Test characters
        'a',
        'z',

        // Test big integers
        36893488147419103231,
        36893488147419103231,
        -18446744073709551615, // Only a big int due to negation
        -9223372036854775809, // Only a big int due to negation

        // Test big integer limits
        36893488147419103231,
        -36893488147419103232,

        // Test parsing whole number floats as integers
        -1,
        123,

        // Test non-decimal integers
        0xff,
        -0xff,
        0o77,
        -0o77,
        0b11,
        -0b11,

        // Test non-decimal big integers
        0x1ffffffffffffffff,
        0x1ffffffffffffffff,
        -0x1ffffffffffffffff,
        0x1ffffffffffffffff,
        0x1ffffffffffffffff,
        -0x1ffffffffffffffff,
        0x1ffffffffffffffff,
        0x1ffffffffffffffff,
        -0x1ffffffffffffffff,
    };
    const actual: T = @import("zon/ints.zon");
    try expectEqual(expected, actual);
}

test "floats" {
    const T = struct {
        f16,
        f32,
        f64,
        f128,
        f16,
        f16,
        f32,
        f32,
        f32,
        f32,
        f32,
        f32,
        f128,
        f32,
        f32,
        f32,
        f32,
        f32,
    };
    const expected: T = .{
        // Test decimals
        0.5,
        123.456,
        -123.456,
        42.5,

        // Test whole numbers with and without decimals
        5.0,
        5.0,
        -102,
        -102,

        // Test characters and negated characters
        'a',
        'z',

        // Test big integers
        36893488147419103231,
        -36893488147419103231,
        0x1ffffffffffffffff,
        0x1ffffffffffffffff,

        // Exponents, underscores
        123.0E+77,

        // Hexadecimal
        0x103.70p-5,
        -0x103.70,
        0x1234_5678.9ABC_CDEFp-10,
    };
    const actual: T = @import("zon/floats.zon");
    try expectEqual(expected, actual);
}

test "inf and nan" {
    // f32
    {
        const actual: struct { f32, f32, f32 } = @import("zon/inf_and_nan.zon");
        try expect(std.math.isNan(actual[0]));
        try expect(std.math.isPositiveInf(actual[1]));
        try expect(std.math.isNegativeInf(actual[2]));
    }

    // f128
    {
        const actual: struct { f128, f128, f128 } = @import("zon/inf_and_nan.zon");
        try expect(std.math.isNan(actual[0]));
        try expect(std.math.isPositiveInf(actual[1]));
        try expect(std.math.isNegativeInf(actual[2]));
    }
}

test "vector" {
    {
        const actual: @Vector(0, bool) = @import("zon/vec0.zon");
        const expected: @Vector(0, bool) = .{};
        try expectEqual(expected, actual);
    }
    {
        const actual: @Vector(3, bool) = @import("zon/vec3_bool.zon");
        const expected: @Vector(3, bool) = .{ false, false, true };
        try expectEqual(expected, actual);
    }

    {
        const actual: @Vector(0, f32) = @import("zon/vec0.zon");
        const expected: @Vector(0, f32) = .{};
        try expectEqual(expected, actual);
    }
    {
        const actual: @Vector(3, f32) = @import("zon/vec3_float.zon");
        const expected: @Vector(3, f32) = .{ 1.5, 2.5, 3.5 };
        try expectEqual(expected, actual);
    }

    {
        const actual: @Vector(0, u8) = @import("zon/vec0.zon");
        const expected: @Vector(0, u8) = .{};
        try expectEqual(expected, actual);
    }
    {
        const actual: @Vector(3, u8) = @import("zon/vec3_int.zon");
        const expected: @Vector(3, u8) = .{ 2, 4, 6 };
        try expectEqual(expected, actual);
    }

    {
        const actual: @Vector(0, *const u8) = @import("zon/vec0.zon");
        const expected: @Vector(0, *const u8) = .{};
        try expectEqual(expected, actual);
    }
    {
        const actual: @Vector(3, *const u8) = @import("zon/vec3_int.zon");
        const expected: @Vector(3, *const u8) = .{ &2, &4, &6 };
        try expectEqual(expected, actual);
    }

    {
        const actual: @Vector(0, ?*const u8) = @import("zon/vec0.zon");
        const expected: @Vector(0, ?*const u8) = .{};
        try expectEqual(expected, actual);
    }
    {
        const actual: @Vector(3, ?*const u8) = @import("zon/vec3_int_opt.zon");
        const expected: @Vector(3, ?*const u8) = .{ &2, null, &6 };
        try expectEqual(expected, actual);
    }
}

test "pointers" {
    // Primitive with varying levels of pointers
    try expectEqual(@as(u8, 'a'), @as(*const u8, @import("zon/a.zon")).*);
    try expectEqual(@as(u8, 'a'), @as(*const *const u8, @import("zon/a.zon")).*.*);
    try expectEqual(@as(u8, 'a'), @as(*const *const *const u8, @import("zon/a.zon")).*.*.*);

    // Primitive optional with varying levels of pointers
    try expectEqual(@as(u8, 'a'), @as(?*const u8, @import("zon/a.zon")).?.*);
    try expectEqual(null, @as(?*const u8, @import("zon/none.zon")));

    try expectEqual(@as(u8, 'a'), @as(*const ?u8, @import("zon/a.zon")).*.?);
    try expectEqual(null, @as(*const ?u8, @import("zon/none.zon")).*);

    try expectEqual(@as(u8, 'a'), @as(?*const *const u8, @import("zon/a.zon")).?.*.*);
    try expectEqual(null, @as(?*const *const u8, @import("zon/none.zon")));

    try expectEqual(@as(u8, 'a'), @as(*const ?*const u8, @import("zon/a.zon")).*.?.*);
    try expectEqual(null, @as(*const ?*const u8, @import("zon/none.zon")).*);

    try expectEqual(@as(u8, 'a'), @as(*const *const ?u8, @import("zon/a.zon")).*.*.?);
    try expectEqual(null, @as(*const *const ?u8, @import("zon/none.zon")).*.*);

    try expectEqual([3]u8{ 2, 4, 6 }, @as(*const [3]u8, @import("zon/vec3_int.zon")).*);

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
        const expected: Outer = .{
            .f1 = &&.{
                .f1 = &null,
                .f2 = &&"foo",
            },
            .f2 = &null,
        };

        const found: ?*const Outer = @import("zon/complex.zon");
        try std.testing.expectEqualDeep(expected, found.?.*);
    }
}

test "recursive" {
    const Recursive = struct { foo: ?*const @This() };
    const expected: Recursive = .{ .foo = &.{ .foo = null } };
    try expectEqualDeep(expected, @as(Recursive, @import("zon/recursive.zon")));
}
