// zig fmt: off
export fn b() void {
    for (0..10) |i, j| {
        _ = i;
        _ = j;
    }
}
// zig fmt: on

// error
// backend=stage2
// target=native
//
// :3:21: error: extra capture in for loop
