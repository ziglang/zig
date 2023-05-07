comptime{
    _ = @import("/usr/local/foo.zig");
}

// error
// backend=stage2
// target=native
//
// :2:17: error: cannot import by absolute path
