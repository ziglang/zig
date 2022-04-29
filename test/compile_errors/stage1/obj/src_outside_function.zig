comptime {
    @src();
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: @src outside function
