const Foo = struct {
    Bar: i32,
    Bar: usize,
};
export fn entry() void {
    const a: Foo = undefined;
    _ = a;
}

// duplicate struct field
//
// tmp.zig:3:5: error: duplicate struct field: 'Bar'
// tmp.zig:2:5: note: other field here
