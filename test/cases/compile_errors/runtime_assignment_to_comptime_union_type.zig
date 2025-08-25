const Foo = union {
    Bar: u8,
    Baz: type,
};
export fn f() void {
    var x: u8 = 0;
    _ = &x;
    const foo = Foo{ .Bar = x };
    _ = foo;
}

// error
//
// :8:23: error: unable to resolve comptime value
// :8:23: note: initializer of comptime-only union 'tmp.Foo' must be comptime-known
// :3:10: note: union requires comptime because of this field
// :3:10: note: types are not available at runtime
