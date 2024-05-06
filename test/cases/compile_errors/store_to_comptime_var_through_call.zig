export fn entry(b: bool) void {
    comptime var int = 0;
    if (b) {
        comptime incr(&int);
    }
}
fn incr(x: *comptime_int) void {
    x.* += 1;
}

// error
//
// :8:9: error: store to comptime variable depends on runtime condition
// :3:9: note: runtime condition here
// :4:22: note: called from here
