const expect = @import("std").testing.expect;
const expectEqual = @import("std").testing.expectEqual;

const h = @cImport(@cInclude("behavior/translate_c_macros.h"));

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
