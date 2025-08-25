const Foo = enum { A, B, C };
export fn entry(foo: Foo) void {
    _ = foo;
}

// error
// target=x86_64-linux
//
// :2:17: error: parameter of type 'tmp.Foo' not allowed in function with calling convention 'x86_64_sysv'
// :2:17: note: enum tag type 'u2' is not extern compatible
// :2:17: note: only integers with 0, 8, 16, 32, 64 and 128 bits are extern compatible
// :1:13: note: enum declared here
