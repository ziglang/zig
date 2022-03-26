comptime {
    @setAlignStack(16);
}

// @setAlignStack outside function
//
// tmp.zig:2:5: error: @setAlignStack outside function
