const assert = @import("std").debug.assert;

const x = @intToPtr(&i32, 0x1000)[0..0x500];
const y = x[0x100..];
test "compile time slice of pointer to hard coded address" {
    assert(usize(x.ptr) == 0x1000);
    assert(x.len == 0x500);

    assert(usize(y.ptr) == 0x1100);
    assert(y.len == 0x400);
}
