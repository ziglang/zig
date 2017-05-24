const assert = @import("std").debug.assert;

const Foo = struct {
    a: void,
    b: i32,
    c: void,
};

test "compare void with void compile time known" {
    comptime {
        const foo = Foo {
            .a = {},
            .b = 1,
            .c = {},
        };
        assert(foo.a == {});
    }
}
