const Foo = extern struct {
    a: i32,
};

export fn entry(foo: [*]Foo) void {
    foo.a += 1;
}

// field access of unknown length pointer
//
// tmp.zig:6:8: error: type '[*]Foo' does not support field access
