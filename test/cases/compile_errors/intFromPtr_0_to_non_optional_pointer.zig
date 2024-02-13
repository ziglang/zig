export fn entry() void {
    const b: *i32 = @ptrFromInt(0);
    _ = b;
}

// error
// backend=stage2
// target=native
//
// :2:33: error: pointer type '*i32' does not allow address zero
