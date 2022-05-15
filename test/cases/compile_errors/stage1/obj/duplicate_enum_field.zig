const Foo = enum {
    Bar,
    Bar,
};

export fn entry() void {
    const a: Foo = undefined;
    _ = a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:5: error: duplicate enum field: 'Bar'
// tmp.zig:2:5: note: other field here
