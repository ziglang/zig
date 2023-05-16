const Foo = struct {
    a: undefined,
};
export fn entry1() void {
    const foo: Foo = undefined;
    _ = foo;
}

// error
// backend=stage2
// target=native
//
// :2:8: error: use of undefined value here causes undefined behavior
