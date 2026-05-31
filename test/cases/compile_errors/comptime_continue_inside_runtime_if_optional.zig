export fn entry() void {
    var p: ?i32 = undefined;
    _ = &p;
    comptime var q = true;
    inline while (q) {
        if (p) |_| continue;
        q = false;
    }
}

// error
//
// :6:20: error: comptime control flow inside runtime block
// :6:13: note: runtime control flow here
