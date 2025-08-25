export fn entry() void {
    if(true) {}
    var good = {};
    if(true) ({})
    var bad = {};
    _ = good;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :4:18: error: expected ';' or 'else' after statement
