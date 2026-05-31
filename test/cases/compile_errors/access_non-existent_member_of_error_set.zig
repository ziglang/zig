const Foo = error{A};
comptime {
    const z = Foo.Bar;
    _ = z;
}

// error
//
// :3:18: error: no error named 'Bar' in 'error{A}'
