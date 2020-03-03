const std = @import("std");

extern var obj1_integer: usize;
extern var obj2_integer: usize;

test "access the external integers" {
    std.testing.expect(obj1_integer == 421);
    std.testing.expect(obj2_integer == 422);
}
