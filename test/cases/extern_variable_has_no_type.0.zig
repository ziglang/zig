comptime {
    const x = foo + foo;
    _ = x;
}
extern var foo: i32;

// error
//
// :2:15: error: cannot load runtime value in comptime block
