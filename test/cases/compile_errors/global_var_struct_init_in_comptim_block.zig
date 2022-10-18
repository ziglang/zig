const Foo = struct {
    x: i32,
};
var x: Foo = .{ .x = 2 };
comptime {
    x = .{ .x = 3 };
}

// error
// backend=stage2
// target=native
//
// :6:17: error: unable to evaluate comptime expression
// :6:17: note: operation is runtime due to this operand
