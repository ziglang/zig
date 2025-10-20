export fn entry() void {
    if(true) {} else {}
    var good = {};
    if(true) ({}) else ({})
    var bad = {};
    _ = good;
    _ = bad;
}

// error
//
// :4:28: error: expected ';' after statement
