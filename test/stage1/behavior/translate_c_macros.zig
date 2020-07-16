const expect = @import("std").testing.expect;

const h = @cImport(@cInclude("stage1/behavior/translate_c_macros.h"));

test "initializer list expression" {
    @import("std").testing.expectEqual(h.Color{
        .r = 200,
        .g = 200,
        .b = 200,
        .a = 255,
    }, h.LIGHTGRAY);
}
