export fn entry() void {
    var p: usize = undefined;
    comptime var q = true;
    outer: inline while (q) {
        while (p == 11) continue :outer;
        q = false;
    }
}

// comptime continue inside runtime while bool
//
// tmp.zig:5:25: error: comptime control flow inside runtime block
// tmp.zig:5:9: note: runtime block created here
