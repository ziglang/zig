export fn entry() void {
    defer {}
    var good = {};
    defer ({})
    var bad = {};
}

// implicit semicolon - defer
//
// tmp.zig:4:15: error: expected ';' after statement
