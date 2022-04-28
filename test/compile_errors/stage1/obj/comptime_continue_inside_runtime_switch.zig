export fn entry() void {
    var p: i32 = undefined;
    comptime var q = true;
    inline while (q) {
        switch (p) {
            11 => continue,
            else => {},
        }
        q = false;
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:6:19: error: comptime control flow inside runtime block
// tmp.zig:5:9: note: runtime block created here
