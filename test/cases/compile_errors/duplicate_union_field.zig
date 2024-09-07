const Foo = union {
    Bar: i32,
    Bar: usize,
};
export fn entry() void {
    const a: Foo = undefined;
    _ = a;
}

// error
//
// :2:5: error: duplicate union member name 'Bar'
// :3:5: note: duplicate name here
// :1:13: note: union declared here
