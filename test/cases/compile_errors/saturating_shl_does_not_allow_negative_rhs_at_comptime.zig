export fn a() void {
    _ = @as(i32, 1) <<| @as(i32, -2);
}

// error
// backend=stage2
// target=native
//
// :2:25: error: shift by negative amount '-2'
