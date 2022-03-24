export fn entry() void {
    _ = while(true):({}) {};
    var good = {};
    _ = while(true):({}) {}
    var bad = {};
}

// implicit semicolon - while-continue expression
//
// tmp.zig:4:28: error: expected ';' after statement
