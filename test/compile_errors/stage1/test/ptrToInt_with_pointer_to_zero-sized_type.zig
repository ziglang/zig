export fn entry() void {
    var pointer: ?*u0 = null;
    var x = @ptrToInt(pointer);
    _ = x;
}

// @ptrToInt with pointer to zero-sized type
//
// tmp.zig:3:23: error: pointer to size 0 type has no address
