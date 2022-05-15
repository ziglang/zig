comptime {
    @setAlignStack(16);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: @setAlignStack outside function
