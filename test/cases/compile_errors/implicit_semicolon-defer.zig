export fn entry() void {
    defer {}
    var good = {};
    defer ({})
    var bad = {};
    _ = good;
    _ = bad;
}

// error
//
// :4:15: error: expected ';' after statement
