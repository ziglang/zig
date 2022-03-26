const Foo = union {
    Bar: i32,
    Bar: usize,
};
export fn entry() void {
    const a: Foo = undefined;
    _ = a;
}

// duplicate union field
//
// tmp.zig:3:5: error: duplicate union field: 'Bar'
// tmp.zig:2:5: note: other field here
