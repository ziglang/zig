export fn entry() void {
    var p: ?usize = undefined;
    _ = &p;
    comptime var q = true;
    outer: inline while (q) {
        while (p) |_| continue :outer;
        q = false;
    }
}

// error
// backend=stage2
// target=native
//
// :6:23: error: comptime control flow inside runtime block
// :6:16: note: runtime control flow here
