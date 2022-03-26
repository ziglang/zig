const Foo = struct {
    a: undefined,
};
export fn entry1() void {
    const foo: Foo = undefined;
    _ = foo;
}

// undefined as field type is rejected
//
// tmp.zig:2:8: error: use of undefined value here causes undefined behavior
