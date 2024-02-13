export fn entry() void {
    comptime @trap();
}

// error
// backend=stage2
// target=native
//
// :2:14: error: encountered @trap at comptime
