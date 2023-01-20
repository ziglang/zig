comptime {
    const v = @as();
}
comptime {
    const u = @bitCast(u32);
}

// error
// backend=stage2
// target=native
//
// :2:15: error: expected 2 arguments, found 0
// :5:15: error: expected 2 arguments, found 1
