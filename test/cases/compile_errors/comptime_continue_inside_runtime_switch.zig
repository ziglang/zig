export fn entry() void {
    var p: i32 = undefined;
    _ = &p;
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
// :7:19: error: comptime control flow inside runtime block
// :6:17: note: runtime control flow here
