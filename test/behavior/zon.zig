const std = @import("std");

const expectEqual = std.testing.expectEqual;
const expectEqualDeep = std.testing.expectEqualDeep;
const expectEqualSlices = std.testing.expectEqualSlices;

test "void" {
    try expectEqual({}, @import("zon/void.zon"));
}

test "bool" {
    try expectEqual(true, @import("zon/true.zon"));
    try expectEqual(false, @import("zon/false.zon"));
}

test "optional" {
    // Coercion
    const some: ?u32 = @import("zon/some.zon");
    const none: ?u32 = @import("zon/none.zon");
    try expectEqual(some, 10);
    try expectEqual(none, null);

    // No coercion
    try expectEqual(some, @import("zon/some.zon"));
    try expectEqual(none, @import("zon/none.zon"));
}

test "union" {
    const Union = union {
        x: f32,
        y: bool,
    };

    const union1: Union = @import("zon/union1.zon");
    const union2: Union = @import("zon/union2.zon");

    try expectEqual(union1.x, 1.5);
    try expectEqual(union2.y, true);
}

test "struct" {
    try expectEqual(.{}, @import("zon/vec0.zon"));
    try expectEqual(.{ .x = 1.5 }, @import("zon/vec1.zon"));
    try expectEqual(.{ .x = 1.5, .y = 2 }, @import("zon/vec2.zon"));
}

test "struct default fields" {
    const Vec3 = struct {
        x: f32,
        y: f32,
        z: f32 = 123.4,
    };
    try expectEqual(Vec3{ .x = 1.5, .y = 2.0, .z = 123.4 }, @import("zon/vec2.zon"));
}

test "struct enum field" {
    const Struct = struct {
        x: enum { x, y, z },
    };
    try expectEqual(Struct{ .x = .z }, @import("zon/enum_field.zon"));
}

test "tuple" {
    try expectEqualDeep(.{ 1.2, true, "hello", 3 }, @import("zon/tuple.zon"));
}

test "char" {
    try expectEqual('a', @import("zon/a.zon"));
    try expectEqual('z', @import("zon/z.zon"));
    try expectEqual(-'a', @import("zon/a_neg.zon"));
}

test "arrays" {
    try expectEqual([0]u8{}, @import("zon/vec0.zon"));
    try expectEqual([4]u8{ 'a', 'b', 'c', 'd' }, @import("zon/array.zon"));
    try expectEqual([4:2]u8{ 'a', 'b', 'c', 'd' }, @import("zon/array.zon"));
}

test "slices" {
    try expectEqualSlices(u8, &.{}, @import("zon/slice-empty.zon"));
    try expectEqualSlices(u8, &.{ 'a', 'b', 'c' }, @import("zon/slice-abc.zon"));
}

test "string literals" {
    try expectEqualDeep("abc", @import("zon/abc.zon"));
    try expectEqualDeep("ab\\c", @import("zon/abc-escaped.zon"));
    const zero_terminated: [:0]const u8 = @import("zon/abc.zon");
    try expectEqualDeep(zero_terminated, "abc");
}

test "enum literals" {
    const Enum = enum {
        foo,
        bar,
        baz,
    };
    try expectEqual(Enum.foo, @import("zon/foo.zon"));
}

test "int" {
    const expected = .{
        // Test various numbers and types
        @as(u8, 10),
        @as(i16, 24),
        @as(i14, -4),
        @as(i32, -123),

        // Test limits
        @as(i8, 127),
        @as(i8, -128),

        // Test characters
        @as(u8, 'a'),
        @as(u8, 'z'),

        // Test big integers
        @as(u65, 36893488147419103231),
        @as(u65, 36893488147419103231),

        // Test big integer limits
        @as(i66, 36893488147419103231),
        @as(i66, -36893488147419103232),

        // Test parsing whole number floats as integers
        @as(i8, -1),
        @as(i8, 123),

        // Test non-decimal integers
        @as(i16, 0xff),
        @as(i16, -0xff),
        @as(i16, 0o77),
        @as(i16, -0o77),
        @as(i16, 0b11),
        @as(i16, -0b11),

        // Test non-decimal big integers
        @as(u65, 0x1ffffffffffffffff),
        @as(i66, 0x1ffffffffffffffff),
        @as(i66, -0x1ffffffffffffffff),
        @as(u65, 0x1ffffffffffffffff),
        @as(i66, 0x1ffffffffffffffff),
        @as(i66, -0x1ffffffffffffffff),
        @as(u65, 0x1ffffffffffffffff),
        @as(i66, 0x1ffffffffffffffff),
        @as(i66, -0x1ffffffffffffffff),
    };
    const actual: @TypeOf(expected) = @import("zon/ints.zon");
    try expectEqual(expected, actual);
}

test "floats" {
    const expected = .{
        // Test decimals
        @as(f16, 0.5),
        @as(f32, 123.456),
        @as(f64, -123.456),
        @as(f128, 42.5),

        // Test whole numbers with and without decimals
        @as(f16, 5.0),
        @as(f16, 5.0),
        @as(f32, -102),
        @as(f32, -102),

        // Test characters and negated characters
        @as(f32, 'a'),
        @as(f32, 'z'),
        @as(f32, -'z'),

        // Test big integers
        @as(f32, 36893488147419103231),
        @as(f32, -36893488147419103231),
        @as(f128, 0x1ffffffffffffffff),
        @as(f32, 0x1ffffffffffffffff),

        // Exponents, underscores
        @as(f32, 123.0E+77),

        // Hexadecimal
        @as(f32, 0x103.70p-5),
        @as(f32, -0x103.70),
        @as(f32, 0x1234_5678.9ABC_CDEFp-10),
    };
    const actual: @TypeOf(expected) = @import("zon/floats.zon");
    try expectEqual(actual, expected);
}
