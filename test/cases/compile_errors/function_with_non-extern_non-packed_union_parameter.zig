const Foo = union {
    A: i32,
    B: f32,
    C: bool,
};
export fn entry(foo: Foo) void { _ = foo; }

// error
// backend=stage2
// target=native
//
// :6:17: error: parameter of type 'tmp.Foo' not allowed in function with calling convention 'C'
// :6:17: note: only unions with packed or extern layout are extern compatible
// :1:13: note: union declared here
