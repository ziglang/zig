comptime{
    _ = @import("../a.zig");
}

// error
// backend=stage2
// target=native
//
// :2:17: error: import of file outside package path: '../a.zig'
