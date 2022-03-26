const Foo = struct {
    Bar: u8,
    Baz: type,
};
export fn f() void {
    var x: u8 = 0;
    const foo = Foo { .Bar = x, .Baz = u8 };
    _ = foo;
}

// runtime assignment to comptime struct type
//
// tmp.zig:7:23: error: unable to evaluate constant expression
