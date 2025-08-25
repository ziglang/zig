export fn entry() void {
    while(true) {}
    var good = {};
    while(true) 1
    var bad = {};
    _ = good;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :4:18: error: expected ';' or 'else' after statement
