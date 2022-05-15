const Foo = struct {
    Bar: i32,
    Bar: usize,
};
export fn entry() void {
    const a: Foo = undefined;
    _ = a;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:5: error: duplicate struct field: 'Bar'
// tmp.zig:2:5: note: other field here
