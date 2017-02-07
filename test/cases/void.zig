const assert = @import("std").debug.assert;

const Foo = struct {
    a: void,
    b: i32,
    c: void,
};

fn compareVoidWithVoidCompileTimeKnown() {
    @setFnTest(this);

    comptime {
        const foo = Foo {
            .a = {},
            .b = 1,
            .c = {},
        };
        assert(foo.a == {});
    }
}
