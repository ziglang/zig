export fn entry() void {
    if(true) {} else if(true) {}
    var good = {};
    if(true) ({}) else if(true) ({})
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:37: error: expected ';' or 'else' after statement
