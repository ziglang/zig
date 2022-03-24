const Foo = struct {
    a: i32,
    b: i32,
};
const foo = Foo { .a = 1, .b = 2, };

comptime {
    const another_foo_ptr = @fieldParentPtr(Foo, "b", &foo.a);
    _ = another_foo_ptr;
}

// @fieldParentPtr - comptime wrong field index
//
// tmp.zig:8:29: error: field 'b' has index 1 but pointer value is index 0 of struct 'Foo'
