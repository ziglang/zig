export fn entry() void {
    _ = if(true) {};
    var good = {};
    _ = if(true) {}
    var bad = {};
}

// implicit semicolon - if expression
//
// tmp.zig:4:20: error: expected ';' after statement
