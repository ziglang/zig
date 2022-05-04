export fn entry() void {
    @setAlignStack(511 + 1);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:5: error: attempt to @setAlignStack(512); maximum is 256
