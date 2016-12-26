//fn intToPtrCast() {
//    @setFnTest(this);
//
//    const x = isize(13);
//    const y = (&u8)(x);
//    const z = usize(y);
//    assert(z == 13);
//}

// TODO const assert = @import("std").debug.assert;
fn assert(ok: bool) {
    if (!ok)
        @unreachable();
}
