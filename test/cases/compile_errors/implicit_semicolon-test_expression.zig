export fn entry() void {
    _ = if (foo()) |_| {};
    var good = {};
    _ = if (foo()) |_| {}
    var bad = {};
}

// error
// backend=stage2
// target=native
//
// :4:26: error: expected ';' after statement
