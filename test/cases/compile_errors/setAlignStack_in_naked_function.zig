export fn entry() callconv(.Naked) void {
    @setAlignStack(16);
}

// error
// backend=stage2
// target=native
//
// :2:5: error: @setAlignStack in naked function
