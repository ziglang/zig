export fn entry() void {
    _ = if(true) {} else if(true) {} else {};
    var good = {};
    _ = if(true) {} else if(true) {} else {}
    var bad = {};
    _ = good;
    _ = bad;
}

// error
//
// :4:45: error: expected ';' after statement
