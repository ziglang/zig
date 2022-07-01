export fn entry() void {
    {}
    var good = {};
    ({})
    var bad = {};
}

// error
// backend=stage2
// target=native
//
// :4:9: error: expected ';' after statement
