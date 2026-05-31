export fn entry() void {
    _ = comptime {};
    var good = {};
    _ = comptime {}
    var bad = {};
    _ = good;
    _ = bad;
}

// error
//
// :4:20: error: expected ';' after statement
