export fn entry() void {
    if(true) {}
    var good = {};
    if(true) ({})
    var bad = {};
}

// implicit semicolon - if statement
//
// tmp.zig:4:18: error: expected ';' or 'else' after statement
