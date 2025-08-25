export fn entry() void {
    _ = if(true) {} else if(true) {};
    var good = {};
    _ = if(true) {} else if(true) {}
    var bad = {};
    _ = good;
    _ = bad;
}

// error
// backend=stage2
// target=native
//
// :4:37: error: expected ';' after statement
