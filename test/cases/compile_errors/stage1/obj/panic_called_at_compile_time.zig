export fn entry() void {
    comptime {
        @panic("aoeu",);
    }
}

// error
// backend=stage1
// target=native
//
// tmp.zig:3:9: error: encountered @panic at compile-time
