const assert = @import("std").debug.assert;

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
        assert(foo.a == {});
    }
}

test "iterate over a void slice" {
    var j: usize = 0;
    for (times(10)) |_, i| {
        assert(i == j);
        j += 1;
    }
}

fn times(n: usize) []const void {
    return ([*]void)(undefined)[0..n];
}
