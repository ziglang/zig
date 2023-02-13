export fn entry() void {
    const x: i32 = 1234;
    const y = @ptrCast(*i32, &x);
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :3:15: error: cast discards const qualifier
// :3:15: note: consider using '@constCast'
