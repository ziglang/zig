export fn entry() void {
    comptime {
        @panic(
            "aoeu",
        );
    }
}

// error
// backend=stage2
// target=native
//
// :3:9: error: encountered @panic at comptime
