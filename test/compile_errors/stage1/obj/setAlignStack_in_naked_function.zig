export fn entry() callconv(.Naked) void {
    @setAlignStack(16);
}

// @setAlignStack in naked function
//
// tmp.zig:2:5: error: @setAlignStack in naked function
