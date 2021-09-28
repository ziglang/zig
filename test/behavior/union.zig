const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const Tag = std.meta.Tag;

const Foo = union {
    float: f64,
    int: i32,
};

test "basic unions" {
    var foo = Foo{ .int = 1 };
    try expect(foo.int == 1);
    foo = Foo{ .float = 12.34 };
    try expect(foo.float == 12.34);
}
