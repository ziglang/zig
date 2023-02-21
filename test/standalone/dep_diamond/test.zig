const foo = @import("foo");
const bar = @import("bar");
const assert = @import("std").debug.assert;

pub fn main() void {
    assert(foo.shared == bar.shared);
}
