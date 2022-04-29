export fn entry() void {
    if(true) {}
    var good = {};
    if(true) ({})
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:18: error: expected ';' or 'else' after statement
