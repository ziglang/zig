export fn entry() void {
    _ = if (foo()) |_| {};
    var good = {};
    _ = if (foo()) |_| {}
    var bad = {};
}

// implicit semicolon - test expression
//
// tmp.zig:4:26: error: expected ';' after statement
