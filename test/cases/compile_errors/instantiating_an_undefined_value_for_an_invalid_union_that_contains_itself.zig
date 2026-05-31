const Foo = union {
    x: Foo,
};

var foo: Foo = undefined;

export fn entry() usize {
    return @sizeOf(@TypeOf(foo.x));
}

// error
//
// :1:13: error: union 'tmp.Foo' depends on itself
