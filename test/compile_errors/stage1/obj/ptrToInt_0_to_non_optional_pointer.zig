export fn entry() void {
    var b = @intToPtr(*i32, 0);
    _ = b;
}

// @ptrToInt 0 to non optional pointer
//
// tmp.zig:2:13: error: pointer type '*i32' does not allow address zero
