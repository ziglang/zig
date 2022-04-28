export fn a() void {
    _ = @as(i32, 1) <<| @as(i32, -2);
}

// error
// backend=stage1
// target=native
//
// error: shift by negative value -2
