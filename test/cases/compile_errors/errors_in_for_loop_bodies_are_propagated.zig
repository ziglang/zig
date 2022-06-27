pub export fn entry() void {
    var arr: [100]u8 = undefined;
    for (arr) |bits| _ = @popCount(bits);
}

// error
// backend=stage2
// target=native
//
// :3:26: error: expected 2 arguments, found 1
