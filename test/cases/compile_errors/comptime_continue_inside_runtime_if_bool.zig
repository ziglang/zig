export fn entry() void {
    var p: usize = undefined;
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
// :5:22: error: comptime control flow inside runtime block
// :5:15: note: runtime control flow here
