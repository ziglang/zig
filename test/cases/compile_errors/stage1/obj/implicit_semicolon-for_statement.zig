export fn entry() void {
    for(foo()) |_| {}
    var good = {};
    for(foo()) |_| ({})
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:24: error: expected ';' or 'else' after statement
