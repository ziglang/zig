export fn u() void {
    _ = @unionInit(0, "a", 0);
}

// error
// backend=stage2
// target=native
//
// :2:20: error: expected type 'type', found 'comptime_int'
