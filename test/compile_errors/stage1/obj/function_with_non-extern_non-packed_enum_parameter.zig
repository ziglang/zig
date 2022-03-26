const Foo = enum { A, B, C };
export fn entry(foo: Foo) void { _ = foo; }

// function with non-extern non-packed enum parameter
//
// tmp.zig:2:22: error: parameter of type 'Foo' not allowed in function with calling convention 'C'
