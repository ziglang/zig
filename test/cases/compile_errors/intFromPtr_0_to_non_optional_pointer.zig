export fn entry() void {
    var b: *i32 = @ptrFromInt(0);
    _ = b;
}

// error
// backend=stage2
// target=native
//
// :2:31: error: pointer type '*i32' does not allow address zero
