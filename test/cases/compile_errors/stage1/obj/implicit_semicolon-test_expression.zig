export fn entry() void {
    _ = if (foo()) |_| {};
    var good = {};
    _ = if (foo()) |_| {}
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:26: error: expected ';' after statement
