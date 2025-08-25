const foo = @import("foo");
const assert = @import("std").debug.assert;

pub fn main() void {
    assert(foo == foo.bar.foo);
    assert(foo == foo.bar.foo.bar.foo);
}
