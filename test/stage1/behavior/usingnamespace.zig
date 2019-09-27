const std = @import("std");

fn Foo(comptime T: type) type {
    return struct {
        usingnamespace T;
    };
}

test "usingnamespace inside a generic struct" {
    const std2 = Foo(std);
    const testing2 = Foo(std.testing);
    std2.testing.expect(true);
    testing2.expect(true);
}

usingnamespace struct {
    pub const foo = 42;
};

test "usingnamespace does not redeclare an imported variable" {
    comptime std.testing.expect(foo == 42);
}
