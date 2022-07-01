export fn entry() void {
    var pointer: ?*u0 = null;
    var x = @ptrToInt(pointer);
    _ = x;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:23: error: pointer to size 0 type has no address
