export fn entry() void {
    _ = @as(*anyopaque, @ptrFromInt(~@as(usize, @import("std").math.maxInt(usize)) - 1));
}

// error
// backend=stage2
// target=native
//
// :2:84: error: overflow of integer type 'usize' with value '-1'
