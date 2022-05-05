export fn entry() void {
    _ = while(true):({}) {};
    var good = {};
    _ = while(true):({}) {}
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:28: error: expected ';' after statement
