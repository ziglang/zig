export fn entry() void {
    while(true):({}) {}
    var good = {};
    while(true):({}) ({})
    var bad = {};
}

// error
// backend=stage2
// target=native
//
// :4:26: error: expected ';' or 'else' after statement
