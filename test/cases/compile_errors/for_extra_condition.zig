export fn a() void {
    for (0..10, 10..20) |i| {
        _ = i;
    }
}

// error
// backend=stage2
// target=native
//
// :2:19: error: for input is not captured
