export fn entry() void {
    _ = for(foo()) |_| {};
    var good = {};
    _ = for(foo()) |_| {}
    var bad = {};
}

// error
// backend=stage2
// target=native
//
// :4:26: error: expected ';' after statement
