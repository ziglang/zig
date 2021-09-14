const expect = @import("std").testing.expect;
const expectEqual = @import("std").testing.expectEqual;

const h = @cImport(@cInclude("behavior/translate_c_macros.h"));

test "initializer list expression" {
    try expectEqual(h.Color{
        .r = 200,
        .g = 200,
        .b = 200,
        .a = 255,
    }, h.LIGHTGRAY);
}

test "sizeof in macros" {
    try expectEqual(@as(c_int, @sizeOf(u32)), h.MY_SIZEOF(u32));
    try expectEqual(@as(c_int, @sizeOf(u32)), h.MY_SIZEOF2(u32));
}

test "reference to a struct type" {
    try expectEqual(@sizeOf(h.struct_Foo), h.SIZE_OF_FOO);
}

test "cast negative integer to pointer" {
    try expectEqual(@intToPtr(?*c_void, @bitCast(usize, @as(isize, -1))), h.MAP_FAILED);
}

test "casting to void with a macro" {
    h.IGNORE_ME_1(42);
    h.IGNORE_ME_2(42);
    h.IGNORE_ME_3(42);
    h.IGNORE_ME_4(42);
    h.IGNORE_ME_5(42);
    h.IGNORE_ME_6(42);
    h.IGNORE_ME_7(42);
    h.IGNORE_ME_8(42);
    h.IGNORE_ME_9(42);
    h.IGNORE_ME_10(42);
}
