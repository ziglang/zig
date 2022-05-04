const Foo = extern struct {
    a: i32,
};

export fn entry(foo: [*]Foo) void {
    foo.a += 1;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:8: error: type '[*]Foo' does not support field access
