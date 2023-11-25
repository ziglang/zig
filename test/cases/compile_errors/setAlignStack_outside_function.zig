comptime {
    @setAlignStack(16);
}

// error
// backend=stage2
// target=native
//
// :2:5: error: @setAlignStack outside function body
