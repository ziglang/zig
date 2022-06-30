export fn entry() void {
    @setAlignStack(16);
    @setAlignStack(16);
}

// error
// backend=stage2
// target=native
//
// :3:5: error: multiple @setAlignStack in the same function body
// :2:5: note: other instance here
