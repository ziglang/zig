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
// backend=stage2
// target=native
//
// :6:19: error: comptime control flow inside runtime block
// :5:17: note: runtime control flow here
