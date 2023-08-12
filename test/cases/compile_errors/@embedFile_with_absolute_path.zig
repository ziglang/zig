comptime {
    _ = @embedFile("/usr/local/lib/foo.zig");
}


// error
// backend=stage2
// target=native
//
// :2:20: error: embeds using absolute paths are not supported: '/usr/local/lib/foo.zig'
