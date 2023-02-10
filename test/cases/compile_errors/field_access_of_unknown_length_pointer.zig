const Foo = extern struct {
    a: i32,
};

export fn entry(foo: [*]Foo) void {
    foo.a += 1;
}

// error
// backend=stage2
// target=native
//
// :6:8: error: type '[*]tmp.Foo' does not support field access
