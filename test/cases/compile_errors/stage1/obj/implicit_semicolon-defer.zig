export fn entry() void {
    defer {}
    var good = {};
    defer ({})
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:15: error: expected ';' after statement
