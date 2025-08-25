const Foo = enum {
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
// :2:5: error: duplicate enum member name 'Bar'
// :3:5: note: duplicate name here
// :1:13: note: enum declared here
