const Foo = error{A};
comptime {
    const z = Foo.Bar;
    _ = z;
}

// error
// backend=stage2
// target=native
//
// :3:18: error: no error named 'Bar' in 'error{A}'
