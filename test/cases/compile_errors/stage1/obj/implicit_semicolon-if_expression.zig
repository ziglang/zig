export fn entry() void {
    _ = if(true) {};
    var good = {};
    _ = if(true) {}
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:20: error: expected ';' after statement
