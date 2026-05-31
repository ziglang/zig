export fn entry() void {
    comptime {}
    var good = {};
    comptime ({})
    var bad = {};
    _ = good;
    _ = bad;
}

// error
//
// :4:18: error: expected ';' after statement
