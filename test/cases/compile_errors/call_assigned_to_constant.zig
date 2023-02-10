const Foo = struct {
    x: i32,
};
fn foo() Foo {
    return .{ .x = 42 };
}
fn bar(val: anytype) Foo {
    return .{ .x = val };
}
export fn entry() void {
    const baz: Foo = undefined;
    baz = foo();
}
export fn entry1() void {
    const baz: Foo = undefined;
    baz = bar(42);
}

// error
// backend=stage2
// target=native
//
// :12:5: error: cannot assign to constant
// :16:5: error: cannot assign to constant
