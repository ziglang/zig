export fn entry() void {
    _ = @TypeOf();
}

// error
// backend=stage2
// target=native
//
// :2:9: error: expected at least 1 argument, found 0
