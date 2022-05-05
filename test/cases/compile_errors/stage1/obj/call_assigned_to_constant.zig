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
// backend=stage1
// target=native
//
// tmp.zig:12:14: error: cannot assign to constant
// tmp.zig:16:14: error: cannot assign to constant
