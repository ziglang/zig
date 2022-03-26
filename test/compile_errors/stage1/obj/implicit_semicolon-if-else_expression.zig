export fn entry() void {
    _ = if(true) {} else {};
    var good = {};
    _ = if(true) {} else {}
    var bad = {};
}

// implicit semicolon - if-else expression
//
// tmp.zig:4:28: error: expected ';' after statement
