export fn entry() void {
    _ = while(true):({}) {};
    var good = {};
    _ = while(true):({}) {}
    var bad = {};
}

// error
// backend=stage2
// target=native
//
// :4:28: error: expected ';' after statement
