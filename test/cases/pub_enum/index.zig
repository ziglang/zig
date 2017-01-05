const other = @import("cases/pub_enum/other.zig");
const assert = @import("std").debug.assert;

fn pubEnum() {
    @setFnTest(this);

    pubEnumTest(other.APubEnum.Two);
}
fn pubEnumTest(foo: other.APubEnum) {
    assert(foo == other.APubEnum.Two);
}

fn castWithImportedSymbol() {
    @setFnTest(this);

    assert(other.size_t(42) == 42);
}
