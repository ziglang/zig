export fn entry() void {
    @setAlignStack(511 + 1);
}

// @setAlignStack too big
//
// tmp.zig:2:5: error: attempt to @setAlignStack(512); maximum is 256
