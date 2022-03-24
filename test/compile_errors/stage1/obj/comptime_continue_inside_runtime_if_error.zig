export fn entry() void {
    var p: anyerror!i32 = undefined;
    comptime var q = true;
    inline while (q) {
        if (p) |_| continue else |_| {}
        q = false;
    }
}

// comptime continue inside runtime if error
//
// tmp.zig:5:20: error: comptime control flow inside runtime block
// tmp.zig:5:9: note: runtime block created here
