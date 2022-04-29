export fn entry() void {
    var p: anyerror!usize = undefined;
    comptime var q = true;
    outer: inline while (q) {
        while (p) |_| {
            continue :outer;
        } else |_| {}
        q = false;
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:13: error: comptime control flow inside runtime block
// tmp.zig:5:9: note: runtime block created here
