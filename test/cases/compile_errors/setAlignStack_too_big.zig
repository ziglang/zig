export fn entry() void {
    @setAlignStack(511 + 1);
}

// error
// backend=stage2
// target=native
//
// :2:5: error: attempt to @setAlignStack(512); maximum is 256
