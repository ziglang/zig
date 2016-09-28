const assert = @import("std").debug.assert;
const other = @import("other.zig");

fn pubEnum() {
    @setFnTest(this, true);

    pubEnumTest(other.APubEnum.Two);
}
fn pubEnumTest(foo: other.APubEnum) {
    assert(foo == other.APubEnum.Two);
}

fn castWithImportedSymbol() {
    @setFnTest(this, true);

    assert(other.size_t(42) == 42);
}


