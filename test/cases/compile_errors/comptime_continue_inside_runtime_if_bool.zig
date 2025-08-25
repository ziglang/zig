export fn entry() void {
    var p: usize = undefined;
    _ = &p;
    comptime var q = true;
    inline while (q) {
        if (p == 11) continue;
        q = false;
    }
}

// error
// backend=stage2
// target=native
//
// :6:22: error: comptime control flow inside runtime block
// :6:15: note: runtime control flow here
