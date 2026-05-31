export fn entry() void {
    _ = if(true) {};
    var good = {};
    _ = if(true) {}
    var bad = {};
    _ = good;
    _ = bad;
}

// error
//
// :4:20: error: expected ';' after statement
