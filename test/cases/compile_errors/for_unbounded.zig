export fn b() void {
    for (0..) |i| {
        _ = i;
    }
}

// error
//
// :2:5: error: unbounded for loop
