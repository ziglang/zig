export fn entry() void {
    _ = @intToPtr(*anyopaque, ~@as(usize, @import("std").math.maxInt(usize)) - 1);
}

// error
// backend=stage1
// target=native
//
// :2:78: error: operation caused overflow
