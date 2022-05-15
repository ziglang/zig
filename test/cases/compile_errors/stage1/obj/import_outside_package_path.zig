comptime{
    _ = @import("../a.zig");
}

// error
// backend=stage1
// target=native
//
// tmp.zig:2:9: error: import of file outside package path: '../a.zig'
