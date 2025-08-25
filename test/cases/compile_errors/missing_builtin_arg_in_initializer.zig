comptime {
    const a = @as();
}
comptime {
    const b = @bitCast();
}
comptime {
    const c = @as(u32);
}

// error
// backend=stage2
// target=native
//
// :2:15: error: expected 2 arguments, found 0
// :5:15: error: expected 1 argument, found 0
// :8:15: error: expected 2 arguments, found 1
