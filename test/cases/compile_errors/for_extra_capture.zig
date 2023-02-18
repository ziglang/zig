export fn b() void {
    for (0..10) |i, j| {
        _ = i; _ = j;
    }
}

// error
// backend=stage2
// target=native
//
// :2:21: error: extra capture in for loop
// :2:21: note: run 'zig fmt' to upgrade your code automatically
