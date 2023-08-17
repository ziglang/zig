const Foo = enum { A, B, C };
export fn entry(foo: Foo) void {
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :2:17: error: parameter of type 'tmp.Foo' not allowed in function with calling convention 'C'
// :2:17: note: enum tag type 'u2' is not extern compatible
// :2:17: note: only integers with 0, 8, 16, 32, 64 and 128 bits are extern compatible
// :1:13: note: enum declared here
