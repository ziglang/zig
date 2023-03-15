const test_module = @import("test_module");
const assert = @import("std").debug.assert;

extern fn fabs(num: f32) f32;

pub fn main() void {
    assert(test_module.c.abs(-1) == 1);
    assert(fabs(fabs(-1.0) - 1.0) < 1e-7);
}
