export fn entry() void {
    var p: anyerror!i32 = undefined;
    _ = &p;
    comptime var q = true;
    inline while (q) {
        if (p) |_| continue else |_| {}
        q = false;
    }
}

// error
// backend=stage2
// target=native
//
// :6:20: error: comptime control flow inside runtime block
// :6:13: note: runtime control flow here
