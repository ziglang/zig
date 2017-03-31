const assert = @import("std").debug.assert;

test "intToPtrCast" {
    const x = isize(13);
    const y = (&u8)(x);
    const z = usize(y);
    assert(z == 13);
}

test "numLitIntToPtrCast" {
    const vga_mem = (&u16)(0xB8000);
    assert(usize(vga_mem) == 0xB8000);
}

test "pointerReinterpretConstFloatToInt" {
    const float: f64 = 5.99999999999994648725e-01;
    const float_ptr = &float;
    const int_ptr = @ptrcast(&i32, float_ptr);
    const int_val = *int_ptr;
    assert(int_val == 858993411);
}

test "implicitly cast a pointer to a const pointer of it" {
    var x: i32 = 1;
    const xp = &x;
    funcWithConstPtrPtr(xp);
    assert(x == 2);
}

fn funcWithConstPtrPtr(x: &const &i32) {
    **x += 1;
}
