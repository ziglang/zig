const c = @import("c.zig");
const expect = @import("std").testing.expect;

test "symbol exists" {
    var foo = c.Foo{
        .a = 1,
        .b = 1,
    };
    _ = &foo;
    try expect(foo.a + foo.b == 2);
}
