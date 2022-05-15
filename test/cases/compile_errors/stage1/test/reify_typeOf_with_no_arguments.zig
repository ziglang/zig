export fn entry() void {
    _ = @TypeOf();
}

// error
// backend=stage1
// target=native
// is_test=1
//
// tmp.zig:2:9: error: expected at least 1 argument, found 0
