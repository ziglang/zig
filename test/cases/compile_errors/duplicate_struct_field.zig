const Foo = struct {
    Bar: i32,
    Bar: usize,
};
export fn entry() void {
    const a: Foo = undefined;
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :3:5: error: duplicate struct field: 'Bar'
// :2:5: note: other field here
// :1:13: note: struct declared here
