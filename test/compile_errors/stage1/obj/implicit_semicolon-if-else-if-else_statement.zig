export fn entry() void {
    if(true) {} else if(true) {} else {}
    var good = {};
    if(true) ({}) else if(true) ({}) else ({})
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:47: error: expected ';' after statement
