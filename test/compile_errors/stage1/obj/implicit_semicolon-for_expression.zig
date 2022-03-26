export fn entry() void {
    _ = for(foo()) |_| {};
    var good = {};
    _ = for(foo()) |_| {}
    var bad = {};
}

// implicit semicolon - for expression
//
// tmp.zig:4:26: error: expected ';' after statement
