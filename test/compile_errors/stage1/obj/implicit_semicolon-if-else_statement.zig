export fn entry() void {
    if(true) {} else {}
    var good = {};
    if(true) ({}) else ({})
    var bad = {};
}

// implicit semicolon - if-else statement
//
// tmp.zig:4:28: error: expected ';' after statement
