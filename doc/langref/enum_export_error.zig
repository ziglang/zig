const Foo = enum { a, b, c };
export fn entry(foo: Foo) void { _ = foo; }

// obj=parameter of type 'enum_export_error.Foo' not allowed in function with calling convention 'C'
