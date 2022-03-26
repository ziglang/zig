export fn entry() void {
    comptime {}
    var good = {};
    comptime ({})
    var bad = {};
}

// implicit semicolon - comptime statement
//
// tmp.zig:4:18: error: expected ';' after statement
