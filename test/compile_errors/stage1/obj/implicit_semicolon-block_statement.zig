export fn entry() void {
    {}
    var good = {};
    ({})
    var bad = {};
}

// error
// backend=stage1
// target=native
//
// tmp.zig:4:9: error: expected ';' after statement
