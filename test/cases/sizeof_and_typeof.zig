fn sizeofAndTypeOf() {
    @setFnTest(this);

    const y: @typeOf(x) = 120;
    assert(@sizeOf(@typeOf(y)) == 2);
}
const x: u16 = 13;
const z: @typeOf(x) = 19;

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
