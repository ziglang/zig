export fn entry() void {
    _ = {};
    var good = {};
    _ = {}
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:11: error: expected ';' after statement
