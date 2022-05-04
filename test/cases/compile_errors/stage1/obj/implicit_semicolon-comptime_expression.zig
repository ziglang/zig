export fn entry() void {
    _ = comptime {};
    var good = {};
    _ = comptime {}
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:20: error: expected ';' after statement
