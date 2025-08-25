export fn entry() void {
    var p: usize = undefined;
    _ = &p;
    comptime var q = true;
    outer: inline while (q) {
        while (p == 11) continue :outer;
        q = false;
    }
}

// error
// backend=stage2
// target=native
//
// :6:25: error: comptime control flow inside runtime block
// :6:18: note: runtime control flow here
