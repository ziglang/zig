export fn entry() void {
    _ = comptime {};
    var good = {};
    _ = comptime {}
    var bad = {};
}

// error
// backend=stage2
// target=native
//
// :4:20: error: expected ';' after statement
