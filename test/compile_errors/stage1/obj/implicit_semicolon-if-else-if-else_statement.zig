export fn entry() void {
    if(true) {} else if(true) {} else {}
    var good = {};
    if(true) ({}) else if(true) ({}) else ({})
    var bad = {};
}

// implicit semicolon - if-else-if-else statement
//
// tmp.zig:4:47: error: expected ';' after statement
