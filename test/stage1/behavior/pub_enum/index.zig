const other = @import("other.zig");
const assertOrPanic = @import("std").debug.assertOrPanic;

test "pub enum" {
    pubEnumTest(other.APubEnum.Two);
}
fn pubEnumTest(foo: other.APubEnum) void {
    assertOrPanic(foo == other.APubEnum.Two);
}

test "cast with imported symbol" {
    assertOrPanic(other.size_t(42) == 42);
}
