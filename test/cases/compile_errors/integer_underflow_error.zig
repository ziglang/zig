export fn entry() void {
    _ = @intToPtr(*anyopaque, ~@as(usize, @import("std").math.maxInt(usize)) - 1);
}

// error
// backend=stage2
// target=native
//
// :2:78: error: overflow of integer type 'usize' with value '-1'
