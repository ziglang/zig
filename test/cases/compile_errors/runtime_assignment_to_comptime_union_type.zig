const Foo = union {
    Bar: u8,
    Baz: type,
};
export fn f() void {
    var x: u8 = 0;
    const foo = Foo{ .Bar = x };
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :7:29: error: unable to resolve comptime value
// :7:29: note: initializer of comptime only union must be comptime-known
