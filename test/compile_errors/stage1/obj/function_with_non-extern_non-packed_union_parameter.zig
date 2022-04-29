const Foo = union {
    A: i32,
    B: f32,
    C: bool,
};
export fn entry(foo: Foo) void { _ = foo; }

// error
// backend=stage1
// target=native
//
// tmp.zig:6:22: error: parameter of type 'Foo' not allowed in function with calling convention 'C'
