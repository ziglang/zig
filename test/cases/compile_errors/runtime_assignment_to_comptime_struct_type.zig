const Foo = struct {
    Bar: u8,
    Baz: type,
};
export fn f() void {
    var x: u8 = 0;
    const foo = Foo { .Bar = x, .Baz = u8 };
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :7:30: error: unable to resolve comptime value
// :7:30: note: initializer of comptime only struct must be comptime-known
