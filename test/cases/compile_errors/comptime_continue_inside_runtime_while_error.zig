export fn entry() void {
    var p: anyerror!usize = undefined;
    _ = &p;
    comptime var q = true;
    outer: inline while (q) {
        while (p) |_| {
            continue :outer;
        } else |_| {}
        q = false;
    }
}

// error
// backend=stage2
// target=native
//
// :7:13: error: comptime control flow inside runtime block
// :6:16: note: runtime control flow here
