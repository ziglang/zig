export fn entry() void {
    if (foo()) |_| {}
    var good = {};
    if (foo()) |_| ({})
    var bad = {};
}

// implicit semicolon - test statement
//
// tmp.zig:4:24: error: expected ';' or 'else' after statement
