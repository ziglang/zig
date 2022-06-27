export fn entry() void {
    var b = @intToPtr(*i32, 0);
    _ = b;
}

// error
// backend=stage2
// target=native
//
// :2:29: error: pointer type '*i32' does not allow address zero
