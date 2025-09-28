// zig fmt: off
export fn b() void {
    for (0..10) |i, j| {
        _ = i;
        _ = j;
    }
}
// zig fmt: on

// error
//
// :3:21: error: extra capture in for loop
