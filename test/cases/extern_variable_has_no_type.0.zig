comptime {
    const x = foo + foo;
    _ = x;
}
extern var foo: i32;

// error
//
// :2:15: error: unable to resolve comptime value
