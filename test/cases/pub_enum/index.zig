const other = @import("other.zig");
const assert = @import("std").debug.assert;

test "pub enum" {
    pubEnumTest(other.APubEnum.Two);
}
fn pubEnumTest(foo: other.APubEnum) void {
    assert(foo == other.APubEnum.Two);
}

test "cast with imported symbol" {
    assert(other.size_t(42) == 42);
}
