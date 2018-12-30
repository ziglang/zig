const std = @import("std");
const assertOrPanic = std.debug.assertOrPanic;
const builtin = @import("builtin");
const maxInt = std.math.maxInt;

const StructWithNoFields = struct {
    fn add(a: i32, b: i32) i32 {
        return a + b;
    }
};
const empty_global_instance = StructWithNoFields{};

test "call struct static method" {
    const result = StructWithNoFields.add(3, 4);
    assertOrPanic(result == 7);
}
