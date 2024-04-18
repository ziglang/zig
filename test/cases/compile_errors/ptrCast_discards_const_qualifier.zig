export fn entry() void {
    const x: i32 = 1234;
    const y: *i32 = @ptrCast(&x);
    _ = y;
}

// error
// backend=stage2
// target=native
//
// :3:21: error: @ptrCast discards const qualifier
// :3:21: note: use @constCast to discard const qualifier
