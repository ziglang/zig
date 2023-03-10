export fn entry() void {
    {}
    var good = {};
    ({})
    var bad = {};
    _ = good;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :4:9: error: expected ';' after statement
