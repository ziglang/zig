const assert = @import("std").debug.assert;

#attribute("test")
fn sizeofAndTypeOf() {
    const y: @typeOf(x) = 120;
    assert(@sizeOf(@typeOf(y)) == 2);
}
const x: u16 = 13;
const z: @typeOf(x) = 19;
