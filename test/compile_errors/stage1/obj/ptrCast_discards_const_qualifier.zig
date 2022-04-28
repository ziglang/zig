export fn entry() void {
    const x: i32 = 1234;
    const y = @ptrCast(*i32, &x);
    _ = y;
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:15: error: cast discards const qualifier
