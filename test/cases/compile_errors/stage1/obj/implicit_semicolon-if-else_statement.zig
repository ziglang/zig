export fn entry() void {
    if(true) {} else {}
    var good = {};
    if(true) ({}) else ({})
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:28: error: expected ';' after statement
