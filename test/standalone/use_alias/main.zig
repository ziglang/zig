const c = @import("c.zig");
const assert = @import("std").debug.assert;

test "symbol exists" {
    var foo = c.Foo{
        .a = 1,
        .b = 1,
    };
    assert(foo.a + foo.b == 2);
}
