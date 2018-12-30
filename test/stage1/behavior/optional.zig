const assertOrPanic = @import("std").debug.assertOrPanic;

pub const EmptyStruct = struct {};

test "optional pointer to size zero struct" {
    var e = EmptyStruct{};
    var o: ?*EmptyStruct = &e;
    assertOrPanic(o != null);
}
