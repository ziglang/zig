export fn entry() void {
    var p: ?i32 = undefined;
    comptime var q = true;
    inline while (q) {
        if (p) |_| continue;
        q = false;
    }
}

// comptime continue inside runtime if optional
//
// tmp.zig:5:20: error: comptime control flow inside runtime block
// tmp.zig:5:9: note: runtime block created here
