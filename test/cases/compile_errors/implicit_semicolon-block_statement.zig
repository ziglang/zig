export fn entry() void {
    {}
    var good = {};
    ({})
    var bad = {};
    _ = good;
    _ = bad;
}

// error
//
// :4:9: error: expected ';' after statement
