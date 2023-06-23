const Foo = struct {
    a: i32,
    b: i32,
};
const foo = Foo{
    .a = 1,
    .b = 2,
};

comptime {
    const field_ptr = @ptrFromInt(*i32, 0x1234);
    const another_foo_ptr = @fieldParentPtr(Foo, "b", field_ptr);
    _ = another_foo_ptr;
}

// error
// backend=stage2
// target=native
//
// :12:55: error: pointer value not based on parent struct
