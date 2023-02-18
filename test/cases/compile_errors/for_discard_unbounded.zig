export fn a() void {
    for (0..10, 10..) |i, _| {
        _ = i;
    }
}
// error
// backend=stage2
// target=native
//
// :2:27: error: discard of unbounded counter
