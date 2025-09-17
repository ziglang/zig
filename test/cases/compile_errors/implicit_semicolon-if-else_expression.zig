export fn entry() void {
    _ = if(true) {} else {};
    var good = {};
    _ = if(true) {} else {}
    var bad = {};
    _ = good;
    _ = bad;
}

// error
//
// :4:28: error: expected ';' after statement
