const my_pkg = @import("my_pkg");
const assert = @import("std").debug.assert;

pub fn main() void {
    assert(my_pkg.add(10, 20) == 30);
}
