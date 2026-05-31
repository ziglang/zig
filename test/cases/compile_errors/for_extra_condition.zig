export fn a() void {
    for (0..10, 10..20) |i| {
        _ = i;
    }
}

// error
//
// :2:19: error: for input is not captured
