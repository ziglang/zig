export fn entry() void {
    comptime {}
    var good = {};
    comptime ({})
    var bad = {};
}

// error
// backend=stage2
// target=native
//
// :4:18: error: expected ';' after statement
