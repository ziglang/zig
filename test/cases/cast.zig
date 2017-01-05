const assert = @import("std").debug.assert;

fn intToPtrCast() {
    @setFnTest(this);

    const x = isize(13);
    const y = (&u8)(x);
    const z = usize(y);
    assert(z == 13);
}
