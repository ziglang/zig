const foo = @import("foo");
const shared = @import("shared");
const assert = @import("std").debug.assert;

pub fn main() void {
    assert(foo == foo.foo);
    assert(foo == foo.foo.foo);
}
