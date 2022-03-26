export fn entry() void {
    _ = if(true) {} else if(true) {} else {};
    var good = {};
    _ = if(true) {} else if(true) {} else {}
    var bad = {};
}

// implicit semicolon - if-else-if-else expression
//
// tmp.zig:4:45: error: expected ';' after statement
