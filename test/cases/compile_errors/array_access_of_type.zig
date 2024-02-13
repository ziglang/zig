export fn foo() void {
    var b: u8[40] = undefined;
    _ = &b;
}

// error
// backend=stage2
// target=native
//
// :2:14: error: type 'type' does not support indexing
// :2:14: note: operand must be an array, slice, tuple, or vector
