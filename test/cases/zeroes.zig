const assert = @import("std").debug.assert;

struct Foo {
    a: f32,
    b: i32,
    c: bool,
    d: ?i32,
}

fn initializing_a_struct_with_zeroes() {
    @setFnTest(this, true);

    const foo: Foo = zeroes;
    assert(foo.a == 0.0);
    assert(foo.b == 0);
    assert(foo.c == false);
    assert(if (const x ?= foo.d) false else true);
}

