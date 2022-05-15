const Foo = union {
    Bar: u8,
    Baz: type,
};
export fn f() void {
    var x: u8 = 0;
    const foo = Foo { .Bar = x };
    _ = foo;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:7:23: error: unable to evaluate constant expression
