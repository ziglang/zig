const Foo = struct {
    a: i32,
    b: i32,
};
const foo = Foo { .a = 1, .b = 2, };

comptime {
    const field_ptr = @intToPtr(*i32, 0x1234);
    const another_foo_ptr = @fieldParentPtr(Foo, "b", field_ptr);
    _ = another_foo_ptr;
}

// @fieldParentPtr - comptime field ptr not based on struct
//
// tmp.zig:9:55: error: pointer value not based on parent struct
