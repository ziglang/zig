const Foo = struct {
    x: Foo,
};

var foo: Foo = undefined;

export fn entry() usize {
    return @sizeOf(@TypeOf(foo.x));
}

// error
//
// :1:13: error: struct 'tmp.Foo' depends on itself
