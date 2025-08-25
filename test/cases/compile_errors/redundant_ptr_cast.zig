const p: *anyopaque = undefined;
export fn a() void {
    _ = @ptrCast(@ptrCast(p));
}
export fn b() void {
    const ptr1: *u32 = @alignCast(@ptrCast(@alignCast(p)));
    _ = ptr1;
}
export fn c() void {
    _ = @constCast(@alignCast(@ptrCast(@constCast(@volatileCast(p)))));
}

// error
// backend=stage2
// target=native
//
// :3:18: error: redundant @ptrCast
// :6:44: error: redundant @alignCast
// :10:40: error: redundant @constCast
