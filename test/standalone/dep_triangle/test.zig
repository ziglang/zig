const foo = @import("foo");
const shared = @import("shared");
const assert = @import("std").debug.assert;

pub fn main() void {
    assert(foo.shared == shared);
}
