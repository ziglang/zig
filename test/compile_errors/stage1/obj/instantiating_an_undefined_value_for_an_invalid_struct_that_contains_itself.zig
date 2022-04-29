const Foo = struct {
    x: Foo,
};

var foo: Foo = undefined;

export fn entry() usize {
    return @sizeOf(@TypeOf(foo.x));
}

// error
// backend=stage1
// target=native
//
// tmp.zig:1:13: error: struct 'Foo' depends on itself
