comptime {
    const x = foo + foo;
    _ = x;
}
extern var foo: i32;

// error
//
// :2:19: error: unable to evaluate comptime expression
// :2:15: note: operation is runtime due to this operand
