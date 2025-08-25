const foo = @import("foo");
const assert = @import("std").debug.assert;

pub fn main() void {
    assert(foo == foo.foo);
    assert(foo == foo.foo.foo);
}
