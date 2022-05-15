const Foo = error{A};
comptime {
    const z = Foo.Bar;
    _ = z;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:18: error: no error named 'Bar' in 'Foo'
