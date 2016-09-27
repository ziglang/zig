const assert = @import("std").debug.assert;
const other = @import("other.zig");

#attribute("test")
fn pubEnum() {
    pubEnumTest(other.APubEnum.Two);
}
fn pubEnumTest(foo: other.APubEnum) {
    assert(foo == other.APubEnum.Two);
}

#attribute("test")
fn castWithImportedSymbol() {
    assert(other.size_t(42) == 42);
}


