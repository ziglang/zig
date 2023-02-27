const test_module = @import("test_module");
const assert = @import("std").debug.assert;

pub fn main() void {
    assert(test_module.header.add(1, 2) == 3);
}
