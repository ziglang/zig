const Foo = error{A};
comptime {
    const z = Foo.Bar;
    _ = z;
}

// access non-existent member of error set
//
// tmp.zig:3:18: error: no error named 'Bar' in 'Foo'
