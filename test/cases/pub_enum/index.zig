const other = @import("other.zig");
const assert = @import("std").debug.assert;

test "pubEnum" {
    pubEnumTest(other.APubEnum.Two);
}
fn pubEnumTest(foo: other.APubEnum) {
    assert(foo == other.APubEnum.Two);
}

test "castWithImportedSymbol" {
    assert(other.size_t(42) == 42);
}
