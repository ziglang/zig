export fn f() void {
    var bad: bool = undefined;
    bad[0] = bad[0];
}
export fn g() void {
    const bad: bool = undefined;
    _ = bad[0];
}

// error
// backend=stage2
// target=native
//
// :3:8: error: type 'bool' does not support indexing
// :3:8: note: operand must be an array, slice, tuple, or vector
// :7:12: error: type 'bool' does not support indexing
// :7:12: note: operand must be an array, slice, tuple, or vector
