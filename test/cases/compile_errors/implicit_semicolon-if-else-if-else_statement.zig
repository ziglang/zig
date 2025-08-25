export fn entry() void {
    if(true) {} else if(true) {} else {}
    var good = {};
    if(true) ({}) else if(true) ({}) else ({})
    var bad = {};
    _ = good;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :4:47: error: expected ';' after statement
