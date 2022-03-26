export fn entry() void {
    var p: ?usize = undefined;
    comptime var q = true;
    outer: inline while (q) {
        while (p) |_| continue :outer;
        q = false;
    }
}

// comptime continue inside runtime while optional
//
// tmp.zig:5:23: error: comptime control flow inside runtime block
// tmp.zig:5:9: note: runtime block created here
