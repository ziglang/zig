export fn entry() void {
    _ = if(true) {} else if(true) {};
    var good = {};
    _ = if(true) {} else if(true) {}
    var bad = {};
}

// implicit semicolon - if-else-if expression
//
// tmp.zig:4:37: error: expected ';' after statement
