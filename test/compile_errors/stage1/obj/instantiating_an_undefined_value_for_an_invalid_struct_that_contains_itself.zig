const Foo = struct {
    x: Foo,
};

var foo: Foo = undefined;

export fn entry() usize {
    return @sizeOf(@TypeOf(foo.x));
}

// instantiating an undefined value for an invalid struct that contains itself
//
// tmp.zig:1:13: error: struct 'Foo' depends on itself
