export fn entry() void {
    if(true) {} else if(true) {}
    var good = {};
    if(true) ({}) else if(true) ({})
    var bad = {};
    _ = good;
    _ = bad;
}

// error
//
// :4:37: error: expected ';' or 'else' after statement
