export fn entry() void {
    comptime {}
    var good = {};
    comptime ({})
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:18: error: expected ';' after statement
