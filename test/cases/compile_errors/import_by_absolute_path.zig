comptime {
    _ = @import("/usr/local/foo.zig");
}


// error
// backend=stage2
// target=native
//
// :2:17: error: imports using absolute paths are not supported: '/usr/local/foo.zig'
