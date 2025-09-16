export fn entry() void {
    comptime @trap();
}

// error
//
// :2:14: error: encountered @trap at comptime
