const assertOrPanic = @import("std").debug.assertOrPanic;

const Foo = struct {
    a: void,
    b: i32,
    c: void,
};

test "compare void with void compile time known" {
    comptime {
        const foo = Foo{
            .a = {},
            .b = 1,
            .c = {},
        };
        assertOrPanic(foo.a == {});
    }
}

test "iterate over a void slice" {
    var j: usize = 0;
    for (times(10)) |_, i| {
        assertOrPanic(i == j);
        j += 1;
    }
}

fn times(n: usize) []const void {
    return ([*]void)(undefined)[0..n];
}

test "void optional" {
    var x: ?void = {};
    assertOrPanic(x != null);
}
