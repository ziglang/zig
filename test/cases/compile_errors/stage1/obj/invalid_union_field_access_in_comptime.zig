const Foo = union {
    Bar: u8,
    Baz: void,
};
comptime {
    var foo = Foo {.Baz = {}};
    const bar_val = foo.Bar;
    _ = bar_val;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:7:24: error: accessing union field 'Bar' while field 'Baz' is set
