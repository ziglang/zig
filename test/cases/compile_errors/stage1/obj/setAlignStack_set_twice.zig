export fn entry() void {
    @setAlignStack(16);
    @setAlignStack(16);
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:5: error: alignstack set twice
// tmp.zig:2:5: note: first set here
