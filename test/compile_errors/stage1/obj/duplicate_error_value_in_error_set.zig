const Foo = error {
    Bar,
    Bar,
};
export fn entry() void {
    const a: Foo = undefined;
    _ = a;
}

// duplicate error value in error set
//
// tmp.zig:3:5: error: duplicate error set field 'Bar'
// tmp.zig:2:5: note: previous declaration here
