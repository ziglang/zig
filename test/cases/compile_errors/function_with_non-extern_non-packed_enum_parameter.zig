const Foo = enum { A, B, C };
export fn entry(foo: Foo) void { _ = foo; }

// error
// backend=stage2
// target=native
//
// :2:8: error: parameter of type 'tmp.Foo' not allowed in function with calling convention 'C'
// :2:8: note: enum tag type 'u2' is not extern compatible
// :2:8: note: only integers with power of two bits are extern compatible
// :1:13: note: enum declared here
