const Foo = struct {
    Bar: u8,
    Baz: type,
};
export fn f() void {
    var x: u8 = 0;
    const foo = Foo{ .Bar = x, .Baz = u8 };
    _ = &x;
    _ = foo;
}

// error
//
// :7:23: error: unable to resolve comptime value
// :7:23: note: initializer of comptime-only struct 'tmp.Foo' must be comptime-known
// :3:10: note: struct requires comptime because of this field
// :3:10: note: types are not available at runtime
