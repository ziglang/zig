export fn entry() void {
    _ = if(true) {} else {};
    var good = {};
    _ = if(true) {} else {}
    var bad = {};
    _ = good;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :4:28: error: expected ';' after statement
