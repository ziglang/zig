const Foo = error{
    Bar,
    Bar,
};
export fn entry() void {
    const a: Foo = undefined;
    _ = a;
}

// error
// backend=stage2
// target=native
//
// :3:5: error: duplicate error set field 'Bar'
// :2:5: note: previous declaration here
