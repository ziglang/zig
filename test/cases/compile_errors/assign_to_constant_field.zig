const Foo = struct {
    field: i32,
};
export fn derp() void {
    const f = Foo {.field = 1234,};
    f.field = 0;
}

// error
// backend=stage2
// target=native
//
// :6:15: error: cannot assign to constant
