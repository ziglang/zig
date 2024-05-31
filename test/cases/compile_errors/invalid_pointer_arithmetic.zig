export fn a(x: [*]u8) void {
    _ = x * 1;
}

export fn b(x: *u8) void {
    _ = x * x;
}

// error
// backend=stage2
// target=native
//
// :2:11: error: invalid pointer-integer arithmetic operator
// :2:11: note: pointer-integer arithmetic only supports addition and subtraction
// :6:11: error: invalid pointer-pointer arithmetic operator
// :6:11: note: pointer-pointer arithmetic only supports subtraction
