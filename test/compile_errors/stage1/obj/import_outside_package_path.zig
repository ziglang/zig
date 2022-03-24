comptime{
    _ = @import("../a.zig");
}

// import outside package path
//
// tmp.zig:2:9: error: import of file outside package path: '../a.zig'
