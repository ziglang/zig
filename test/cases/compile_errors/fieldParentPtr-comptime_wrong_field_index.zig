const Foo = struct {
    a: i32,
    b: i32,
};
const foo = Foo{
    .a = 1,
    .b = 2,
};

comptime {
    const another_foo_ptr: *const Foo = @fieldParentPtr("b", &foo.a);
    _ = another_foo_ptr;
}

// error
// backend=stage2
// target=native
//
// :11:41: error: field 'b' has index '1' but pointer value is index '0' of struct 'tmp.Foo'
// :1:13: note: struct declared here
