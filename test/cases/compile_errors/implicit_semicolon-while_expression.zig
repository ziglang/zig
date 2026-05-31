export fn entry() void {
    _ = while(true) {};
    var good = {};
    _ = while(true) {}
    var bad = {};
    _ = good;
    _ = bad;
}

// error
//
// :4:23: error: expected ';' after statement
