const std = @import("std");

const Foo = struct {
    free: bool,

    pub const FooError = error{NotFree};
};

var foo = Foo{ .free = true };
var default_foo: ?*Foo = null;

fn get_foo() Foo.FooError!*Foo {
    if (foo.free) {
        foo.free = false;
        return &foo;
    }
    return error.NotFree;
}

test "fixed" {
    default_foo = get_foo() catch null; // This Line
    try std.testing.expect(!default_foo.?.free);
}
