export fn entry() void {
    defer {}
    var good = {};
    defer ({})
    var bad = {};
}

// error
// backend=stage2
// target=native
//
// :4:15: error: expected ';' after statement
