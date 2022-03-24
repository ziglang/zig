export fn entry() void {
    for(foo()) |_| {}
    var good = {};
    for(foo()) |_| ({})
    var bad = {};
}

// implicit semicolon - for statement
//
// tmp.zig:4:24: error: expected ';' or 'else' after statement
