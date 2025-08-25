export fn b() void {
    for (0..) |i| {
        _ = i;
    }
}

// error
// backend=stage2
// target=native
//
// :2:5: error: unbounded for loop
