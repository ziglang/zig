const Foo = struct {
    a: undefined,
};
export fn entry1() void {
    const foo: Foo = undefined;
    _ = foo;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:8: error: use of undefined value here causes undefined behavior
