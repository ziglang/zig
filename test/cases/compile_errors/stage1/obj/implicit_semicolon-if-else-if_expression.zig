export fn entry() void {
    _ = if(true) {} else if(true) {};
    var good = {};
    _ = if(true) {} else if(true) {}
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:37: error: expected ';' after statement
