export fn entry() void {
    comptime {
        @panic("aoeu",);
    }
}

// @panic called at compile time
//
// tmp.zig:3:9: error: encountered @panic at compile-time
