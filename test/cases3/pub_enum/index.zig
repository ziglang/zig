const other = @import("cases3/pub_enum/other.zig");

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


// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
