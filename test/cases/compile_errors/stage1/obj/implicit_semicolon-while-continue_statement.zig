export fn entry() void {
    while(true):({}) {}
    var good = {};
    while(true):({}) ({})
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:26: error: expected ';' or 'else' after statement
