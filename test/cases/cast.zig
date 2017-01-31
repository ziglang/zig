const assert = @import("std").debug.assert;

fn intToPtrCast() {
    @setFnTest(this);

    const x = isize(13);
    const y = (&u8)(x);
    const z = usize(y);
    assert(z == 13);
}

fn numLitIntToPtrCast() {
    @setFnTest(this);

    const vga_mem = (&u16)(0xB8000);
    assert(usize(vga_mem) == 0xB8000);
}
