pub export fn entry() void {
    var arr: [100]u8 = undefined;
    for (arr) |bits| _ = @popCount(u8, bits);
}

// error
// backend=stage2
// target=native
//
// :3:26: error: expected 1 argument, found 2
