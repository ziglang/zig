comptime {
    @setAlignStack(16);
}

comptime {
    @setCold(true);
}

comptime {
    _ = @returnAddress();
}

// error
// backend=stage2
// target=native
//
// :2:5: error: @setAlignStack outside function body
// :6:5: error: @setCold outside function body
// :10:9: error: @returnAddress outside function body
