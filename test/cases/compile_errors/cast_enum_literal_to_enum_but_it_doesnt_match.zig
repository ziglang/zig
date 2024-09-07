const Foo = enum {
    a,
    b,
};
export fn entry() void {
    const x: Foo = .c;
    _ = x;
}

// error
// backend=stage2
// target=native
//
// :6:21: error: enum 'tmp.Foo' has no member named 'c'
// :1:13: note: enum declared here
