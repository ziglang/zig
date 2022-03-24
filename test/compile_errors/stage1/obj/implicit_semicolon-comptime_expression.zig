export fn entry() void {
    _ = comptime {};
    var good = {};
    _ = comptime {}
    var bad = {};
}

// implicit semicolon - comptime expression
//
// tmp.zig:4:20: error: expected ';' after statement
