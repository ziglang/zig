const Foo = struct {
    x: Foo,
};

var foo: Foo = undefined;

export fn entry() usize {
    return @sizeOf(@TypeOf(foo.x));
}

// error
// backend=stage2
// target=native
//
// :1:13: error: struct 'tmp.Foo' depends on itself
// :2:5: note: while checking this field
