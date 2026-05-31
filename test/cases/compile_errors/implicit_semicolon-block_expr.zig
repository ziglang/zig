export fn entry() void {
    _ = {};
    var good = {};
    _ = {}
    var bad = {};
    _ = good;
    _ = bad;
}

// error
//
// :4:11: error: expected ';' after statement
