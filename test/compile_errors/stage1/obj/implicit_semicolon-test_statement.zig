export fn entry() void {
    if (foo()) |_| {}
    var good = {};
    if (foo()) |_| ({})
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:24: error: expected ';' or 'else' after statement
