const Foo = struct {
    a: undefined,
};
export fn entry1() void {
    const foo: Foo = undefined;
    _ = foo;
}

// error
//
// :2:8: error: use of undefined value here causes illegal behavior
