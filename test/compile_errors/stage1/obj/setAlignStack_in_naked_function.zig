export fn entry() callconv(.Naked) void {
    @setAlignStack(16);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: @setAlignStack in naked function
