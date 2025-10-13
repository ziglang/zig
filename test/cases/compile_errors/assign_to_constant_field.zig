const Foo = struct {
    field: i32,
};
export fn derp() void {
    const f = Foo{
        .field = 1234,
    };
    f.field = 0;
}

// error
//
// :8:6: error: cannot assign to constant
