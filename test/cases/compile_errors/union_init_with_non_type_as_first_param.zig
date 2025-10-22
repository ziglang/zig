export fn u() void {
    _ = @unionInit(0, "a", 0);
}

// error
//
// :2:20: error: expected type 'type', found 'comptime_int'
