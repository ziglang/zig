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
// backend=stage2
// target=native
//
// :8:23: error: unable to resolve comptime value
// :8:23: note: initializer of comptime only union must be comptime-known
